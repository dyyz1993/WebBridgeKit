# HTML App 接入指南（渐进增强模型）

任何 HTTPS 网页都是潜在的 WebBridgeKit HTML App。接入采用渐进增强：接入成本从零开始，
每多做一点，解锁一层能力；没有强制项。

协议细节见 [Push v2](push-v2.md)、[Gateway v1](gateway-v1.md)、[Message Types v1](message-types-v1.md)
与 [Offline Package v1](offline-package-v1.md)。

## 三层成本收益表

| 层级 | 网站方成本 | 解锁能力 | 用户侧体验 |
|---|---|---|---|
| **第 0 层 · 展示** | **零改造**：任何 HTTPS 页面原样注册即可 | 在 App 内打开、书签、签名信任、清单版本化缓存（含离线秒开） | 贴网址 → 自动识别 → 点「添加」（约 5 秒） |
| **第 1 层 · 深链** | 子页面路径化（`/order/123`）。服务端渲染站点天然满足；纯 hash 路由 SPA 需将关键页改为路径路由 | **推送直达任意白名单子页面/路由**（普通 PWA 桌面推送只能回到首页，这是本平台的核心差异） | 点横幅直接落到订单详情/会话/审批单 |
| **第 2 层 · 能力** | 引入一行 `<script src="WebBridge.js">`，按需调用 `WebBridge.scan()` 等 | 原生设备能力：扫码、相机、定位、剪贴板、震动、通知、缓存控制等 30+ bridge handler | 首次使用敏感能力时 iOS 系统弹窗授权一次 |
| **推送触达**（横切） | 网站后端调用推送 API | 主动向用户发送七类规范消息（普通/Markdown/验证码/二维码/图片/聊天/审批） | 通知横幅 + 原生收件箱（离线可查、可撤回） |

## 信任模型（为什么需要网关）

宿主授予 HTML 页面原生能力与推送深链，因此必须存在签名信任边界：

- **网关**是签名机，不是审核门槛：任何人可自建（开源实现即本仓库 `Server/`），
  注册即签发，不对应用做人为审批。
- 页面自带的 `manifest.webmanifest` 描述「我是谁」（图标/主题/起始页），
  但它是页面自声明的，不能作为授予原生能力的依据。
- 宿主的 HTML App 清单（appId、allowedOrigins、routes、capabilities）由网关
  Ed25519 私钥签名；App 端验签后才信任对应能力与路由。
- 推送深链只允许落在签名清单的 `routes` 白名单内，杜绝「横幅钓鱼」。
- 敏感能力遵循**双重门**：清单声明（签名）授予资格，iOS 系统弹窗完成最终用户授权；
  用户可随时在宿主权限面板查看并撤回任一应用的能力。

## 注册一个 HTML App（第 0 层，一条命令）

```bash
curl -X POST "https://<gateway>/api/v1/html-apps" \
  -H "Authorization: Bearer <ADMIN_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{
    "schemaVersion": "1",
    "appId": "com.example.shop",
    "name": "示例商城",
    "startURL": "https://shop.example.com/index.html",
    "allowedOrigins": ["https://shop.example.com"],
    "capabilities": ["notification"],
    "routes": ["/index.html", "/order", "/order/detail"],
    "cache": {"strategy": "manifest", "version": "v1", "persistent": true}
  }'
```

清单字段校验规则（服务端强制）：

- `appId`：唯一、≤64 字符、仅 `A-Za-z0-9._-`
- `startURL`：必须 HTTPS；其 origin 必须出现在 `allowedOrigins`（精确、去重）
- `routes`：以 `/` 开头且非空；推送深链只能命中这些路径
- `cache.version`：非空；策略 `manifest` / `none`

## 深链推送（第 1 层）

```json
POST /push
{
  "device_key": "<用户推送身份>",
  "title": "订单已发货",
  "body": "订单 #12345 已由顺丰揽收",
  "appId": "com.example.shop",
  "route": "/order/detail?id=12345"
}
```

`appId + route` 命中已注册签名清单后，横幅点击直接打开该 PWA 的对应子页面。
未注册或路由不在白名单时退回普通通知。消息同时进入原生收件箱，晚点开依然深链。

## 原生能力（第 2 层）

```html
<script src="https://<fixtures-host>/test_resources/WebBridge.js"></script>
<script>
  WebBridge.scan().then(code => { /* 扫码结果 */ });
  WebBridge.haptic();
</script>
```

能力必须在清单 `capabilities` 中声明（如 `camera`、`location`、`scan`、`clipboard`），
未声明的能力调用会被宿主拒绝。参考实现见 `test_resources/pwa-notification/`。

## 用户侧流程（总结）

1. 贴网址 → 宿主自动抓取 `manifest.webmanifest` 预填名称/图标/起始页
2. 确认「添加」→ 网关自动签发清单（用户无感）
3. 之后：推送点横幅直达子页面；敏感能力首次使用时系统弹窗一次
4. 随时可在权限面板查看/撤回任一应用的能力
