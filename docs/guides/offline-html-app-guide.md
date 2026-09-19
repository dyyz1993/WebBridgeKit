# 把网页做成 Drel 离线 HTML 应用（整合指南）

本指南把散落在 `docs/api/` 各文档、`tools/` 打包脚本和服务端实现里的操作信息整合成一条可执行管线，并以一个典型场景贯穿：**自有服务器上的联网 Web 应用**（示例 `https://pi-chat.example.com:8443/`，带 `?token=` 查询参数的 React 聊天页）如何变成 App 里可注册、可离线打开的 HTML 应用。

读完后你应该能回答：打包打什么、部署到哪、服务器怎么录入、手机上怎么出现、以后怎么更新。

参考文档（本文与其不一致处，以本文勘误为准，见 §10）：

- 契约：`docs/api/offline-package-v1.md`、`docs/api/drel-web-app-manifest-profile.md`
- 总览：`docs/api/html-app-onboarding.md`
- 数据注入：`docs/api/drel-offline-template.md`；拉起：`docs/api/drel-app-link.md`
- 架构：`docs/architecture/strong-offline-packages.md`
- 参考实现：`tools/build-drel-offline-network-demo-site.sh` 与线上 `https://drel.app/test/offline-network/`

## 1. 三分钟理解信任链

离线体系里有三层文件、一个签名网关：

1. `package.json` —— **资源清单**：逐文件列出 `path/url/size/sha256/mimeType`，是离线包的完整性清单。
2. `manifest.webmanifest` —— 标准 PWA manifest + `drel_offline` 扩展字段，指向资源清单并携带其 sha256。
3. 网关签名的父清单 —— 即 `POST /api/v1/html-apps` 的请求体，服务端用 Ed25519 私钥对它签名后下发；其中的 `cache.resourceManifestSHA256` 把资源清单的字节钉死。

手机端只信任**验签通过**的父清单，再按清单逐文件校验下载。有 `manifest.webmanifest` 不等于离线可用——必须走完整条签名链。

## 2. 前置条件：网关已具备签名能力（一次性）

服务端环境变量（`Server/.env.example`「Managed HTML app gateway signing」段）：

```dotenv
ADMIN_API_KEY=<自定义管理密钥>          # POST/PUT/DELETE 的鉴权
GATEWAY_KEY_ID=gw-2026-09-19           # 非空才可签名
# Base64URL 编码的 32 字节 Ed25519 私钥（raw seed）。生成方法：
#   openssl genpkey -algorithm ed25519 -out gateway-ed25519.pem
#   openssl pkey -in gateway-ed25519.pem -outform DER 2>/dev/null | tail -c 32 | base64 | tr '+/' '-_' | tr -d '='
GATEWAY_PRIVATE_KEY=<上一步输出>
```

- 公钥不用手工推导：`GET /api/v1/gateway` 直接返回 `publicKeyId` / `publicKey`（Base64URL 的 32 字节 raw public key）。
- 自检：`GET /health` 返回 `status:"ok"`；`GET /api/v1/gateway` 能看到 keyId。
- 官方网关（api.drel.app）与自部署网关的**服务端录入步骤完全相同**；差别只在手机端——已 pin 官方网关的 App 无需导入，新建自部署网关才需要走 `docs/guides/self-hosted-gateway-import.md` 的导入流程。

## 3. 第一步：准备站点产物

以 React 应用为例（`npm run build` 产物）：

- **全部静态资源入包**：`index.html`、带 hash 的 JS/CSS chunk、图标、字体。漏一个 chunk，断网时就白屏。
- **相对路径引用**，不依赖任何 CDN；未入包的 API 调用运行时仍需网络。
- `index.html` 声明 `<link rel="manifest" href="../manifest.webmanifest">`（路径按你的部署布局调整）。
- **联网型应用的形态**（聊天/仪表盘等）：包里只放 UI 壳，数据永远联网取。页面里用 `window.DrelRuntime.isOfflinePackage` / `offlinePackageVersion` 识别是否运行在离线包中（见 manifest-profile「网页运行环境识别」）；断网时回退 localStorage 快照并如实标注缓存时间——参考 `test_resources/offline-network-demo/v1/assets/app.js` 的实现。
- React SPA 注意：hash 路由（`#/chat`）无法做深链；`routes` 填实际入口路径且**不能带 query**。

