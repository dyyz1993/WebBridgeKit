# Drel Web App Manifest Profile（规划：1.3.0 / 1.4.0）

## 目的

Drel 采用标准 **Web App Manifest**（通常命名为 `manifest.json` 或
`manifest.webmanifest`）作为网页应用的展示和启动描述；它不是 Drel 自定义
网页格式，也不是离线包本身。

当前实现已把同名 `drel_offline` 扩展与标准 `manifest.webmanifest` 适配器接入
现有的、已签名的 Drel HTML App 父 Manifest。父 Manifest 必须以 `webManifest.url`
和 `webManifest.sha256` 固定标准 Manifest 的精确地址与字节；适配器拒绝摘要不符、
重定向、越过 `allowedOrigins` 或 `scope` 的启动地址和图标。标准 Manifest 中的
`drel_offline` 还必须与父 Manifest 的签名声明完全一致。任意网站不能因出现一个
JSON 文件而自动获得离线安装资格。

网页在 HTML 中以标准方式声明：

```html
<link rel="manifest" href="/manifest.webmanifest">
```

这让同一份网页能够继续被普通浏览器和其他 PWA 容器识别。Drel 只读取本
文列明的字段，不要求网页调用任何 Drel 专有 JavaScript。

> 标准来源：[W3C Web Application Manifest](https://www.w3.org/TR/appmanifest/)。
> Web App Manifest 是正在演进的 Web 标准；Drel 的兼容范围以本文为准。

## 两层文件，解决两类问题

| 层 | 文件 | 回答的问题 | 何时使用 |
| --- | --- | --- | --- |
| PWA 描述层 | `manifest.json` / `manifest.webmanifest` | 这个网页应用叫什么、图标是什么、从哪里启动、偏好怎样展示？ | 1.3.0「我的应用」 |
| Drel 安装完整性层 | 当前离线包资源清单（默认示例为 `package.json`）及其已签名父 Manifest | 哪些精确字节可以下载、校验、原子安装并离线启动？ | 1.4.0「私有离线应用」 |

因此，**有 Web Manifest 不等于已经离线可用**。Service Worker 或浏览器缓存
可以改善网页的网络体验，但不能作为 Drel“离线可用”的承诺。Drel 的离线包
仍须校验资源清单 SHA-256、每个资源的哈希和大小，并在应用管理的持久化目录
中原子激活。完整安装协议见
[Strong Offline Package v1](offline-package-v1.md)。

## Drel 的离线扩展（1.4.0 目标）：描述与资源清单分离

标准 Web App Manifest 没有“列出整个离线资源集合并校验每个文件”的成员。它允许
实现方增加带稳定前缀、独立处理的专有成员；因此 Drel 计划以 `drel_offline` 只声明
离线包的**版本、资源清单位置和资源清单摘要**，而不污染标准字段：

```json
{
  "name": "Example Console",
  "start_url": "/app/",
  "scope": "/app/",
  "drel_offline": {
    "version": "2026.09.08",
    "resource_manifest": "/drel/package.json",
    "resource_manifest_sha256": "64-lowercase-hex-characters"
  }
}
```

`/drel/package.json` 才列出完整资源集合：本地相对路径、首次安装下载来源、大小、
MIME 类型和 SHA-256。Drel 下载并验证所有资源后，把入口 HTML、CSS、JavaScript、
图片、字体及 Manifest 图标一起写入应用私有目录；只有整包完整，才原子切换为当前
版本。

**这不是“每次仍按线上 URL 打开”。** 资源 URL 只服务于首次下载或用户主动更新；
成功安装后的启动解析到本地入口文件，并由现有文件/自定义 scheme 处理同包的
CSS、JS、图片请求，断网时也不发起线上页面请求。若希望首次安装也只下载一次，
未来可把完整资源清单所指向的多文件下载替换成一个已签名、带总哈希的归档包；
这仍需要一个下载来源，但运行时同样只读取本地。

把所有资源数组直接内嵌进 `manifest.json` 在技术上可行，但不建议作为 Drel 的
主契约：它会令日常 PWA 元数据更新和大包资源版本绑死，难以对资源清单的原始字节
做独立签名/摘要校验。采用一个小型标准 Manifest 加一个可精确固定的资源清单，
更适合断点下载、校验、回滚与审计。当前代码已具备等价的已签名父 Manifest +
资源清单安装协议；`drel_offline` 是 1.4.0 将它接入标准 Web Manifest 的公开
字段形态，尚未作为 Store 构建功能发布。当前代码已接受该扩展，把 Web Manifest
绑定和离线声明一并纳入父 Manifest 的 Ed25519 签名覆盖范围，并实现受信任读取、
相对 URL 解析和来源/scope 校验。1.4.0 的用户入口仍要求用户主动下载或更新，
不会静默安装。

## 下载形态与运行形态

离线方案必须区分“首次怎么取得文件”和“安装后怎么运行”。压缩包不是另一种
离线运行模式，而是完整包的一种下载形态：

| 方案 | 首次取得 | 安装后启动 | 是否可承诺断网 |
| --- | --- | --- | --- |
| WebView / PWA 缓存 | 网页按需网络请求 | 仍由 WebKit 决定命中与清理 | 否，只能加速 |
| 资源清单 | 按资源清单逐项下载、校验 | 原生从应用私有目录提供本地入口和同包资源 | 是，前提是资源完整 |
| 归档包（ZIP 等） | 下载一个有摘要的归档，解包到 staging 后逐项校验 | 与资源清单方案完全相同 | 是，前提是资源完整 |

归档不得直接作为 WebView 的运行容器。Drel 必须先在私有 staging 目录解包，
验证清单中的每个文件，再原子启用目录；否则 HTML 的相对 CSS、模块导入、图片与
字体无法得到一致、安全的解析。Drel 仍以资源清单作为最终真相：归档只是更方便的
传输优化，可在后续版本作为 `archive` 可选字段加入，不替代每个文件的校验。

本地入口不能来自网页声明的任意绝对磁盘路径。它只能由 Drel 根据已验证的
`appId + version + entrypoint` 在 `Application Support` 的私有包目录计算出来，再
授予 WebKit 该包目录的最小读取范围，或由受限的 Drel custom scheme 按相对路径
提供资源。所有未打入包的 API、第三方 CDN、动态图片和登录接口仍需要网络；要把
某个应用称作“完全离线”，其首屏和目标流程依赖必须全部被列入包或明确提供本地
降级。

## 1.3.0 支持字段与 Drel 映射

| 标准字段 | Drel 用途 | 限制 |
| --- | --- | --- |
| `id` | 稳定网页应用身份的候选值 | 必须与受信任来源绑定；不能仅凭远程更新替换本地应用身份。 |
| `name`、`short_name`、`lang`、`dir` | 应用卡片标题与辅助显示 | `name` 缺失时回退网页标题或用户自定义名称。 |
| `icons` | 首页「我的应用」、应用信息页的图标 | 安装后只使用已校验包内图标；网络入口只能视为预览，不能作为永久离线保证。 |
| `start_url` | 用户确认后的默认启动页 | 去除凭据、一次性 token 和临时参数；限制为已确认的同源、同范围 URL。 |
| `scope` | 判断哪些导航仍属于该应用 | 超出范围的外部链接走普通网页打开策略，不能继承应用身份或默认启动设置。 |
| `display` | 对 Drel 容器展示偏好的提示 | 不是强制命令。Drel 保留返回、退出、外部链接和安全提示；推送的展示策略仍由统一路由策略处理。 |
| `theme_color`、`background_color` | 卡片、启动过渡和容器主题的视觉提示 | 仅作视觉信息，不改变 Drel 的全局品牌图标或系统权限界面。 |

`shortcuts`、`screenshots`、`orientation` 等字段先作为兼容数据保留，不在
1.3.0 自动生成原生操作、通知按钮或权限入口。后续若启用，必须单独进入版本
范围、测试和审核说明。

## 图标复用规则

1. 网页应在 `icons` 中提供多个尺寸和 MIME 类型；Drel 选择最适合当前卡片
   尺寸且可解码的一项。`sizes` 是选择提示，不是可信性证明。
2. 优先使用清晰的方形 PNG/WebP；如声明 `purpose: "maskable"`，仅在该展示
   场景适合裁切时使用。不能把非圆角/非安全区图标硬裁成圆形。
3. 离线安装时，选中的图标也必须列入已校验的资源清单，和 HTML、CSS、JS 一起
   固化为该版本的一部分。更新图标等同于更新包版本。
4. 没有可用 Manifest 图标时，网络入口可回退到网页 favicon/`apple-touch-icon`
   作预览；离线应用则使用 Drel 默认占位图，直到用户安装包含图标的有效版本。
5. 网页图标只能用于 Drel 内的应用卡片与应用信息；它**不能动态替换 iOS 中
   Drel 本体的 App Icon**。系统通知仍显示 Drel 的应用图标。

## 最小示例

```json
{
  "id": "/",
  "name": "Example Console",
  "short_name": "Console",
  "lang": "en",
  "start_url": "/app/",
  "scope": "/app/",
  "display": "standalone",
  "theme_color": "#5B5CE2",
  "background_color": "#FFFFFF",
  "icons": [
    {
      "src": "/assets/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/assets/icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    }
  ]
}
```

这份文件可让 Drel 在 1.3.0 中建立应用卡片；只有在 1.4.0 另行提供经签名、
哈希校验的离线资源清单后，它才可显示为“离线可用”。

## 安全与版本边界

- 添加应用、设置默认启动、下载离线包、更新包和删除包都必须由用户在前台主动
  触发；推送、网页脚本和远程描述文件不能自动执行这些动作。
- Manifest 只描述网页，不授予原生能力。任何 Bridge 或权限设计属于独立的
  `1.5.0` 决策门，不能因网页带有 Manifest 或离线包而提前启用。
- 不能以 `display: "fullscreen"` 绕过 Drel 的返回、退出、外部导航或安全控制。
- 离线资源清单与签名的准确字段、限制和错误语义以
  [Strong Offline Package v1](offline-package-v1.md) 为准。

## 网页运行环境识别

Drel 在创建 WebView 时一次性追加稳定、可版本化的 UA 产品标记；它会随首个
网页请求发送，不依赖页面加载后的异步修改。格式为：

```text
Drel/<App版本> (Build/<构建号>; Screen/<原生点宽>x<原生点高>; DPR/<缩放>; Container/1; Offline/1; Bridge/<协议版本或0>) WebBridgeKit/1
```

`Screen` 表示设备原生屏幕基准，不表示当前网页可用区域，也不用于判断刘海或
安全区。网页布局仍应使用 CSS `env(safe-area-inset-*)`、`window.innerWidth`、
`window.innerHeight` 和 `window.visualViewport`。

同时，Drel 在 document start 注入只读 `window.DrelRuntime`：

- `runtime`：网络页为 `web`，已安装本地包为 `offline-package`；
- `isOfflinePackage`：是否由 Drel 管理的本地包运行；
- `presentation`：`normal`、`immersive` 或 `modal`；
- `screen`：屏幕基准尺寸与 DPR；
- `viewport`：当前实时可用区域，随全屏、非全屏和旋转自然变化；
- `containerVersion`、`offlinePackageVersion`、`bridgeVersion`：分别用于判断
  容器协议、离线包协议和原生 Bridge 协议。商店容器未开放 Bridge 时，
  `bridgeVersion` 必须为 `0`，网页不能据此推断获得任何原生权限。

该对象仅提供环境信息；它不授予 Bridge、文件、相册或其他原生能力。网页必须
对字段缺失做普通浏览器降级，不得把 UA 或运行信息当成安全凭证。
