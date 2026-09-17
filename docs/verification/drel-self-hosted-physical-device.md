# Drel 自托管加密推送真机验收

此文档是 **Drel 自托管推送** 的最终验收记录，不是 Apple 审核演示。
只有当前代码已制成包含「设置 → 自托管推送」的 TestFlight 构建、独立 HTTPS 服务已部署且
测试 iPhone 已连接时才执行。使用手机上实际已安装、且确实展示该设置入口的最新测试构建；
不要以旧的 Build 60 或模拟器结果代替真机验收。

## 前置条件

- 独立公网域名已通过 Cloudflare Tunnel 公开到仅监听 `127.0.0.1:8080` 的自托管
  服务；不使用 `api.drel.app` 或正在审核的正式服务。无需开放入站 80/443。
- 主机 `.env` 设置 `APNS_TOPIC=com.webbridgekit.superapp`、
  `APNS_ENVIRONMENT=production`，并由该 App topic 所属的 Drel operator 以只读方式
  提供 Apple 签发的 production topic-specific APNs `.p8`。不得用旧 team-scoped key，
  更不得把 `.p8` 发布给第三方、自建用户或写入测试/公开仓库。
- `systemctl is-active drel-selfhosted cloudflared-drel` 均返回 `active`；
  `https://<host>/ping` 返回 `pong`，`/health` 返回 `status: ok` 与
  `apnsReady: true`，描述文件返回 `drel.self-hosted-push.v1`。
- 原生服务已通过 `cd Server/native && go test ./...` 和公开描述文件/健康接口验证；
  不能把 `apnsReady: false` 视为可测试状态。
- 直接推送的可移植字段（包括 `mode`、`display`、`route`、分组、角标、声音和
  中断级别）已由原生服务回归测试覆盖；嵌套 `params` / `approval` 使用 `POST /push`
  JSON，而不是短 URL。测试时仍须验证真实 APNs 负载在 iPhone 上的实际表现。
- 一台已解锁过一次的 TestFlight/Ad Hoc Drel iPhone。记录机型与 iOS 版本，但不要
  记录 APNs token、配对 token、设备 key 或 `.p8` 内容。

## 配对

在部署主机或可信管理机运行：

```bash
DREL_PAIRING_QR_OUTPUT=pairing.png \
  bash tools/create-drel-selfhost-pairing.sh https://push.example.com
```

在 iPhone 的 **Drel → 设置 → 自托管推送** 扫描 `pairing.png`，或粘贴脚本输出的
`drel://` 配置码。通过标准：页面显示已连接的服务器名称、HTTPS 地址和自托管推送
地址；官方 `api.drel.app` 的默认地址仍保持不变。等待配置码过期后，重复使用同一
二维码应失败。

## 发送与验收

从可信发送端以已连接页面显示的 `<deviceKey>` 发送。先验收默认的**直接推送**：它应
通过自建服务器直连 APNs，不经过 `api.drel.app`；随后单独验收可选的发送侧加密路径。
两种测试均不得把真实 key 写进截图、文档或终端录屏。

直接模式结构：

```bash
curl -G 'https://push.example.com/<deviceKey>/Self-hosted%20verification/Direct%20delivery' \
  --data-urlencode 'url=https://drel.app/'
```

严格加密模式结构：

```bash
node Server/examples/drel-encrypt-and-push.mjs \
  https://push.example.com <deviceKey> \
  'Self-hosted verification' 'Code 482901' https://drel.app/
```

按顺序验证，并在下表记录 **通过 / 失败 / 未执行**：

| 场景 | 操作 | 通过标准 |
| --- | --- | --- |
| 前台 | Drel 保持前台，发送一次 | 收件箱只有一条「Code 482901」；不自动打开网页。 |
| 后台 | 退到后台，发送一次 | 横幅展示解密后的标题和正文；点按后收件箱只有一条新增消息。 |
| 锁屏 | 锁屏后发送一次 | 锁屏通知展示解密内容与指定铃声；首次开机后必须先解锁一次才测试。 |
| 点击路由 | 点按含 `url` 的通知 | 仅打开一次 `https://drel.app/` 的普通网页容器，不出现 manifest 错误。 |
| 沉浸式打开 | Drel 退到后台后，发送一次带 `mode=immersive` 与 `url` 的直接推送，再点按通知 | 点按后仅打开一次全屏网页容器；前台收到通知时不允许系统强制打断并自动全屏。 |
| 无重复发送 | 对同一个场景仅执行一次发送工具 | 通知中心与收件箱均只出现一条；服务端不得对同一 alert 自动重试。 |
| 发送侧保密 | 检查该次 HTTP request、应用日志与 APNs 外层记录 | 仅有 `deviceKey`、空 `title/body` 和 `drelEnvelope`；不得出现 `Code 482901`。 |
| 本机解密与来源 | 在 Drel 的自托管来源下打开刚才的加密消息；切换到官方来源再检查 | 自托管历史只有刚才的一条解密后正文；官方历史不混入此消息。自托管消息不能因来源筛选而消失。 |
| 撤销 | Drel 点「移除自托管服务器」后再发送 | 服务端精确注销该 token/key；不再送达，官方服务不受影响。 |

## 失败取证

- 只记录时间、redacted 后的设备 key 尾部、HTTP 状态和 APNs 错误码；不得保存正文、
  token、配对码或私钥。
- APNs 返回超时不允许自动重发。先检查服务器日志是否有一次 APNs 尝试，再到手机
  检查是否已经投递。
- 若锁屏显示「解密失败」，确认测试构建和 Notification Service Extension 都来自当前
  代码、手机本次开机后至少解锁过一次，并重新扫描一个未过期配置码。
- 若点击网页出现 `Manifest file not found`，这不是 APNs 问题；检查 URL 路由是否使用
  普通 HTTPS 容器路径而不是 HTML App manifest loader。若带 `mode=immersive` 却仍以
  非全屏打开，记录时间和请求模式；先确认通知是从后台/锁屏状态点按，而不是在前台期待
  iOS 自动跳转。

## 结果记录

| 日期 | 构建 | 设备 / iOS | 服务域名 | 前台 | 后台 / 锁屏 | 点击 / 全屏 | 解密 / 来源 | 无重复 | 撤销 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-09-08 | TestFlight 真机待填 | 真机待填 | push.drel.app | 未执行 | 未执行 | 未执行 | 未执行 | 未执行 | 未执行 | 自动预检 7 通过、0 失败；详见 `build/reports/real-device-push-readiness.md`，不能替代真机证据。 |