## 4. 第二步：打包生成三件套

复制 `tools/build-drel-offline-network-demo-site.sh` 为 `build-pichat-site.sh`，修改头部四值（这是脚本唯一需要改的地方，原脚本硬编码给官方 demo 用）：

```bash
SOURCE="/path/to/pichat/dist"                       # 你的构建产物目录
PUBLIC_ROOT="https://pi-chat.example.com:8443/drel" # 产物将部署到的公网根地址
APP_ID="com.shanbox.pichat"                         # ≤64 字符，仅 A-Za-z0-9._-
VERSION="1"
```

同时把脚本中 Python 段的 `package_root = stage / "test" / "offline-network" / "v1"` 改成你的相对目录，`mime_overrides` 确保 `.js` 映射为 `text/javascript`。

脚本会依次产出：

1. `<staging>/<路径>/package.json` —— 资源清单（`schemaVersion/appId/version/entrypoint/files[]`），以 `sort_keys` + 紧凑分隔符序列化，**摘要对这份确切字节**计算；
2. `<staging>/<路径>/manifest.webmanifest` —— 含 `drel_offline{version, resource_manifest, resource_manifest_sha256}`；
3. `<staging>/<路径>/gateway-manifest.json` —— 待签名父清单，内容即 §6 的 POST 请求体；
4. `build-metadata.json` —— 两个摘要与文件数（后续录入要用）；
5. 诊断 ZIP —— **仅供人工检查，运行时不执行**，不需要部署它给 App 用。

硬性限额：资源清单 ≤1MiB；≤2000 个文件；单文件 ≤50MiB；总量 ≤250MiB。`entrypoint` 必须在 `files` 中恰好出现一次。

### webmanifest 字段速查

完整规范见 [`docs/api/drel-web-app-manifest-profile.md`](../api/drel-web-app-manifest-profile.md)。Drel 只读取下列字段：

| 字段 | 用途 | 注意 |
| --- | --- | --- |
| `id` / `name` / `short_name` | 应用身份与卡片标题 | `name` 缺失时服务端录入会回退抓取网页标题 |
| `icons` | 应用卡片/详情图标 | **选中使用的图标必须同时列入 `package.json` 的 `files`**，随包一起校验；只声明不入包则离线态用占位图 |
| `start_url` | 默认启动页 | 按规范应去除凭据与临时参数；同 `scope` 同源 |
| `scope` | 判断导航是否仍属于该应用 | 超出 scope 的外链走普通网页打开策略 |
| `display` | 展示偏好提示 | 仅提示；不能借 `fullscreen` 绕过返回/退出控制 |
| `theme_color` / `background_color` | 卡片与过渡视觉 | 仅视觉 |
| `drel_offline.version` | 离线包版本 | 必须与父清单 `cache.version` 一致 |
| `drel_offline.resource_manifest` | 资源清单（package.json）的公网地址 | 必须与父清单 `cache.resourceManifestURL` 一致 |
| `drel_offline.resource_manifest_sha256` | 资源清单摘要 | 必须与父清单 `cache.resourceManifestSHA256` 一致 |

三个一致性约束（客户端安装器强制）：`webManifest.url` 的**精确字节**摘要必须等于父清单 `webManifest.sha256`（禁止重定向）；`drel_offline` 三字段与父清单 `cache` 声明逐一相等；manifest 的 URL 必须是 HTTPS 且落在 `allowedOrigins` / `scope` 内。`shortcuts`、`screenshots` 等字段仅作兼容数据保留，Drel 不消费。

最小示例（与打包脚本产物同构，`sort_keys` 紧凑序列化后计算摘要）：

