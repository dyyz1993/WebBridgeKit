# WebBridgeKit 测试数据 Case 文档

> 本文档维护所有模块的测试数据，覆盖正常 case + 边界 case，用于单元测试、集成测试和 UI 验证。
>
> 最后更新：2026-05-10

---

## 目录

1. [服务器配置（ServerConfig）](#1-服务器配置serverconfig)
2. [推送 Token（AccessToken）](#2-推送-tokenaccesstoken)
3. [缓存应用（Manifest/CacheEntry）](#3-缓存应用manifestcacheentry)
4. [消息（Message/PushNotification）](#4-消息messagepushnotification)
5. [收藏夹（URLFavorite）](#5-收藏夹urlfavorite)
6. [访问历史（WebPageHistory）](#6-访问历史webpagehistory)
7. [密钥（APIKey）](#7-密钥apikey)
8. [口令（CommandToken）](#8-口令commandtoken)
9. [缓存规则（CacheRule）](#9-缓存规则cacherule)
10. [页面缓存规则（PageCacheRule）](#10-页面缓存规则pagecacherule)
11. [缓存统计（WebCacheStatistics）](#11-缓存统计webcachestatistics)
12. [缓存统计信息（CacheStats）](#12-缓存统计信息cachestats)
13. [消息路由（MessageRouter/RouteTarget）](#13-消息路由messagerouterroutetarget)
14. [设备注册（DeviceRegistration）](#14-设备注册deviceregistration)
15. [Manifest 验证（ManifestValidationResult）](#15-manifest-验证manifestvalidationresult)
16. [错误数据（WebBridgeError/ManifestError）](#16-错误数据webbridgeerrormanifesterror)

---

## 1. 服务器配置（ServerConfig）

> 模型：`SuperApp/Sources/Models/ServerConfig.swift`
> 字段：`id`, `serverType`, `baseURL`, `apiEndpoint`, `isActive`, `updatedAt`

### Case 1.1: 默认服务器（内置）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"default"` | 固定 ID |
| serverType | `"default"` | 默认类型 |
| baseURL | `nil` | 使用内置地址 |
| apiEndpoint | `nil` | 使用默认端点 |
| isActive | `true` | 激活状态 |
| updatedAt | `2026-05-10T08:00:00Z` | 更新时间 |

```json
{
  "id": "default",
  "serverType": "default",
  "baseURL": null,
  "apiEndpoint": null,
  "isActive": true,
  "updatedAt": "2026-05-10T08:00:00Z"
}
```

### Case 1.2: 自定义服务器（Hummingbird 本地）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"local-hb"` | 自定义 ID |
| serverType | `"custom"` | 自定义类型 |
| baseURL | `"http://localhost:8080"` | 本地开发服务器 |
| apiEndpoint | `"/push"` | 推送端点 |
| isActive | `true` | 激活 |

```json
{
  "id": "local-hb",
  "serverType": "custom",
  "baseURL": "http://localhost:8080",
  "apiEndpoint": "/push",
  "isActive": true,
  "updatedAt": "2026-05-10T08:00:00Z"
}
```

**fullAPIURL**: `http://localhost:8080/push`

### Case 1.3: 远程生产服务器

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"prod-server"` | 生产 ID |
| serverType | `"custom"` | 自定义类型 |
| baseURL | `"https://api.webbridgekit.com"` | 生产 API |
| apiEndpoint | `"/v1/push"` | V1 推送端点 |
| isActive | `true` | 激活 |

```json
{
  "id": "prod-server",
  "serverType": "custom",
  "baseURL": "https://api.webbridgekit.com",
  "apiEndpoint": "/v1/push",
  "isActive": true,
  "updatedAt": "2026-05-09T12:00:00Z"
}
```

### Case 1.4: 未激活的自定义服务器（边界）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"inactive-test"` | 测试用 |
| serverType | `"custom"` | 自定义 |
| baseURL | `"https://staging.webbridgekit.com"` | 测试环境 |
| apiEndpoint | `"/api/push"` | 测试端点 |
| isActive | `false` | 未激活 |

### Case 1.5: 无效 URL 服务器（错误处理）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"bad-url"` | 无效配置 |
| serverType | `"custom"` | 自定义 |
| baseURL | `"not-a-valid-url"` | 无效 URL |
| apiEndpoint | `nil` | 无端点 |
| isActive | `true` | 激活但不可用 |

**fullAPIURL**: `nil`（URL 解析失败）

---

## 2. 推送 Token（AccessToken）

> 模型：`SuperApp/Sources/Models/AccessToken.swift`
> 字段：`id`, `url`, `token`, `title`, `validDuration`, `createdAt`, `expiresAt`, `accessCount`

### Case 2.1: 永久有效 Token

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"token-perm-001"` | UUID |
| url | `"https://api.webbridgekit.com"` | 服务器地址 |
| token | `"ABC123XYZ"` | 8位口令码 |
| title | `"我的永久口令"` | 名称 |
| validDuration | `-1` | 永久有效 |
| createdAt | `2026-01-01T00:00:00Z` | 创建时间 |
| expiresAt | `2026-01-01T00:00:00Z` | 不使用 |
| accessCount | `42` | 访问次数 |

**isPermanent**: `true`
**isExpired**: `false`
**remainingTimeText**: 永久有效

### Case 2.2: 有效期内的 Token

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"token-active-002"` | UUID |
| url | `"http://localhost:8080"` | 本地服务器 |
| token | `"WXyz7890"` | 8位口令码 |
| title | `"临时测试口令"` | 名称 |
| validDuration | `86400` | 24小时（秒） |
| createdAt | `2026-05-10T08:00:00Z` | 刚创建 |
| expiresAt | `2026-05-11T08:00:00Z` | 明天过期 |
| accessCount | `3` | 访问次数 |

**isPermanent**: `false`
**isExpired**: `false`
**remainingTimeText**: `"23小时 59分"`

### Case 2.3: 已过期 Token

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"token-expired-003"` | UUID |
| url | `"http://localhost:8080"` | 本地 |
| token | `"EXPIRED!"` | 口令码 |
| title | `"过期口令"` | 名称 |
| validDuration | `3600` | 1小时 |
| createdAt | `2026-05-01T00:00:00Z` | 创建 |
| expiresAt | `2026-05-01T01:00:00Z` | 已过期 |
| accessCount | `15` | 访问次数 |

**isExpired**: `true`
**remainingTimeText**: `"已过期"`

### Case 2.4: 7天有效期 Token

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"token-7day-004"` | UUID |
| url | `"https://api.webbridgekit.com"` | 远程 |
| token | `"WeekTokn"` | 口令码 |
| title | `"周卡口令"` | 名称 |
| validDuration | `604800` | 7天 |
| createdAt | `2026-05-08T00:00:00Z` | 创建 |
| expiresAt | `2026-05-15T00:00:00Z` | 5天后过期 |
| accessCount | `0` | 未使用 |

**remainingTimeText**: `"4天 23小时"`

### Case 2.5: 空 Token（未注册）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"token-empty-005"` | UUID |
| url | `""` | 空 |
| token | `""` | 空 |
| title | `nil` | 无标题 |
| validDuration | `0` | 无有效期 |
| createdAt | `2026-05-10T00:00:00Z` | 创建 |
| expiresAt | `2026-05-10T00:00:00Z` | 已过期 |
| accessCount | `0` | 未使用 |

---

## 3. 缓存应用（Manifest/CacheEntry）

> 客户端模型：`Sources/Models/ManifestModels.swift`
> 服务端模型：`Server/Sources/WebBridgeServer/Models/Manifest.swift`
> 缓存条目：`Sources/Models/CacheEntryRealm.swift`

### Case 3.1: 天气应用（已缓存，完整 Manifest）

```json
{
  "resources": {
    "index.html": "https://cdn.weather.com/app/index.html",
    "styles/main.css": "https://cdn.weather.com/app/styles/main.css",
    "scripts/weather.js": "https://cdn.weather.com/app/scripts/weather.js",
    "images/sunny.svg": "https://cdn.weather.com/app/images/sunny.svg",
    "images/cloudy.svg": "https://cdn.weather.com/app/images/cloudy.svg",
    "images/rainy.svg": "https://cdn.weather.com/app/images/rainy.svg",
    "data/cities.json": "https://cdn.weather.com/app/data/cities.json"
  },
  "version": "1.2.0",
  "persistent": true,
  "lastUpdated": "2026-05-10T06:00:00Z",
  "appid": "com.weather.daily",
  "name": "天气预报",
  "icon": "https://cdn.weather.com/app/icon-192.png",
  "isPinned": true,
  "isFavorite": true,
  "lastAccessed": "2026-05-10T07:30:00Z",
  "accessCount": 128
}
```

**对应 CacheEntryRealm 条目**：

| key | url | mimeType | originalSize | compressedSize | resourceType |
|-----|-----|----------|-------------|----------------|-------------|
| `weather_index_html` | `https://cdn.weather.com/app/index.html` | `text/html` | 24576 | 8192 | html |
| `weather_main_css` | `https://cdn.weather.com/app/styles/main.css` | `text/css` | 32768 | 6144 | stylesheet |
| `weather_js` | `https://cdn.weather.com/app/scripts/weather.js` | `application/javascript` | 102400 | 30720 | script |
| `weather_sunny_svg` | `https://cdn.weather.com/app/images/sunny.svg` | `image/svg+xml` | 4096 | 2048 | image |
| `weather_cities_json` | `https://cdn.weather.com/app/data/cities.json` | `application/json` | 16384 | 4096 | json |

**CacheMemoryInfo 汇总**：
- totalEntries: 5
- totalOriginalSize: 180,224 bytes
- totalCompressedSize: 51,200 bytes
- compressionRatio: 0.284 (71.6% 节省)
- savedSpace: 129,024 bytes

### Case 3.2: 笔记应用（已缓存，Markdown 编辑器风格）

```json
{
  "resources": {
    "index.html": "https://notes.md/editor/index.html",
    "editor.css": "https://notes.md/editor/editor.css",
    "marked.min.js": "https://notes.md/editor/marked.min.js",
    "highlight.js": "https://notes.md/editor/highlight.js",
    "editor.js": "https://notes.md/editor/editor.js"
  },
  "version": "2.0.1",
  "persistent": true,
  "lastUpdated": "2026-05-09T12:00:00Z",
  "appid": "md-notes-editor",
  "name": "Markdown 笔记",
  "icon": "https://notes.md/icon.png",
  "isPinned": false,
  "isFavorite": true,
  "lastAccessed": "2026-05-10T09:00:00Z",
  "accessCount": 45
}
```

### Case 3.3: 电商应用（大缓存，淘宝/京东风格）

```json
{
  "resources": {
    "index.html": "https://m.shop.example.com/index.html",
    "static/css/app.css": "https://m.shop.example.com/static/css/app.css",
    "static/js/vendor.js": "https://m.shop.example.com/static/js/vendor.js",
    "static/js/app.js": "https://m.shop.example.com/static/js/app.js",
    "static/js/chunk-home.js": "https://m.shop.example.com/static/js/chunk-home.js",
    "static/js/chunk-product.js": "https://m.shop.example.com/static/js/chunk-product.js",
    "static/js/chunk-cart.js": "https://m.shop.example.com/static/js/chunk-cart.js",
    "static/images/banner1.webp": "https://m.shop.example.com/static/images/banner1.webp",
    "static/images/banner2.webp": "https://m.shop.example.com/static/images/banner2.webp",
    "static/images/banner3.webp": "https://m.shop.example.com/static/images/banner3.webp",
    "static/fonts/iconfont.woff2": "https://m.shop.example.com/static/fonts/iconfont.woff2",
    "static/data/categories.json": "https://m.shop.example.com/static/data/categories.json"
  },
  "version": "3.5.2",
  "persistent": false,
  "lastUpdated": "2026-05-10T00:00:00Z",
  "appid": "shop-mall-app",
  "name": "优购商城",
  "icon": "https://m.shop.example.com/static/icon.png",
  "isPinned": false,
  "isFavorite": false,
  "lastAccessed": "2026-05-10T10:00:00Z",
  "accessCount": 256
}
```

**大缓存 CacheEntryRealm 条目**：

| key | mimeType | originalSize | compressedSize | resourceType |
|-----|----------|-------------|----------------|-------------|
| `shop_vendor_js` | `application/javascript` | 524288 | 153600 | script |
| `shop_app_js` | `application/javascript` | 204800 | 61440 | script |
| `shop_banner1_webp` | `image/webp` | 81920 | 77824 | image |
| `shop_iconfont_woff2` | `font/woff2` | 45056 | 43008 | font |
| `shop_categories_json` | `application/json` | 32768 | 8192 | json |

### Case 3.4: 游戏应用（临时缓存，小游戏平台风格）

```json
{
  "resources": {
    "index.html": "https://play.casual.games/tetris/index.html",
    "game.js": "https://play.casual.games/tetris/game.js",
    "sprites.png": "https://play.casual.games/tetris/sprites.png",
    "sounds/bgm.mp3": "https://play.casual.games/tetris/sounds/bgm.mp3",
    "sounds/clear.wav": "https://play.casual.games/tetris/sounds/clear.wav"
  },
  "version": "1.0.0",
  "persistent": false,
  "lastUpdated": "2026-05-10T08:00:00Z",
  "appid": "game-tetris",
  "name": "俄罗斯方块",
  "icon": "https://play.casual.games/tetris/icon.png",
  "isPinned": false,
  "isFavorite": false,
  "lastAccessed": "2026-05-10T08:30:00Z",
  "accessCount": 7
}
```

**CacheEntryRealm 包含音频资源**：

| key | mimeType | originalSize | resourceType |
|-----|----------|-------------|-------------|
| `game_bgm_mp3` | `audio/mpeg` | 1048576 | audio |
| `game_clear_wav` | `audio/wav` | 20480 | audio |
| `game_sprites_png` | `image/png` | 65536 | image |
| `game_js` | `application/javascript` | 40960 | script |

### Case 3.5: 新闻应用（过期缓存，RSS/Feed 风格）

```json
{
  "resources": {
    "index.html": "https://news.daily/feed/index.html",
    "feed.js": "https://news.daily/feed/feed.js",
    "styles.css": "https://news.daily/feed/styles.css"
  },
  "version": "1.1.0",
  "persistent": true,
  "lastUpdated": "2026-03-01T00:00:00Z",
  "appid": "news-daily-feed",
  "name": "每日新闻",
  "icon": "https://news.daily/icon.png",
  "isPinned": false,
  "isFavorite": false,
  "lastAccessed": "2026-04-01T00:00:00Z",
  "accessCount": 30
}
```

**isExpired(expirationDays: 30)**: `true`（最后更新距今超过30天）

### Case 3.6: 技术文档站（已缓存）

```json
{
  "resources": {
    "index.html": "https://docs.swift.org/getting-started/index.html",
    "css/theme.css": "https://docs.swift.org/css/theme.css",
    "js/search.js": "https://docs.swift.org/js/search.js",
    "js/navigation.js": "https://docs.swift.org/js/navigation.js"
  },
  "version": "1.0.0",
  "persistent": true,
  "lastUpdated": "2026-05-08T00:00:00Z",
  "appid": "swift-docs",
  "name": "Swift 文档",
  "icon": "https://docs.swift.org/favicon.ico",
  "isPinned": true,
  "isFavorite": true,
  "lastAccessed": "2026-05-10T06:00:00Z",
  "accessCount": 200
}
```

### Case 3.7: 后台管理面板（已缓存）

```json
{
  "resources": {
    "index.html": "https://admin.example.com/dashboard/index.html",
    "static/app.css": "https://admin.example.com/static/app.css",
    "static/app.js": "https://admin.example.com/static/app.js",
    "static/charts.js": "https://admin.example.com/static/charts.js"
  },
  "version": "2.3.0",
  "persistent": true,
  "lastUpdated": "2026-05-07T00:00:00Z",
  "appid": "admin-dashboard",
  "name": "管理后台",
  "icon": "https://admin.example.com/static/logo.png",
  "isPinned": false,
  "isFavorite": true,
  "accessCount": 88
}
```

### Case 3.8: 空 Manifest（边界：无资源）

```json
{
  "resources": {},
  "version": "0.0.1"
}
```

**validate()**: `.invalid([.missingRequiredField("resources")])`

### Case 3.9: 最小有效 Manifest（边界）

```json
{
  "resources": {
    "index.html": "https://example.com/index.html"
  }
}
```

**validate()**: `.validWithWarnings(["No version specified, using default version"])`
**resolvedVersion**: `"0.0.1"`

### Case 3.10: 无效资源路径 Manifest（安全边界）

```json
{
  "resources": {
    "../../../etc/passwd": "https://evil.com/steal",
    "/absolute/path": "https://evil.com/path",
    "valid.html": "ftp://invalid-scheme.com/file"
  },
  "version": "1.0.0"
}
```

**validate()**: `.invalid([path traversal, absolute path, invalid scheme])`

### Case 3.11: 视频/多媒体缓存 CacheEntry

| key | url | mimeType | originalSize | compressedSize | resourceType |
|-----|-----|----------|-------------|----------------|-------------|
| `video_intro_mp4` | `https://cdn.example.com/intro.mp4` | `video/mp4` | 5242880 | 5242880 | video |
| `audio_podcast_mp3` | `https://podcast.example.com/ep001.mp3` | `audio/mpeg` | 20971520 | 20971520 | audio |

**注意**：视频/音频文件通常不压缩（compressedSize == originalSize）

---

## 4. 消息（Message/PushNotification）

> 消息载荷：`Sources/Message/Protocols/MessageChannel.swift` — `MessagePayload`
> 存储消息：`Sources/Message/Protocols/MessageStore.swift` — `StoredMessage`
> 推送载荷：`Server/Sources/WebBridgeServer/Models/PushPayload.swift` — `PushPayload`
> 消息引擎：`Sources/Message/MessageEngine.swift`

### Case 4.1: APNs 推送消息（标准格式）

```json
{
  "id": "msg-apns-001",
  "title": "天气预报",
  "body": "今天北京晴，25°C，适合户外活动",
  "subtitle": "北京",
  "channel": "apns",
  "category": "weather",
  "priority": "normal",
  "sound": "default",
  "badge": 3,
  "group": "weather-updates",
  "threadId": "weather-beijing",
  "targetURL": "https://weather.com/beijing",
  "targetAppId": null,
  "targetMode": null,
  "userInfo": {
    "city": "beijing",
    "temperature": "25"
  },
  "createdAt": "2026-05-10T08:00:00Z"
}
```

### Case 4.2: Bark 推送消息

```json
{
  "id": "msg-bark-002",
  "title": "服务器告警",
  "body": "CPU 使用率超过 90%，请及时处理",
  "subtitle": null,
  "channel": "bark",
  "category": "alert",
  "priority": "high",
  "sound": "alarm.caf",
  "badge": 1,
  "group": "server-alerts",
  "threadId": "server-prod-01",
  "targetURL": "https://monitor.example.com/dashboard",
  "targetAppId": null,
  "targetMode": null,
  "userInfo": {
    "server": "prod-01",
    "metric": "cpu",
    "threshold": "90"
  },
  "createdAt": "2026-05-10T09:15:00Z"
}
```

**BarkChannel 配置**：

```swift
BarkChannel(
  serverURL: "https://api.day.app",
  key: "AbCdEfGh1234",
  configuration: BarkConfiguration(
    icon: "https://monitor.example.com/icon.png",
    isArchive: true,
    copyable: true
  )
)
```

**生成的 Bark URL**: `https://api.day.app/AbCdEfGh1234/服务器告警/CPU使用率超过90%?group=server-alerts&url=https://monitor.example.com/dashboard&level=active&isArchive=1&copyable=1`

### Case 4.3: Bridge 本地消息（Web 小程序跳转）

```json
{
  "id": "msg-bridge-003",
  "title": "订单已确认",
  "body": "您的订单 #20260510001 已确认，预计明天送达",
  "subtitle": "优购商城",
  "channel": "bridge",
  "category": "order",
  "priority": "normal",
  "sound": null,
  "badge": null,
  "group": "shop-orders",
  "threadId": "order-20260510001",
  "targetURL": null,
  "targetAppId": "shop-mall-app",
  "targetMode": "modal",
  "userInfo": {
    "orderId": "20260510001",
    "status": "confirmed"
  },
  "createdAt": "2026-05-10T10:30:00Z"
}
```

**hasRoute**: `true`（有 targetAppId）
**RouteTarget**: `RouteTarget(type: .appId, destination: "shop-mall-app", mode: "modal")`

### Case 4.4: 系统消息（低优先级）

```json
{
  "id": "msg-sys-004",
  "title": "系统维护通知",
  "body": "系统将于今晚 22:00-23:00 进行维护升级",
  "subtitle": null,
  "channel": "system",
  "category": "system",
  "priority": "low",
  "sound": null,
  "badge": null,
  "group": "system-notices",
  "targetURL": null,
  "targetAppId": null,
  "userInfo": null,
  "createdAt": "2026-05-10T07:00:00Z"
}
```

**hasRoute**: `false`

### Case 4.5: 紧急消息（Critical 级别）

```json
{
  "id": "msg-critical-005",
  "title": "安全告警",
  "body": "检测到异常登录，请立即确认是否为本人操作",
  "subtitle": "账户安全",
  "channel": "apns",
  "category": "security",
  "priority": "critical",
  "sound": "critical.caf",
  "badge": 1,
  "group": "security-alerts",
  "targetURL": "https://account.example.com/security",
  "userInfo": {
    "alertType": "abnormal_login",
    "ip": "203.0.113.42",
    "location": "上海"
  },
  "createdAt": "2026-05-10T11:00:00Z"
}
```

### Case 4.6: Markdown 格式消息

```json
{
  "id": "msg-md-006",
  "title": "周报摘要",
  "body": "## 本周完成\n- **用户模块** 重构完成\n- *缓存优化* 性能提升 30%\n- 修复 12 个 Bug\n\n## 下周计划\n1. 新增支付模块\n2. [查看详情](https://project.example.com/weekly)",
  "channel": "bridge",
  "priority": "normal",
  "userInfo": {
    "markdown": "1",
    "bodyType": "markdown"
  }
}
```

**MarkdownProcessor 处理后 body**: `"本周完成\n- 用户模块 重构完成\n- 缓存优化 性能提升 30%\n- 修复 12 个 Bug\n\n下周计划\n1. 新增支付模块\n2. 查看详情"`

### Case 4.7: Webhook 接收消息

**Webhook 请求体**：

```json
{
  "title": "GitHub PR merged",
  "body": "feat: add dark mode support (#42)",
  "source": "github",
  "url": "https://github.com/webbridgekit/app/pull/42",
  "group": "github-notifications",
  "sound": "ping.aiff",
  "level": "active",
  "repository": "webbridgekit/app",
  "sender": "developer@example.com"
}
```

**WebhookChannel 配置**：

```swift
WebhookChannel(
  port: 8765,
  path: "/webhook",
  secret: "whsec_abcdef123456"
)
```

**签名头**: `X-Webhook-Signature: sha256=<HMAC-SHA256 hex>`

### Case 4.8: 带 Deep Link 的消息

```json
{
  "id": "msg-deeplink-008",
  "title": "新文章",
  "body": "Swift Concurrency 实践指南已发布",
  "channel": "bridge",
  "priority": "normal",
  "targetURL": "myapp://article/swift-concurrency-guide",
  "userInfo": {
    "articleId": "swift-concurrency-guide"
  }
}
```

**RouteTarget**: `RouteTarget(type: .deeplink, destination: "myapp://article/swift-concurrency-guide")`

### Case 4.9: StoredMessage（已读状态）

```json
{
  "id": "stored-read-001",
  "payload": {
    "id": "msg-apns-001",
    "title": "天气预报",
    "body": "今天北京晴，25°C",
    "channel": "apns"
  },
  "isRead": true,
  "readAt": "2026-05-10T08:05:00Z",
  "receivedAt": "2026-05-10T08:00:00Z"
}
```

### Case 4.10: StoredMessage（未读状态）

```json
{
  "id": "stored-unread-002",
  "payload": {
    "id": "msg-bark-002",
    "title": "服务器告警",
    "body": "CPU 使用率超过 90%",
    "channel": "bark"
  },
  "isRead": false,
  "readAt": null,
  "receivedAt": "2026-05-10T09:15:00Z"
}
```

### Case 4.11: PushPayload（服务端推送格式）

```json
{
  "title": "新消息提醒",
  "body": "您有3条未读消息",
  "sound": "default",
  "badge": 3,
  "icon": "https://app.example.com/icon.png",
  "group": "messages",
  "url": "https://app.example.com/inbox",
  "copy": "验证码: 839201",
  "isArchive": true
}
```

---

## 5. 收藏夹（URLFavorite）

> 模型：`Sources/Models/URLFavorite.swift`
> 字段：`id`, `url`, `title`, `favicon`, `isPinned`, `sortOrder`, `createdAt`, `enableCacheMode`

### Case 5.1: 常用网站收藏（置顶）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"fav-github-001"` | UUID |
| url | `"https://github.com"` | GitHub 首页 |
| title | `"GitHub"` | 名称 |
| favicon | `(Data)` | 图标数据 |
| isPinned | `true` | 置顶 |
| sortOrder | `0` | 第一位 |
| createdAt | `2026-01-15T08:00:00Z` | 收藏时间 |
| enableCacheMode | `false` | 未开启缓存模式 |

**domain**: `"github.com"`

### Case 5.2: 技术文档站（开启缓存）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"fav-docs-002"` | UUID |
| url | `"https://developer.apple.com/documentation"` | Apple 开发者文档 |
| title | `"Apple Developer"` | 名称 |
| isPinned | `true` | 置顶 |
| sortOrder | `1` | 第二位 |
| enableCacheMode | `true` | 开启缓存模式 |

### Case 5.3: 新闻网站（非置顶）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"fav-news-003"` | UUID |
| url | `"https://news.ycombinator.com"` | Hacker News |
| title | `"Hacker News"` | 名称 |
| isPinned | `false` | 非置顶 |
| sortOrder | `10` | 非置顶排序 |
| enableCacheMode | `false` | 无缓存 |

### Case 5.4: 搜索引擎（置顶）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"fav-google-004"` | UUID |
| url | `"https://www.google.com"` | Google |
| title | `"Google"` | 名称 |
| isPinned | `true` | 置顶 |
| sortOrder | `2` | 第三位 |

### Case 5.5: 在线工具网站

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"fav-tool-005"` | UUID |
| url | `"https://www.jsonlint.com"` | JSON 校验工具 |
| title | `"JSONLint"` | 名称 |
| isPinned | `false` | 非置顶 |
| sortOrder | `11` | 非置顶排序 |

### Case 5.6: 本地开发地址（边界）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"fav-local-006"` | UUID |
| url | `"http://localhost:8080/health"` | 本地健康检查 |
| title | `"本地服务"` | 名称 |
| isPinned | `false` | 非置顶 |
| enableCacheMode | `false` | 无缓存 |

**domain**: `"localhost"`

---

## 6. 访问历史（WebPageHistory）

> 模型：`Sources/Models/WebPageHistory.swift`
> 字段：`id`, `url`, `title`, `favicon`, `htmlPath`, `resourcePaths`, `cachedSize`, `isCached`, `isPinned`, `isFavorite`, `visitCount`, `lastVisitDate`, `cacheDate`, `thumbnail`, `ruleId`, `ruleName`, `isExcluded`

### Case 6.1: 已缓存的访问记录（天气应用）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"hist-weather-001"` | UUID |
| url | `"https://weather.com/beijing"` | 天气页面 |
| title | `"北京天气 - 实时预报"` | 页面标题 |
| favicon | `(Data)` | 网站图标 |
| htmlPath | `"/var/.../WebPageCache/hist-weather-001/index.html"` | 本地 HTML |
| resourcePaths | `["styles.css", "app.js"]` | 资源列表 |
| cachedSize | `184320` | 180 KB |
| isCached | `true` | 已缓存 |
| isPinned | `false` | 未置顶 |
| isFavorite | `true` | 已收藏 |
| visitCount | `35` | 访问次数 |
| lastVisitDate | `2026-05-10T07:30:00Z` | 最后访问 |
| cacheDate | `2026-05-09T00:00:00Z` | 缓存日期 |
| thumbnail | `(Data)` | 缩略图 |
| ruleId | `"preset-baidu"` | 关联规则 |
| ruleName | `"百度"` | 规则名称 |
| isExcluded | `false` | 未排除 |

**formattedSize**: `"180 KB"`

### Case 6.2: 未缓存的访问记录

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"hist-uncached-002"` | UUID |
| url | `"https://www.wikipedia.org/wiki/Swift_(programming_language)"` | Wikipedia |
| title | `"Swift (programming language) - Wikipedia"` | 页面标题 |
| favicon | `nil` | 无图标 |
| htmlPath | `nil` | 无本地 HTML |
| resourcePaths | `[]` | 无资源 |
| cachedSize | `0` | 无缓存 |
| isCached | `false` | 未缓存 |
| isPinned | `false` | 未置顶 |
| visitCount | `2` | 访问次数 |
| lastVisitDate | `2026-05-09T15:00:00Z` | 最后访问 |
| cacheDate | `nil` | 无缓存日期 |
| thumbnail | `nil` | 无缩略图 |
| ruleId | `nil` | 无规则 |

### Case 6.3: 被规则排除的历史记录

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"hist-excluded-003"` | UUID |
| url | `"https://passport.baidu.com/v2/login"` | 百度登录页 |
| title | `"百度登录"` | 页面标题 |
| isCached | `false` | 未缓存 |
| ruleId | `"preset-baidu"` | 百度规则 |
| ruleName | `"百度"` | 规则名称 |
| isExcluded | `true` | 被排除 |

### Case 6.4: 置顶的访问记录

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"hist-pinned-004"` | UUID |
| url | `"https://stackoverflow.com"` | Stack Overflow |
| title | `"Stack Overflow"` | 页面标题 |
| isCached | `true` | 已缓存 |
| isPinned | `true` | 置顶 |
| isFavorite | `true` | 已收藏 |
| visitCount | `500` | 高频访问 |
| cachedSize | `524288` | 512 KB |

---

## 7. 密钥（APIKey）

> 模型：`SuperApp/Sources/Models/APIKey.swift`
> 字段：`id`, `name`, `value`, `createdAt`, `expiresAt`, `description`, `isEnabled`, `boundGroupId`

### Case 7.1: 有效 API Key（Bark 推送）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"key-bark-001"` | UUID |
| name | `"Bark 推送密钥"` | 密钥名称 |
| value | `"sk-a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"` | 完整密钥 |
| createdAt | `2026-04-01T00:00:00Z` | 创建时间 |
| expiresAt | `nil` | 永久有效 |
| description | `"用于 Bark 推送通道的服务端密钥"` | 描述 |
| isEnabled | `true` | 启用 |
| boundGroupId | `"bark-push"` | 绑定组 |

**isPermanent**: `true`
**isExpired**: `false`
**maskedKey**: `"sk-a1b****5p6"`

### Case 7.2: 过期 API Key

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"key-expired-002"` | UUID |
| name | `"测试密钥（已过期）"` | 密钥名称 |
| value | `"sk-xyz987abc456def"` | 密钥值 |
| createdAt | `2026-01-01T00:00:00Z` | 创建 |
| expiresAt | `2026-03-01T00:00:00Z` | 已过期 |
| description | `"仅用于测试的临时密钥"` | 描述 |
| isEnabled | `true` | 启用但过期 |
| boundGroupId | `nil` | 未绑定 |

**isPermanent**: `false`
**isExpired**: `true`
**remainingTimeText**: `"已过期"`

### Case 7.3: 短有效期 API Key（即将过期）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"key-short-003"` | UUID |
| name | `"临时调试密钥"` | 密钥名称 |
| value | `"sk-temp123456789abcdef"` | 密钥值 |
| createdAt | `2026-05-09T00:00:00Z` | 创建 |
| expiresAt | `"2026-05-11T00:00:00Z"` | 明天过期 |
| description | `"调试用，48小时有效"` | 描述 |
| isEnabled | `true` | 启用 |
| boundGroupId | `"debug-group"` | 调试组 |

**remainingTimeText**: `"1天"`

### Case 7.4: 已禁用的 API Key

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"key-disabled-004"` | UUID |
| name | `"旧版推送密钥"` | 密钥名称 |
| value | `"sk-oldkey1234567890"` | 密钥值 |
| createdAt | `2025-12-01T00:00:00Z` | 创建 |
| expiresAt | `nil` | 永久 |
| description | `"已弃用的推送密钥"` | 描述 |
| isEnabled | `false` | 已禁用 |
| boundGroupId | `nil` | 未绑定 |

### Case 7.5: Webhook 签名密钥

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"key-webhook-005"` | UUID |
| name | `"Webhook 签名密钥"` | 密钥名称 |
| value | `"whsec_abcdef1234567890fedcba0987654321"` | Webhook Secret |
| createdAt | `2026-05-01T00:00:00Z` | 创建 |
| expiresAt | `nil` | 永久 |
| description | `"用于验证 GitHub Webhook 签名"` | 描述 |
| isEnabled | `true` | 启用 |

---

## 8. 口令（CommandToken）

> 服务端模型：`Server/Sources/WebBridgeServer/Models/CommandToken.swift`

### Case 8.1: URL Scheme 口令

**CommandGenerateRequest**：

```json
{
  "type": "urlScheme",
  "data": "myapp://open?url=https://weather.com",
  "format": "urlScheme",
  "ttlSeconds": 3600
}
```

**CommandToken**：

```json
{
  "id": "cmd-urlscheme-001",
  "payload": {
    "type": "urlScheme",
    "data": "myapp://open?url=https://weather.com",
    "format": "urlScheme"
  },
  "signature": "a1b2c3d4e5f6...",
  "createdAt": "2026-05-10T08:00:00Z",
  "expiresAt": "2026-05-10T09:00:00Z"
}
```

**CommandGenerateResponse**：

```json
{
  "id": "cmd-urlscheme-001",
  "token": "eyJ0eXBlIjoidXJsU2NoZW1lIiwiZGF0YSI6Im15YXBwOi8vb3Blbj91cmw9aHR0cHM6Ly93ZWF0aGVyLmNvbSJ9",
  "url": "webbridgekit://command?token=eyJ0eXBlIj...",
  "signature": "a1b2c3d4e5f6..."
}
```

### Case 8.2: Base64 编码口令

**CommandGenerateRequest**：

```json
{
  "type": "base64",
  "data": "SGVsbG8gV2ViQnJpZGdlS2l0",
  "format": "base64",
  "ttlSeconds": 86400
}
```

**CommandResolveResponse**：

```json
{
  "id": "cmd-base64-002",
  "payload": {
    "type": "base64",
    "data": "SGVsbG8gV2ViQnJpZGdlS2l0",
    "format": "base64"
  },
  "format": "base64",
  "output": "Hello WebBridgeKit"
}
```

### Case 8.3: 纯文本口令

**CommandGenerateRequest**：

```json
{
  "type": "plainText",
  "data": "打开天气应用",
  "format": "plainText",
  "ttlSeconds": 0
}
```

**CommandToken**（永不过期）：

```json
{
  "id": "cmd-plain-003",
  "payload": {
    "type": "plainText",
    "data": "打开天气应用",
    "format": "plainText"
  },
  "signature": "f1e2d3c4b5a6...",
  "createdAt": "2026-05-10T08:00:00Z",
  "expiresAt": null
}
```

### Case 8.4: JSON 口令

**CommandGenerateRequest**：

```json
{
  "type": "json",
  "data": "{\"action\":\"openApp\",\"appId\":\"shop-mall-app\",\"params\":{\"page\":\"product\",\"id\":\"12345\"}}",
  "format": "base64",
  "ttlSeconds": 3600
}
```

**CommandResolveResponse**：

```json
{
  "id": "cmd-json-004",
  "payload": {
    "type": "json",
    "data": "{\"action\":\"openApp\",\"appId\":\"shop-mall-app\",\"params\":{\"page\":\"product\",\"id\":\"12345\"}}",
    "format": "base64"
  },
  "format": "base64",
  "output": "{\"action\":\"openApp\",\"appId\":\"shop-mall-app\",\"params\":{\"page\":\"product\",\"id\":\"12345\"}}"
}
```

---

## 9. 缓存规则（CacheRule）

> 模型：`Sources/Models/CacheRule.swift`
> 字段：`id`, `name`, `type`, `pattern`, `resourceType`, `isEnabled`, `createdAt`, `priority`

### Case 9.1: 域名匹配规则

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"rule-domain-001"` | UUID |
| name | `"缓存所有 CDN 资源"` | 规则名称 |
| type | `.domain` | 域名匹配 |
| pattern | `"*.cdn.example.com"` | 通配符子域名 |
| resourceType | `.staticResource` | 静态资源 |
| isEnabled | `true` | 启用 |
| priority | `10` | 优先级 |

**matches("https://static.cdn.example.com/app.js")**: `true`
**matches("https://cdn.example.com/app.css")**: `true`
**matches("https://other.example.com/app.js")**: `false`

### Case 9.2: Glob 模式规则

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"rule-glob-002"` | UUID |
| name | `"缓存所有 JS/CSS"` | 规则名称 |
| type | `.glob` | Glob 匹配 |
| pattern | `"https://*.example.com/**/*.{js,css}"` | JS/CSS 文件 |
| resourceType | `.staticResource` | 静态资源 |
| isEnabled | `true` | 启用 |
| priority | `20` | 优先级 |

### Case 9.3: 正则表达式规则

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"rule-regex-003"` | UUID |
| name | `"API 数据缓存"` | 规则名称 |
| type | `.regex` | 正则匹配 |
| pattern | `"https://api\\.example\\.com/v[0-9]+/data.*"` | API 版本路径 |
| resourceType | `.dynamicResource` | 动态资源 |
| isEnabled | `true` | 启用 |
| priority | `5` | 高优先级 |

**matches("https://api.example.com/v1/data/cities")**: `true`
**matches("https://api.example.com/v2/data/weather?city=bj")**: `true`

### Case 9.4: 精确 URL 匹配规则

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"rule-exact-004"` | UUID |
| name | `"首页精确缓存"` | 规则名称 |
| type | `.exact` | 精确匹配 |
| pattern | `"https://weather.com/index.html"` | 精确 URL |
| resourceType | `.staticResource` | 静态资源 |
| isEnabled | `true` | 启用 |

### Case 9.5: 已禁用规则

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"rule-disabled-005"` | UUID |
| name | `"旧版缓存规则"` | 规则名称 |
| type | `.domain` | 域名匹配 |
| pattern | `"old.example.com"` | 旧域名 |
| resourceType | `.staticResource` | 静态资源 |
| isEnabled | `false` | 已禁用 |

**matches(任何 URL)**: `false`（规则已禁用）

---

## 10. 页面缓存规则（PageCacheRule）

> 模型：`Sources/Models/PageCacheRule.swift`
> 字段：`id`, `name`, `includePatterns`, `excludePatterns`, `isEnabled`, `createdAt`, `lastCachedAt`

### Case 10.1: 百度规则（预设）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"preset-baidu"` | 预设 ID |
| name | `"百度"` | 规则名称 |
| includePatterns | `["https://*.baidu.com/**"]` | 百度全站 |
| excludePatterns | `["https://*.baidu.com/login/**"]` | 排除登录页 |
| isEnabled | `true` | 启用 |

**matches("https://www.baidu.com/s?wd=swift")**: `true`
**matches("https://passport.baidu.com/v2/login")**: `false`（被排除）

### Case 10.2: VIP 视频规则（预设）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"preset-vip-video"` | 预设 ID |
| name | `"VIP 视频"` | 规则名称 |
| includePatterns | `["https://*.vip.com/video/**", "https://*.vip.com/movie/**"]` | 视频页 |
| excludePatterns | `["https://*.vip.com/login*", "https://*.vip.com/register*"]` | 排除登录/注册 |
| isEnabled | `true` | 启用 |

### Case 10.3: GitHub 规则（预设，无排除）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"preset-github"` | 预设 ID |
| name | `"GitHub"` | 规则名称 |
| includePatterns | `["https://github.com/**"]` | 全站 |
| excludePatterns | `[]` | 无排除 |
| isEnabled | `true` | 启用 |

### Case 10.4: 多模式自定义规则

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"custom-multi-004"` | UUID |
| name | `"技术博客"` | 规则名称 |
| includePatterns | `["https://blog.example.com/posts/**", "https://blog.example.com/tutorials/**", "https://blog.example.com/guides/**"]` | 3种路径 |
| excludePatterns | `["https://blog.example.com/posts/draft/**"]` | 排除草稿 |
| isEnabled | `true` | 启用 |

### Case 10.5: RuleWithPages（UI 展示用）

```swift
RuleWithPages(
  rule: PageCacheRule.baiduRule,
  cachedPages: [
    CachedPageInfo(
      id: "page-001",
      url: "https://www.baidu.com/s?wd=swift",
      title: "swift_百度搜索",
      ruleId: "preset-baidu",
      ruleName: "百度",
      resourceCount: 12,
      totalSize: 245760,
      cachedAt: "2026-05-10T06:00:00Z",
      isOfflineAvailable: true,
      isExcluded: false
    ),
    CachedPageInfo(
      id: "page-002",
      url: "https://baike.baidu.com/item/Swift",
      title: "Swift（苹果编程语言）_百度百科",
      ruleId: "preset-baidu",
      ruleName: "百度",
      resourceCount: 8,
      totalSize: 184320,
      cachedAt: "2026-05-09T12:00:00Z",
      isOfflineAvailable: true,
      isExcluded: false
    )
  ],
  isExpanded: true
)
```

**formattedTotalSize**: `"420 KB"`
**totalPagesCount**: `2`

---

## 11. 缓存统计（WebCacheStatistics）

> 模型：`Sources/Models/WebCacheStatistics.swift`
> 字段：`domain`, `totalSize`, `fileCount`, `lastUpdate`

### Case 11.1: 各域名缓存统计

| domain | totalSize | fileCount | lastUpdate | formattedSize |
|--------|-----------|-----------|------------|---------------|
| `cdn.weather.com` | `184320` | `15` | `2026-05-10T06:00:00Z` | `"180 KB"` |
| `m.shop.example.com` | `2097152` | `42` | `2026-05-10T10:00:00Z` | `"2.0 MB"` |
| `play.casual.games` | `1228800` | `8` | `2026-05-10T08:30:00Z` | `"1.2 MB"` |
| `docs.swift.org` | `524288` | `20` | `2026-05-08T00:00:00Z` | `"512 KB"` |
| `github.com` | `3145728` | `95` | `2026-05-10T09:00:00Z` | `"3.0 MB"` |

### Case 11.2: 空域名统计（边界）

| domain | totalSize | fileCount | lastUpdate |
|--------|-----------|-----------|------------|
| `empty.example.com` | `0` | `0` | `2026-05-10T00:00:00Z` |

---

## 12. 缓存统计信息（CacheStats）

> 模型：`Sources/Models/CacheModels.swift` — `CacheStats`

### Case 12.1: 高命中率统计

| 字段 | 值 | 说明 |
|------|-----|------|
| totalRequests | `1000` | 总请求数 |
| cacheHits | `850` | 缓存命中 |
| cacheMisses | `150` | 缓存未命中 |
| totalCacheSize | `10485760` | 10 MB |

**hitRate**: `0.85`
**formattedHitRate**: `"85.0%"`
**formattedCacheSize**: `"10.0 MB"`

### Case 12.2: 低命中率统计（冷启动）

| 字段 | 值 | 说明 |
|------|-----|------|
| totalRequests | `50` | 总请求数 |
| cacheHits | `5` | 缓存命中 |
| cacheMisses | `45` | 缓存未命中 |
| totalCacheSize | `524288` | 512 KB |

**hitRate**: `0.10`
**formattedHitRate**: `"10.0%"`

### Case 12.3: 零请求统计（边界）

| 字段 | 值 | 说明 |
|------|-----|------|
| totalRequests | `0` | 无请求 |
| cacheHits | `0` | 无命中 |
| cacheMisses | `0` | 无未命中 |
| totalCacheSize | `0` | 无缓存 |

**hitRate**: `0.0`
**formattedHitRate**: `"0.0%"`

---

## 13. 消息路由（MessageRouter/RouteTarget）

> 路由：`Sources/Message/Router/MessageRouter.swift`
> 目标：`Sources/Message/MessageEngine.swift` — `RouteTarget`

### Case 13.1: URL 路由

```json
{
  "type": "url",
  "destination": "https://weather.com/beijing",
  "mode": null,
  "params": null
}
```

**触发条件**: `MessagePayload(targetURL: "https://weather.com/beijing")`

### Case 13.2: 小程序路由

```json
{
  "type": "appId",
  "destination": "shop-mall-app",
  "mode": "modal",
  "params": {
    "page": "product",
    "id": "12345"
  }
}
```

**触发条件**: `MessagePayload(targetAppId: "shop-mall-app", targetMode: "modal", userInfo: ["page": "product", "id": "12345"])`

### Case 13.3: Deep Link 路由

```json
{
  "type": "deeplink",
  "destination": "myapp://article/swift-concurrency",
  "mode": null,
  "params": null
}
```

**触发条件**: `MessagePayload(targetURL: "myapp://article/swift-concurrency")`（非 http/https scheme）

### Case 13.4: 无路由

```json
{
  "type": "none",
  "destination": "",
  "mode": null,
  "params": null
}
```

**触发条件**: `MessagePayload()`（无 targetURL 和 targetAppId）

---

## 14. 设备注册（DeviceRegistration）

> 模型：`Server/Sources/WebBridgeServer/Models/DeviceRegistration.swift`

### Case 14.1: iOS 设备注册

```json
{
  "deviceToken": "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456",
  "key": "user-device-001",
  "platform": "iOS",
  "appVersion": "2.5.0",
  "createdAt": "2026-05-10T08:00:00Z"
}
```

### Case 14.2: Android 设备注册

```json
{
  "deviceToken": "fcm://c1d2e3f4g5h6i7j8k9l0m1n2o3p4q5r6",
  "key": "user-device-002",
  "platform": "Android",
  "appVersion": "2.5.0",
  "createdAt": "2026-05-10T08:01:00Z"
}
```

### Case 14.3: 最小注册信息

```json
{
  "deviceToken": "minimal-token-123",
  "key": "minimal-key",
  "platform": null,
  "appVersion": null,
  "createdAt": "2026-05-10T08:00:00Z"
}
```

---

## 15. Manifest 验证（ManifestValidationResult）

> 模型：`Sources/Models/ManifestError.swift`

### Case 15.1: 有效 Manifest

```swift
ManifestValidationResult.valid()
// isValid: true, errors: [], warnings: []
```

### Case 15.2: 有效但有警告

```swift
ManifestValidationResult.validWithWarnings(["No version specified, using default version"])
// isValid: true, errors: [], warnings: ["No version specified, using default version"]
```

### Case 15.3: 无效 Manifest（多错误）

```swift
ManifestValidationResult.invalid([
  .missingRequiredField("resources"),
  .invalidFormat("Invalid appid format: ../../hack"),
  .invalidResourcePath("Path traversal detected in: ../../../etc/passwd")
], warnings: ["Name field is empty"])
// isValid: false, errors: [...], warnings: [...]
```

### Case 15.4: ManifestVersion 支持

```swift
ManifestVersion.isSupported("1.0.0")  // true
ManifestVersion.isSupported("1.5.0")  // true
ManifestVersion.isSupported("2.0.0")  // true
ManifestVersion.isSupported("0.9.0")  // false (低于最小支持版本)
ManifestVersion.isSupported("2.1.0")  // false (高于最大支持版本)
ManifestVersion.isSupported("3.0.0")  // false
```

---

## 16. 错误数据（WebBridgeError/ManifestError）

### Case 16.1: WebBridgeError 错误场景

| 错误类型 | 示例值 | 说明 |
|---------|--------|------|
| `.invalidInput` | `"URL cannot be empty"` | 空输入 |
| `.networkRequestFailed` | `"Connection refused"` | 网络请求失败 |
| `.cacheLoadFailed` | `"Disk read error"` | 缓存加载失败 |
| `.cacheSaveFailed` | `(NSError domain: "disk")` | 缓存保存失败 |
| `.databaseOperationFailed` | `(Realm.Error)` | 数据库操作失败 |
| `.timeout` | `"Manifest download"` | 操作超时 |
| `.networkUnavailable` | `"No internet connection"` | 无网络 |
| `.browserOpenFailed` | `"Invalid URL scheme"` | 浏览器打开失败 |

### Case 16.2: MessageError 错误场景

| 错误类型 | 示例值 | 说明 |
|---------|--------|------|
| `.channelNotActive` | `channelId: "bark"` | 通道未激活 |
| `.channelNotConfigured` | `channelId: "webhook"` | 通道未配置 |
| `.invalidPayload` | `reason: "Missing title"` | 无效载荷 |
| `.sendFailed` | `reason: "Timeout"` | 发送失败 |
| `.unauthorized` | - | 未授权 |
| `.rateLimited` | `retryAfter: 60` | 限流 |
| `.serverError` | `statusCode: 500, message: "Internal Error"` | 服务器错误 |

### Case 16.3: ManifestError 错误场景

| 错误类型 | 示例值 | 说明 |
|---------|--------|------|
| `.invalidFormat` | `"Expected JSON object"` | 格式错误 |
| `.missingRequiredField` | `"resources"` | 缺少必填字段 |
| `.unsupportedVersion` | `"3.0.0"` | 不支持的版本 |
| `.invalidResourcePath` | `"Path traversal detected in: ../../etc"` | 路径遍历 |
| `.invalidResourceType` | `"executable"` | 无效资源类型 |
| `.corruptedData` | - | 数据损坏 |

---

## 附录：消息处理器管线测试数据

### Processor Pipeline 顺序

| 优先级 | 处理器 | identifier | 说明 |
|--------|--------|-----------|------|
| 100 | MarkdownProcessor | `"markdown"` | Markdown 转纯文本 |
| 200 | LevelProcessor | `"level"` | 设置中断级别 |
| 300 | BadgeProcessor | `"badge"` | 管理 badge 数字 |
| 400 | AutoCopyProcessor | `"autoCopy"` | 自动复制到剪贴板 |
| 500 | ArchiveProcessor | `"archive"` | 消息归档存储 |
| 600 | MuteProcessor | `"mute"` | 群组静音检查 |

### MessagePriority 值

| 优先级 | intValue | 说明 |
|--------|----------|------|
| `.low` | 0 | 低优先级 |
| `.normal` | 5 | 普通 |
| `.high` | 8 | 高优先级 |
| `.critical` | 10 | 紧急 |

### MessageInterruptionLevel

| 级别 | displayName | Bark level 映射 |
|------|-------------|----------------|
| `.passive` | 静默 | `"passive"` |
| `.active` | 默认 | `nil`（默认） |
| `.timeSensitive` | 时效性 | `"timeSensitive"` |
| `.critical` | 紧急 | `"timeSensitive"` |

### MessageBodyType

| 类型 | 说明 |
|------|------|
| `.plainText` | 纯文本 |
| `.markdown` | Markdown 格式 |

---

## 附录：消息统计（MessageStatistics）测试数据

### Case A.1: 多通道统计

```json
{
  "totalReceived": 150,
  "totalSent": 80,
  "totalFailed": 5,
  "totalQueued": 3,
  "byChannel": {
    "bark": {
      "received": 50,
      "sent": 45,
      "failed": 2,
      "queued": 1
    },
    "apns": {
      "received": 60,
      "sent": 30,
      "failed": 3,
      "queued": 2
    },
    "bridge": {
      "received": 40,
      "sent": 5,
      "failed": 0,
      "queued": 0
    }
  },
  "lastUpdated": "2026-05-10T10:00:00Z"
}
```

### Case A.2: 零统计（初始状态）

```json
{
  "totalReceived": 0,
  "totalSent": 0,
  "totalFailed": 0,
  "totalQueued": 0,
  "byChannel": {},
  "lastUpdated": "2026-05-10T00:00:00Z"
}
```

---

## 附录：CachedResource 测试数据

### Case B.1: 图片缓存资源

| 字段 | 值 | 说明 |
|------|-----|------|
| url | `https://cdn.weather.com/icon.png` | CDN 图片 |
| data | `(Data, 4096 bytes)` | PNG 数据 |
| mimeType | `image/png` | MIME 类型 |
| cachedAt | `2026-05-10T06:00:00Z` | 缓存时间 |

**age**: 取决于当前时间
**isExpired(maxAge: 86400)**: 取决于缓存时间
**formattedSize**: `"4 KB"`

### Case B.2: CacheRequestInfo 测试数据

| 字段 | 值 | 说明 |
|------|-----|------|
| url | `https://cdn.weather.com/app.js` | JS 资源 |
| isMainFrame | `false` | 子资源 |
| httpMethod | `"GET"` | GET 请求 |
| hasCache | `true` | 有缓存 |
| cacheAge | `3600.0` | 缓存1小时 |

---

## 附录：AppID 解析测试数据

### Case C.1: 从 Manifest 解析

| 输入 appid | 输入 URL | 结果 | 说明 |
|------------|---------|------|------|
| `"com.weather.daily"` | `https://weather.com` | `"com_weather_daily"` | 优先使用 appid |
| `nil` | `https://weather.com/beijing` | `"weather_com_beijing"` | URL 域名+路径 |
| `nil` | `https://localhost:8080/test` | `"localhost_8080_test"` | 本地地址 |
| `"../hack"` | `https://safe.com` | `"__hack"` | 安全清理 |
| `""` | `https://example.com` | `"example_com"` | 空 appid 回退 |

### Case C.2: 从 HTML 提取 Title

| HTML 输入 | 结果 |
|-----------|------|
| `<html><title>天气预报</title></html>` | `"天气预报"` |
| `<html><TITLE>Swift 文档</TITLE></html>` | `"Swift 文档"` |
| `<html><title>  Hello &amp; World  </title></html>` | `"Hello & World"` |
| `<html><no title></html>` | `nil` |
| `<html><title></title></html>` | `nil` |

---

## 附录：服务端 Manifest 测试数据

> 服务端模型：`Server/Sources/WebBridgeServer/Models/Manifest.swift`

### Case D.1: 完整服务端 Manifest

```json
{
  "appId": "com.weather.daily",
  "version": "1.2.0",
  "buildNumber": 42,
  "resources": [
    {
      "path": "index.html",
      "url": "https://cdn.weather.com/app/index.html",
      "hash": "sha256-abc123def456...",
      "size": 24576
    },
    {
      "path": "scripts/weather.js",
      "url": "https://cdn.weather.com/app/scripts/weather.js",
      "hash": "sha256-789ghi012jkl...",
      "size": 102400
    }
  ],
  "integrity": {
    "algorithm": "sha256",
    "manifestHash": "sha256-fullmanifesthash..."
  },
  "createdAt": "2026-05-01T00:00:00Z",
  "updatedAt": "2026-05-10T06:00:00Z"
}
```

### Case D.2: Manifest 列表响应

```json
{
  "manifests": [
    {
      "appId": "com.weather.daily",
      "version": "1.2.0",
      "buildNumber": 42,
      "updatedAt": "2026-05-10T06:00:00Z"
    },
    {
      "appId": "md-notes-editor",
      "version": "2.0.1",
      "buildNumber": 15,
      "updatedAt": "2026-05-09T12:00:00Z"
    },
    {
      "appId": "shop-mall-app",
      "version": "3.5.2",
      "buildNumber": 88,
      "updatedAt": "2026-05-10T00:00:00Z"
    }
  ]
}
```

### Case D.3: Manifest 版本响应

```json
{
  "appId": "com.weather.daily",
  "version": "1.2.0",
  "buildNumber": 42
}
```
