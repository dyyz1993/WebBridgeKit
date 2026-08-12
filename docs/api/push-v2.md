# WebBridgeKit Push v2

Push v2 是官方版与自托管版共同使用的开放通知协议。最小请求保持 Bark 兼容；结构化字段用于驱动原生 Inbox；需要业务交互时只路由到已注册且受信任的 HTML App/PWA。

新的审批接入统一使用 [Approval v1](approval-v1.md)。Approval v1 使用扁平公共字段、原生/Web/PWA 三种呈现方式、官方状态查询和可选签名 Webhook；本页下方的旧审批字段仅用于现有实现迁移。

7 类规范消息的必填字段、UI 映射和最小 curl 示例见 [Message Types v1](message-types-v1.md)。

## 发送入口

- JSON：`POST /push`
- Bark 兼容：`GET|POST /:deviceKey/:title/:body`

最小 JSON：

```json
{
  "device_key": "device-key",
  "title": "通知标题",
  "body": "通知正文"
}
```

## 字段与原生渲染

| 字段 | 类型 | Inbox 行为 |
|---|---|---|
| `title`, `subtitle`, `body` | string | 标题、来源/副标题、摘要与详情正文 |
| `category` | string | `otp`, `chat`, `approval`, `task`, `security` 等分类图标和标签 |
| `contentType` | string | `plain`, `markdown`, `image`, `qr`, `approval`, `otp`, `chat` |
| `markdown` | string | 原生详情中的 Markdown 内容；Bark 查询 `markdown=1` 表示正文就是 Markdown |
| `verificationCode` | string | 验证码卡片与复制操作 |
| `qrPayload` | string | 在详情页由宿主生成二维码，不要求远端图片 |
| `image`, `icon` | URL string | 媒体或来源图标 |
| `group`, `threadId` | string | Inbox 分组与 APNs 线程 |
| `level` | string | `passive`, `active`, `timeSensitive`, `critical` |
| `sound`, `badge`, `volume`, `call` | mixed | APNs/Bark 提示行为 |
| `copy`, `autoCopy`, `isArchive` | mixed | 复制和归档兼容能力 |
| `id` | string | 可更新/撤回消息的稳定标识 |
| `revision` | integer | 单调递增版本；客户端忽略更旧状态 |
| `delete` | boolean | 撤回同一 `id` 的消息 |
| `expiresAt`, `ttl` | string/number | 过期时间或相对秒数 |
| `actionState` | string | `pending`, `approved`, `rejected`, `cancelled`, `expired`；只有 `pending` 进入“待处理” |
| `requestId` | string | 通知与 PWA 业务请求共享的标识 |
| `appId`, `route`, `params` | mixed | 路由到已注册 HTML App；路由和来源仍需本地清单校验 |
| `display` | string | `sheet`, `full`, `inline`；当前原生版支持 sheet/full，inline 暂回退为 sheet |
| `statePath` | string | 交给目标 PWA 的状态查询路径；宿主不携带业务凭据代替 PWA 审批 |

兼容字段 `appid` 与 `mode=normal|modal|immersive` 会继续接受。推荐新接入使用 `appId` 与 `display`。

## 验证码

```json
{
  "device_key": "device-key",
  "title": "登录验证码",
  "body": "验证码 482 901，5 分钟内有效",
  "category": "otp",
  "contentType": "otp",
  "verificationCode": "482 901",
  "copy": "482901",
  "expiresAt": "2026-08-11T14:35:00Z",
  "id": "otp-login-42"
}
```

## Markdown 与二维码

```json
{
  "device_key": "device-key",
  "title": "部署结果",
  "body": "生产环境部署完成",
  "contentType": "markdown",
  "markdown": "## 部署完成\n\n- 环境：生产\n- 结果：**成功**",
  "qrPayload": "https://example.com/builds/42",
  "id": "deploy-42"
}
```

## 待确认与状态更新

首次推送：

```json
{
  "device_key": "device-key",
  "title": "需要确认生产发布",
  "body": "打开审批页检查变更后再确认",
  "category": "approval",
  "contentType": "approval",
  "actionState": "pending",
  "requestId": "approval-42",
  "id": "approval-42",
  "revision": 1,
  "appId": "com.example.agent-console",
  "route": "/approvals/approval-42",
  "params": { "requestId": "approval-42" },
  "display": "sheet",
  "statePath": "/api/approvals/approval-42"
}
```

业务系统完成审批后，再发送同一 `id` 且更高 `revision`：

```json
{
  "device_key": "device-key",
  "title": "生产发布已通过",
  "body": "审批状态已同步",
  "category": "approval",
  "contentType": "approval",
  "actionState": "approved",
  "requestId": "approval-42",
  "id": "approval-42",
  "revision": 2
}
```

Push 只能定位待确认请求，不能代表用户批准。目标 PWA 必须使用自己的登录态向业务 API 提交操作，并从 `statePath` 或其既有 API 重新读取权威状态。未经本地清单验证的 `appId + route`、远端 HTML 字符串或推送中携带的执行指令都不能直接获得敏感能力。