```json
{
  "id": "https://pi-chat.example.com:8443/drel/",
  "name": "Pi Chat",
  "short_name": "Pi Chat",
  "start_url": "https://pi-chat.example.com:8443/drel/v1/index.html",
  "scope": "https://pi-chat.example.com:8443/drel/",
  "display": "standalone",
  "icons": [{"src": "…/icon-512.png", "sizes": "512x512", "type": "image/png"}],
  "drel_offline": {
    "version": "1",
    "resource_manifest": "https://pi-chat.example.com:8443/drel/package.json",
    "resource_manifest_sha256": "<64 位小写 hex>"
  }
}
```

## 5. 第三步：部署与自校验

- 把 staging 中对应目录（含 `v1/`、`package.json`、`manifest.webmanifest`）部署到 `PUBLIC_ROOT`。
- **同一版本 URL 的字节永不改动**；任何更新都发新 `VERSION`、新目录。
- 托管层不得对 `package.json` / `manifest.webmanifest` 做重定向或字节改写（安装器会报 `redirectMismatch` / `digestMismatch`）。
- 站点必须有受信 CA 的 TLS 证书（客户端用 URLSession 下载，`:8443` 这类非默认端口无豁免）。
- 官方的 `tools/verify-drel-offline-demo-public.sh` 是 demo 专用（硬编码官方 appId 与 ZIP 名），自定义站点请手工校验：

```bash
# 与 build-metadata.json 比对
curl -fsS "$PUBLIC_ROOT/package.json" | shasum -a 256          # == packageSHA256
curl -fsS "$PUBLIC_ROOT/manifest.webmanifest" | shasum -a 256  # == webManifestSHA256
# 抽查若干文件的 sha256/size 与 package.json 一致
```

## 6. 第四步：服务器录入（签名）

```bash
curl -X POST "https://<网关域名>/api/v1/html-apps" \
  -H "Authorization: Bearer $ADMIN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "schemaVersion": "1",
    "appId": "com.shanbox.pichat",
    "name": "Pi Chat",
    "startURL": "https://pi-chat.example.com:8443/",
    "allowedOrigins": ["https://pi-chat.example.com:8443"],
    "capabilities": [],
    "routes": ["/"],
    "cache": {
      "strategy": "manifest",
      "version": "1",
      "persistent": true,
      "resourceManifestURL": "https://pi-chat.example.com:8443/drel/package.json",
      "resourceManifestSHA256": "<package.json 的 sha256>",
      "restoresLastState": true
    },
    "webManifest": {
      "url": "https://pi-chat.example.com:8443/drel/manifest.webmanifest",
      "sha256": "<manifest.webmanifest 的 sha256>"
    },
    "drel_offline": {
      "version": "1",
      "resource_manifest": "https://pi-chat.example.com:8443/drel/package.json",
      "resource_manifest_sha256": "<同 resourceManifestSHA256>"
    }
  }'
```

校验要点（不符会被 4xx 拒绝）：

