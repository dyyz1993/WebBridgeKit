# WebBridgeKit Approval v1 设计

日期：2026-08-11

## 决策摘要

WebBridgeKit 将审批定义为消息的业务类型，将呈现方式定义为独立维度。Approval v1 同时支持：

- `native`：官方服务器保存审批状态，iOS 原生渲染选项和回填；适合一条 `curl` 开箱即用。
- `web`：打开任意经过 HTTPS 校验的外部页面；页面及其源站处理查询、提交和多人状态。
- `pwa`：通过已注册的 `appId + route` 打开受信任 PWA；适合需要 Manifest、受控 Bridge 和离线能力的业务。

推送不得携带原始 HTML。`approval` 与 `web/html` 不再混成同一个字段。

## 目标

1. 官方 App 用户无需配置 Gateway，即可复制设备 Key 后通过一条 `curl` 创建原生审批。
2. 已有业务页面的接入方可直接携带 HTTPS 页面地址，不必迁移到原生表单协议。
3. 简单审批由官方服务提供状态查询和可选 Webhook；源站不必提供状态查询接口。
4. 自定义 Web/PWA 审批的业务状态仍由源站负责，WebBridgeKit 不解析页面或代替页面执行操作。
5. 敏感操作必须由用户明确触发；Push 参数只描述请求，不能作为授权凭据。

## 统一消息信封

```json
{
  "schema": "webbridgekit.message.v1",
  "type": "approval",
  "deviceKey": "DEVICE_KEY",
  "id": "approval-42",
  "requestId": "approval-42",
  "revision": 1,
  "state": "pending",
  "title": "是否发布生产环境？",
  "body": "版本 2.4.0 已通过测试",
  "expiresAt": "2026-08-11T16:00:00Z",
  "presentation": "native",
  "approval": {}
}
```

公共字段全部放在顶层，避免多层对象。`id` 是 Inbox 更新标识；`requestId` 是审批请求标识。两者可以相同。`revision` 必须单调递增。状态为 `pending`, `approved`, `rejected`, `cancelled`, `expired`。

`presentation` 是顶层字符串，取值为 `native`, `web`, `pwa`。`url`, `appId`, `route`, `params`, `display` 等通用路由字段也保持在顶层。只有 actions、回填要求和响应方式等审批专属字段进入 `approval` 对象。

## 模式一：原生标准审批

```json
{
  "schema": "webbridgekit.message.v1",
  "type": "approval",
  "deviceKey": "DEVICE_KEY",
  "id": "approval-42",
  "requestId": "approval-42",
  "revision": 1,
  "state": "pending",
  "title": "是否发布生产环境？",
  "body": "版本 2.4.0 已通过测试",
  "presentation": "native",
  "approval": {
    "actions": [
      { "id": "approve", "title": "通过", "style": "primary", "resultState": "approved" },
      { "id": "reject", "title": "拒绝", "style": "destructive", "requiresReason": true, "resultState": "rejected" }
    ],
    "responseMode": "webhook",
    "responseURL": "https://example.com/webhooks/webbridgekit"
  }
}
```

`approval.responseMode` 支持：

- `poll`：不要求源站提供任何接口；调用方查询官方状态接口。
- `webhook`：官方服务器将响应投递到 `responseURL`，并同时保留官方查询结果。

官方状态查询：

```http
GET /api/v1/approvals/{requestId}
Authorization: Bearer {deviceKey}
```

源站不需要提供状态查询地址。`responseURL` 只保存在官方服务器，不进入 APNs Payload。

### 标准 Webhook

```http
POST {responseURL}
Content-Type: application/json
X-WBK-Delivery-Id: evt-123
X-WBK-Timestamp: 1786433400
X-WBK-Signature: v1=<hmac-sha256>
```

```json
{
  "schema": "webbridgekit.approval-response.v1",
  "eventId": "evt-123",
  "requestId": "approval-42",
  "revision": 2,
  "actionId": "approve",
  "values": {},
  "respondedAt": "2026-08-11T15:30:00Z"
}
```

源站返回任意 `2xx` 表示收到。非 `2xx` 或超时触发持久化重试。源站使用 `eventId` 幂等。审批状态与 Webhook 投递状态分开保存；用户决定已经发生，不因临时回调失败而丢失。

## 模式二：自定义 Web 审批

```json
{
  "schema": "webbridgekit.message.v1",
  "type": "approval",
  "deviceKey": "DEVICE_KEY",
  "id": "approval-42",
  "requestId": "approval-42",
  "revision": 1,
  "state": "pending",
  "title": "需要确认生产发布",
  "body": "打开业务页面处理",
  "presentation": "web",
  "url": "https://example.com/approvals/42",
  "display": "sheet"
}
```

