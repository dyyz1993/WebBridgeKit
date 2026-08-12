# WebBridgeKit Message Types v1

所有规范消息使用 `POST /push`、`schema: webbridgekit.message.v1` 和一个明确的 `type`。`title`、`body`、`deviceKey` 是公共必填字段；类型字段只负责选择 Inbox 的原生内容插槽，不改变 PWA 的业务协议。

## 字段到 UI 映射

| `type` | 类型必填字段 | Inbox 详情 | 主要操作 | 降级行为 |
| --- | --- | --- | --- | --- |
| `plain` | 无 | 普通正文 | 有 `url`/`appId` 时打开目标 | 始终保留标题和正文 |
| `markdown` | `markdown` | 宿主内置离线 Markdown 阅读区 | 打开内容中的 HTTPS 链接 | 渲染异常时保留推送摘要 |
| `image` | HTTPS `image` | 图片预览 | 有路由时打开目标 | 加载失败显示紧凑错误提示，正文仍可读 |
| `qr` | `qrPayload` | 宿主生成二维码 | 复制二维码原始值 | 空值在接口层拒绝 |
| `otp` | `verificationCode` | 大字号验证码与有效期 | 复制验证码 | 过期后保留历史并标记过期 |
| `chat` | `appId`, `route` | 消息摘要 | 打开会话 | PWA 负责登录、消息读取和回复 |
| `approval` | 见 [Approval v1](approval-v1.md) | 状态与原生动作或受信任页面 | 确认提交/打开审批 | 第一份有效响应生效 |

`group` 和 `threadId` 用于 Inbox 分组及 APNs 线程；`params` 仅允许字符串值。`route`、`requestId`、`revision`、`statePath` 等诊断字段默认折叠到详情页“技术信息”。推送不接受原始 HTML。

## Markdown 渲染边界

`markdown` 只传 Markdown 字符串。宿主把它转为自包含 HTML 后在内置 `WKWebView` 中显示，不下载 CDN 解析器，也不依赖外部 PWA；因此纯文字、表格、任务清单、引用、代码块和安全链接在离线时仍可阅读。原始 HTML 会作为文本转义，链接仅允许 `https`、`http` 或 `mailto`，图片仅允许 HTTPS 地址；远程图片本身仍需要网络可用。

## 最小请求示例

```bash
curl http://localhost:8080/push \
  -H 'Content-Type: application/json' \
  -d '{"schema":"webbridgekit.message.v1","type":"plain","deviceKey":"test","title":"系统维护","body":"今晚 22:00 开始维护"}'

curl http://localhost:8080/push \
  -H 'Content-Type: application/json' \
  -d '{"schema":"webbridgekit.message.v1","type":"markdown","deviceKey":"test","title":"部署完成","body":"查看部署摘要","markdown":"## 结果\n\n- 状态：成功"}'

curl http://localhost:8080/push \
  -H 'Content-Type: application/json' \
  -d '{"schema":"webbridgekit.message.v1","type":"image","deviceKey":"test","title":"预览已生成","body":"查看图片","image":"https://example.com/preview.png"}'

curl http://localhost:8080/push \
  -H 'Content-Type: application/json' \
  -d '{"schema":"webbridgekit.message.v1","type":"qr","deviceKey":"test","title":"扫码登录","body":"二维码十分钟有效","qrPayload":"webbridgekit://login/request-42"}'

curl http://localhost:8080/push \
  -H 'Content-Type: application/json' \
  -d '{"schema":"webbridgekit.message.v1","type":"otp","deviceKey":"test","title":"登录验证码","body":"五分钟内有效","verificationCode":"482901","expiresAt":"2026-08-12T02:00:00Z"}'

curl http://localhost:8080/push \
  -H 'Content-Type: application/json' \
  -d '{"schema":"webbridgekit.message.v1","type":"chat","deviceKey":"test","title":"林默发来新消息","body":"部署日志已经补充好了","appId":"com.example.team-chat","route":"/conversations/linmo","params":{"conversationId":"linmo"}}'
```

审批使用结构化 `approval.actions`，完整示例、状态查询、提交与 Webhook 签名见 [Approval v1](approval-v1.md)。

## 自动验证

```bash
bash tools/verify-message-types-v1.sh
```

该脚本同时验证 JSON Schema、7 类有效请求和缺失类型字段的拒绝行为。