- `appId` ≤64 字符、仅 `A-Za-z0-9._-`；`name` 为空时服务端会尝试抓页面 `<link rel=manifest>` 补名。
- `allowedOrigins` 是**精确 origin（含端口）**去重列表，且必须包含 `startURL` 的 origin——`:8443` 必须写上。
- `routes` 必须以 `/` 开头，**禁止 `?` `#` `\` `*` `..`**；支持 `:param` 命名段；客户端按段数做精确匹配。注意 §10 勘误 1。
- `resourceManifestURL` 与 `resourceManifestSHA256` 必须成对出现，URL 的 origin 必须在 `allowedOrigins` 内。
- `cache` 与 `drel_offline` 两处声明不一致会被拒。
- `strategy` 的合法值是 `manifest` / `networkOnly`（§10 勘误 2）。

接口行为：POST 是按 `appId` 的 upsert；`GET /api/v1/html-apps` 返回 `{"manifests":[…]}` 并在读取时即时签名；`DELETE /:appId` 下线应用。持久化在 `<DATA_DIR>/html-apps.json`。

## 7. 第五步：手机端出现与安装

1. **目录刷新时机**（二选一，无后台轮询）：打开应用中心；或收到指向该应用的推送（本地未信任该应用时自动联网刷新）。
2. 刷新时客户端会：拉目录 → 逐条验签 → 下载每个 `webManifest.url` 并比对摘要与 `drel_offline` 一致性 → 应用出现在「我的应用」。
3. 进应用详情点 **「下载离线包」**（已有旧包且服务端已更新时显示「更新离线包」）。安装器会逐文件校验 size+sha256 后原子落盘到 `Application Support/WebBridgeKit/Packages/<sha256(appId)>/`。
4. 「打开应用」时：`appId + version + resourceManifestSHA256` 三者与受信清单完全一致 → 走本地强离线入口；不一致（服务端已更新而本机未更新）→ 自动回落联网打开，不会用错版本的旧包。
5. 验收路径参照 `docs/verification/drel-14-offline-network-demo.md`：联网下载 → 飞行模式冷启动 → 断网可用 → 恢复联网数据刷新。

## 8. token 与登录态

- `startURL` 带 `?token=…` **可以注册**（服务端只取 origin 参与校验），联网打开时 query 也会保留传到页面。
- 但**强离线启动不走 startURL**：本地入口是 `file://` 文件路径，没有任何 query——token 到不了页面。
- 推荐做法：
  1. 登录态放 localStorage：首次联网运行时建立会话，之后离线直接可用；
  2. 每次经推送注入：`POST /push` 带 `"params": {"token": "…"}`，页面读 `drel_param_token`（值为标量字符串、建议总量 <1KB、只能写入 `textContent`，见 `docs/api/drel-offline-template.md`）。
- 不要把凭据写进 `start_url`——它会被签名固化，换 token 就要重新录入并等手机端刷新。

## 9. 更新流程（全手动）

1. 改站点 → `VERSION` 加 1 → 重跑打包脚本（新摘要）→ 部署新版本文件（旧版本文件保留）。
2. 重新 `POST /api/v1/html-apps`（upsert 覆盖并重签）。
3. 手机端刷新目录（见 §7.1）→ 应用详情显示「待更新（当前 x → y）」→ 用户手动点「更新离线包」。
4. 更新失败只丢弃暂存区，旧包继续可用；已更新服务端但设备未更新时，打开自动回落联网版，不会用旧离线包冒充新版本。

## 10. 已知文档勘误与易错点

1. `docs/guides/pwa-developer-guide.md` 中 `/app/chat/*` 通配符示例是**错的**——服务端校验禁止 `*`，照抄会被拒。
2. `docs/api/html-app-onboarding.md` 把 `cache.strategy` 写作 `manifest / none`，实际为 **`manifest / networkOnly`**。
3. `/api/v1/gateway` 返回的字段名是 `healthPath` / `manifestPath`，而网关导入配置（gateway-v1）要求 `healthEndpoint` / `manifestEndpoint`，两者需手工映射。
4. `html-app-onboarding.md` 的 curl 示例只有基础字段，**不带** `webManifest` / `drel_offline` / `resourceManifestSHA256`——离线应用录入必须带全（§6）。
5. 打包脚本硬编码官方 demo 的四个值，复用必须 fork 修改（§4）。
6. 官方 verify 脚本仅适用官方 demo（§5）。

## 11. 排错速查

| 现象 | 原因 |
|---|---|
| 录入 4xx | route 带通配符/`?`；origin 漏 `:8443` 端口；`cache` 与 `drel_offline` 不一致；摘要格式非 64 位小写 hex |
| 手机端应用不出现 | 未刷新目录（开应用中心或发一条指向它的推送）；验签失败（服务端 keyId/私钥换过而客户端 pin 的是旧公钥） |
| 「下载离线包」失败 | manifest 超限（1MiB/2000 文件/50MiB 单文件/250MiB 总量）；托管层重定向或字节被改（`redirectMismatch`/`digestMismatch`）；证书不受信 |
| 离线打开白屏 | 有 chunk 没入包；hash 路由深链；`entrypoint` 不在 `files` 里 |
| 离线打开变成联网加载 | 服务端已更新而本机离线包未更新（版本或摘要不匹配，属预期安全行为），联网更新一次即恢复强离线 |