WebBridgeKit 只显示通知并打开页面。页面和源站负责身份、查询、表单、响应、多人同步和业务结果。完成后源站发送相同 `id`、更高 `revision` 的 Push 更新 Inbox。

外部页面必须使用 HTTPS。原生容器显示真实来源，不授予敏感 Bridge 能力，不自动推断页面内的审批结果。

## 模式三：受信任 PWA 审批

```json
{
  "schema": "webbridgekit.message.v1",
  "type": "approval",
  "deviceKey": "DEVICE_KEY",
  "id": "approval-42",
  "requestId": "approval-42",
  "revision": 1,
  "state": "pending",
  "title": "需要确认生产发布",
  "presentation": "pwa",
  "appId": "com.example.console",
  "route": "/approvals/approval-42",
  "params": { "requestId": "approval-42" },
  "display": "sheet"
}
```

宿主必须验证本地 Manifest、精确来源和允许路由。PWA 自己处理审批业务。Push 不能授予能力或直接批准。

## 兼容与归一化

项目尚未上线，Approval v1 采用浅层结构作为规范，不保留旧审批协议的长期兼容负担。服务端可以在入口短期接受 `device_key`, `contentType`, `actionState`, `url`, `appId`, `route` 等现有字段，并立即归一化为 v1；文档和返回值只展示 v1。

不得接受 `html` 字符串。`web` 只接受 URL，`pwa` 只接受 `appId + route`。

## 安全与失败处理

- 创建和查询使用设备 Key；设备响应使用安装时生成并保存在 Keychain 的设备凭据。
- 回调仅允许 HTTPS，拒绝 localhost、私网、链路本地、含用户信息的 URL 和不安全重定向。
- Webhook 使用时间戳、投递 ID 和 HMAC 签名，限制重放窗口。
- 原生审批使用 compare-and-set：仅 `pending` 且 revision 匹配时接受第一份响应。
- 回调重试必须持久化，服务重启后继续；达到上限后状态为 `delivery.failed`，允许人工重试。
- 任意 Web 页面不获得敏感 Bridge；只有已注册 PWA 可申请 Manifest 声明的能力。

## 状态模型

原生审批包含两个独立状态：

```json
{
  "state": "approved",
  "revision": 2,
  "delivery": {
    "state": "delivered",
    "attempts": 1,
    "lastAttemptAt": "2026-08-11T15:30:01Z"
  }
}
```

审批状态描述用户选择；投递状态描述 Webhook 是否送达。两者不得混用。

## 实施顺序

1. 定义 OpenAPI 和四份 JSON Schema：消息、审批创建、审批响应、审批状态。
2. Swift 服务端增加持久化 ApprovalStore、创建/响应/查询路由和回调投递器。
3. iOS 增加原生 action/回填 UI、提交中状态和冲突处理。
4. 正式化 `web` 受限容器与 `pwa` 可信路由。
5. 增加 `tools/verify-approval-v1.sh`，覆盖 Schema、查询、第一响应生效、签名、幂等、过期、重试和 SSRF。

## 验收标准

- 官方 App 无需 Gateway 即可通过一条 `curl` 创建原生审批。
- `poll` 模式下源站不提供任何接口也能查询结果。
- `webhook` 模式按标准请求体和签名投递，重复事件不重复生效。
- 相同请求的第二份响应返回冲突，不能覆盖第一份有效响应。
- Web 和 PWA 页面可以完全自定义，但不得携带原始 HTML。
- 旧 revision、过期请求、不安全回调地址和未注册 PWA 路由均被拒绝。
- 自动验证脚本输出零失败，服务端测试、iOS 单测、UI 回归和崩溃扫描通过。

## ADR：采用双轨呈现而非单一路径

### 决策

Approval v1 采用统一生命周期信封与 `native/web/pwa` 三种呈现方式。原生模式由官方服务管理响应；Web/PWA 模式由页面源站管理业务。

### 理由

只做原生协议会限制业务表单；只做 HTML 会破坏“一条 curl 即用”的官方体验。双轨方案把复杂度放在明确的扩展点，同时保持普通用户低门槛。

### 代价

服务端与 iOS 需要实现原生审批闭环，并维护外部 Web 与可信 PWA 两个不同安全等级。协议通过独立的顶层 `presentation` 字段避免三种模式互相污染，同时将嵌套限制在审批专属的 `approval` 对象内。
