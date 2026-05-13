# WebBridgeKit 系统交互文档

> 本文档描述 WebBridgeKit 三大核心体系的完整交互链路、数据流和 API 调用关系。

---

## 目录

1. [Bridge 引擎 — JS↔Native 桥接](#1-bridge-引擎)
2. [Cache 缓存 — 11 子系统离线引擎](#2-cache-缓存引擎)
3. [Message 消息 — 推送/Bark/Webhook 路由](#3-message-消息引擎)
4. [CommandParser 口令 — HMAC 签名命令体系](#4-commandparser-口令体系)
5. [WebSocket — JSON-RPC 2.0 双通道](#5-websocket-引擎)
6. [AI 调试接口 — MCP 协议](#6-ai-调试接口)
7. [完整调用关系图](#7-调用关系图)

---

## 1. Bridge 引擎

### 1.1 架构概览

```
┌─────────────────────────────────────────────────────┐
│                    WebView (WKWebView)               │
│  ┌───────────────────────────────────────────────┐  │
│  │              WebBridge.js (注入脚本)           │  │
│  │  window.WebBridge.call(action, params, cb)    │  │
│  └───────────────────┬───────────────────────────┘  │
│                      │ WKScriptMessage               │
├──────────────────────┼───────────────────────────────┤
│                  Native 层                           │
│  ┌───────────────────▼───────────────────────────┐  │
│  │          WebJavaScriptBridge (核心)             │  │
│  │  nativeHandlers: [String: WebNativeAPI]        │  │
│  │  handlerFactories: 懒加载工厂                   │  │
│  └──────┬──────┬──────┬──────┬──────┬──────┬────┘  │
│         │      │      │      │      │      │        │
│  ┌──────▼──┐┌──▼───┐┌──▼───┐┌──▼───┐┌──▼───┐┌──▼───┐
│  │ Device  ││Inter- ││Cache ││Navi- ││Media ││Net-  │
│  │ (9个)   ││action ││Debug ││gation││(7个) ││work  │
│  │         ││(5个)  ││(6个) ││(5个) ││      ││(3个) │
│  └─────────┘└───────┘└──────┘└──────┘└──────┘└─────┘
└─────────────────────────────────────────────────────┘
```

### 1.2 Handler 分类 (35+)

| 分组 | Handler | JS Action | 功能 |
|------|---------|-----------|------|
| **Device** | WebSystemInfoHandler | `system.getInfo` | 获取设备/OS/电池信息 |
| | WebScreenHandler | `screen.getInfo` | 屏幕尺寸/亮度/方向 |
| | WebHapticHandler | `haptic.impact/notification/selection` | 触觉反馈 |
| | WebVibrateHandler | `vibrate` | 振动 |
| | WebLayoutHandler | `layout.*` | SafeArea/状态栏 |
| | WebBluetoothHandler | `bluetooth.*` | 蓝牙扫描/连接 |
| | WebLocationHandler | `location.*` | 定位 |
| | WebSensorsHandler | `sensors.*` | 陀螺仪/加速度计 |
| | WebSystemExtraHandler | `system.*` | 打开设置/拨号等 |
| **Interaction** | WebClipboardHandler | `clipboard.read/write` | 剪贴板读写 |
| | WebGestureHandler | `gesture.*` | 手势识别 |
| | WebGestureInterceptor | 拦截手势 | 自定义手势拦截 |
| | WebScanHandler | `scan.start/stop` | 二维码扫描 |
| | WebShareHandler | `share.*` | 系统分享 |
| **Navigation** | WebOpenPageHandler | `openPage` | 打开新页面 |
| | WebClosePageHandler | `closePage` | 关闭页面 |
| | WebGoBackHandler | `goBack` | 返回 |
| | WebGetHistoryHandler | `getHistory` | 获取历史记录 |
| | WebSetModalHandler | `setModal` | 设置模态 |
| **CacheDebug** | WebCacheDebugHandler | `cache.*` | 缓存调试 (CRUD) |
| | WebPageCacheHandler | `pageCache.*` | 页面缓存操作 |
| | PageCacheOperationMethods | 扩展方法 | 批量操作 |
| | PageCacheRuleMethods | 缓存规则 | 规则管理 |
| | CompressedCacheMethods | 压缩缓存 | 压缩/解压 |
| **Media** | WebCameraHandler | `camera.*` | 相机拍照/录像 |
| | WebPhotoHandler | `photo.*` | 相册选择 |
| | WebVideoHandler | `video.*` | 视频处理+Vision |
| | WebAudioLevelHandler | `audio.*` | 音频电平 |
| | WebMediaHandler | `media.*` | 媒体通用 |
| | WebSpeechHandler | `speech.*` | 语音识别 |
| | WebSpeechSynthesisHandler | `speechSynthesis.*` | 语音合成 |
| **Network** | WebNetworkHandler | `network.*` | 网络状态/请求 |
| | WebPayloadHandler | `payload.*` | 数据载荷 |
| | WebResourceURLSchemeHandler | URL拦截 | 资源请求拦截 |
| **App** | WebContactsHandler | `contacts.*` | 通讯录 |
| | WebFileHandler | `file.*` | 文件操作 |
| | WebMirroringHandler | `mirroring.*` | 屏幕镜像 |
| | WebOpenSettingsHandler | `openSettings` | 打开设置 |
| **Permission** | WebPermissionHandler | `permission.*` | 权限请求 |
| | WebPermissionManager | 内部管理 | 权限状态管理 |
| | WebPermissionStatusHandler | `permission.status` | 权限查询 |
| **Manifest** | LazyManifestLoader | 懒加载 | 按需加载 Manifest |
| | PersistentManifestLoader | 持久化 | Manifest 离线加载 |
| | ManifestDownloadService | 下载 | Manifest 下载 |
| | ManifestProgressUI | UI | 下载进度展示 |

### 1.3 JS→Native 调用流程

```
JS: window.WebBridge.call('haptic.impact', { style: 'medium' })

↓ WKScriptMessageHandler.userContentController(_:didReceive:)

WebJavaScriptBridge:
  1. 解析 message.body → { action, params, callbackId }
  2. handlersLock.lock()
  3. 查找 nativeHandlers["haptic"] 或 handlerFactories["haptic"]
  4. 若是工厂，创建实例并缓存
  5. handler.handle(name: "impact", params: {style:"medium"})
  6. 通过 evaluateJavascript 回调 JS callback
```

### 1.4 元数据自动发现

```swift
// Sources/Bridge/Meta/HandlerMeta.swift
// 每个 Handler 自动注册元数据（名称、方法列表、参数 schema）
// AI 调试接口 / AI Tools 可查询所有可用 Handler
```

---

## 2. Cache 缓存引擎

### 2.1 架构概览

```
┌──────────────────────────────────────────────────────────────────┐
│                       Cache 缓存引擎                             │
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐ │
│  │  WebCacheManager │  │ ManifestCache    │  │ ResourceCache │ │
│  │  (系统缓存)       │  │ Manager (清单)   │  │ Manager (资源) │ │
│  └────────┬─────────┘  └────────┬─────────┘  └──────┬────────┘ │
│           │                     │                    │          │
│  ┌────────▼─────────────────────▼────────────────────▼────────┐ │
│  │              CacheManager (聚合器)                          │ │
│  │  统一缓存 CRUD 接口                                        │ │
│  └──────┬──────────────────────────────────────────────────────┘ │
│         │                                                        │
│  ┌──────▼──────────────────────────────────────────────────────┐ │
│  │              三级存储                                        │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐                   │ │
│  │  │ Memory   │→│ Disk     │→│ Hybrid   │                   │ │
│  │  │ Cache    │ │ Cache    │ │ Cache    │                   │ │
│  │  └──────────┘ └──────────┘ └──────────┘                   │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              辅助子系统                                      ││
│  │  WebPageHistoryManager  │ CacheRuleManager  │ GlobPattern  ││
│  │  CacheStatsAggregator   │ URLRuleMatcher    │ PresetURL    ││
│  │  WebCompressedCacheStore│ PageCacheRule     │ HTMLParser   ││
│  │  WebPageThumbnail       │ SystemURLCache    │ ManifestStore││
│  │  WebPageOfflineCache    │ DashboardModels   │ ManifestDL   ││
│  └─────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────┘
```

### 2.2 11 个子系统详解

| # | 子系统 | 文件 | 职责 | 用户可感知的交互 |
|---|--------|------|------|------------------|
| 1 | **WebCacheManager** | Cache/WebCacheManager.swift | 系统级网站缓存（WKWebsiteDataStore） | 设置页清理缓存 → 确认弹窗 → 清除 |
| 2 | **CacheManager** | Cache/CacheManager.swift | 统一缓存 CRUD 聚合器 | 所有缓存操作的统一入口 |
| 3 | **ManifestCacheManager** | Cache/ManifestCacheManager.swift | 应用清单缓存（Manifest 下载/存储） | 发现页显示"离线"/"需更新"状态 |
| 4 | **ManifestDownloader** | Cache/ManifestDownloader.swift | Manifest 文件下载 | 首次加载 WebApp 时的进度条 |
| 5 | **ManifestStore** | Cache/ManifestStore.swift | Manifest 持久化存储 | 离线时仍能显示 App 结构 |
| 6 | **WebResourceCacheManager** | Cache/WebResourceCacheManager.swift | Web 资源（CSS/JS/图片）缓存 | 离线时 WebApp 仍可显示 |
| 7 | **ResourceDownloader** | Cache/ResourceDownloader.swift | 资源下载器 | 后台预缓存 |
| 8 | **WebPageHistoryManager** | Cache/WebPageHistoryManager.swift | 浏览历史（Realm） | 首页 URLGrid 显示的卡片列表 |
| 9 | **CacheRuleManager** | Cache/CacheRuleManager.swift | 缓存规则（URL 匹配/过期策略） | 缓存仪表盘的规则管理 |
| 10 | **WebPageOfflineCacheManager** | Cache/WebPageOfflineCacheManager.swift | 离线页面缓存 | 断网时仍能浏览已缓存页面 |
| 11 | **WebCompressedCacheStore** | Cache/WebCompressedCacheStore.swift | 压缩缓存存储 | 减少磁盘占用 |
| 12 | **CacheStatsAggregator** | Cache/CacheStatsAggregator.swift | 统计聚合 | 缓存仪表盘的统计图表 |
| 13 | **PresetURLCatalog** | Cache/PresetURLCatalog.swift | 预设 URL 目录 | 发现页的推荐应用列表 |

### 2.3 缓存交互链路

```
用户打开 WebApp
    │
    ├─ ① WebView 加载 URL
    │     └─ WebPageHistoryManager 记录访问历史 → Realm
    │
    ├─ ② ManifestCacheManager 检查清单
    │     ├─ 有缓存 → 使用离线清单
    │     └─ 无缓存 → ManifestDownloader 下载
    │
    ├─ ③ 资源缓存
    │     ├─ CacheURLSchemeHandler 拦截请求
    │     ├─ CacheRuleManager 判断是否缓存
    │     ├─ 命中 → 直接返回本地资源
    │     └─ 未命中 → 网络加载 + ResourceDownloader 后台缓存
    │
    └─ ④ 离线状态
          ├─ WebPageOfflineCacheManager 提供离线页面
          └─ 用户看到缓存内容（可能标记"需更新"）
```

### 2.4 用户入口与缓存的关系

| 用户操作 | 调用的缓存系统 | 影响范围 |
|----------|---------------|---------|
| 首页清理缓存（垃圾桶按钮） | WebCacheManager.clearAll() | 清除所有 WKWebsiteDataStore 数据 |
| 发现页下拉刷新 | ManifestCacheManager + WebResourceCacheManager | 检查更新 |
| URLGrid 卡片显示"离线"标记 | WebPageHistoryManager (isCached) | 只读状态 |
| 设置→缓存管理→缓存仪表盘 | CacheStatsAggregator 聚合 11 子系统 | 统计展示 |
| 设置→缓存管理→收藏 | URLFavoriteManager | 收藏列表 |
| WebView 内 WebApp 请求资源 | CacheURLSchemeHandler → CacheRuleManager | 请求拦截 |

---

## 3. Message 消息引擎

### 3.1 架构概览

```
┌─────────────────────────────────────────────────────────┐
│                  Message 消息引擎                        │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │            MessageEngine (Actor, 单例)            │   │
│  │  channels: [BarkChannel, WebhookChannel]         │   │
│  │  store: InMemoryMessageStore                     │   │
│  │  router: MessageRouter                           │   │
│  │  pipeline: MessageProcessorPipeline              │   │
│  │  statistics: MessageStatistics                   │   │
│  └──────────────────────────────────────────────────┘   │
│       │              │               │                   │
│  ┌────▼────┐   ┌─────▼─────┐   ┌────▼────┐            │
│  │ Channels│   │  Processors │   │  Stores │            │
│  │ ┌─────┐ │   │ ┌─────────┐│   │┌───────┐│            │
│  │ │Bark │ │   │ │Push     ││   ││User   ││            │
│  │ │     │ │   │ │Payload  ││   ││Default││            │
│  │ └─────┘ │   │ │Parser   ││   ││sMsg   ││            │
│  │ ┌─────┐ │   │ └─────────┘│   ││Store  ││            │
│  │ │Web- │ │   │ ┌─────────┐│   │└───────┘│            │
│  │ │hook │ │   │ │Builtin  ││   └─────────┘            │
│  │ │     │ │   │ │Process- ││                            │
│  │ └─────┘ │   │ │ors      ││                            │
│  └─────────┘   │ └─────────┘│                            │
│                 └───────────┘                            │
│  ┌──────────────────────────────────────────────────┐   │
│  │              MessageRouter                        │   │
│  │  ① customResolver (自定义路由)                    │   │
│  │  ② appId 路由 → 打开小程序                        │   │
│  │  ③ URL 路由 → 打开网页                            │   │
│  │  ④ deeplink 路由 → 打开系统应用                    │   │
│  │  ⑤ 默认 → 展示通知                               │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### 3.2 两个 Channel

| Channel | 协议 | 方向 | 配置 |
|---------|------|------|------|
| **BarkChannel** | HTTPS GET | 出站（App→Server→APNs→设备） | serverURL + key（默认 api.day.app） |
| **WebhookChannel** | HTTP POST | 入站（外部→App） | port:8765 + /webhook |

### 3.3 消息处理流程

```
外部推送到达（Bark）
    │
    ├─ BarkChannel.send(payload)
    │     └─ HTTPS GET https://api.day.app/{key}/{title}/{body}
    │
    └─ 消息到达设备（APNs 回调）
          │
          ├─ PushPayloadParser 解析
          │     ├─ 提取 title/body/url/sound/group
          │     └─ 解析 targetAppId/targetURL/targetMode
          │
          ├─ MessageProcessorPipeline 处理
          │     └─ 过滤/转换/增强
          │
          ├─ InMemoryMessageStore 存储
          │
          ├─ MessageRouter 路由
          │     ├─ 有 appId → 打开小程序
          │     ├─ 有 URL → WebView 打开
          │     ├─ 有 deeplink → 系统处理
          │     └─ 默认 → 显示通知
          │
          └─ onMessageReceived 回调 → Inbox 刷新
```

### 3.4 用户入口

| 用户操作 | 调用的消息系统 | 说明 |
|----------|---------------|------|
| 首页 PushToken 卡片"注册" | PushNotificationManager.registerForPushNotifications() | 注册 APNs |
| 首页 PushToken 卡片"复制" | 复制 serverURL + deviceToken | 供外部推送用 |
| 收信箱 FAB 铃铛 | 发送测试推送（通过 Bark Channel） | 自测 |
| 收信箱消息列表 | InMemoryMessageStore 读取 | 展示历史消息 |
| 收信箱筛选"未读" | 过滤 store 中的未读消息 | 筛选 |
| 设置→通知设置 | 打开系统设置 | iOS 系统设置 |

---

## 4. CommandParser 口令体系

### 4.1 架构概览

```
┌──────────────────────────────────────────────────────┐
│              CommandParser 口令体系                    │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │         CommandParser (Actor, 单例)             │  │
│  │  decoderRegistry: CommandDecoderRegistry       │  │
│  │  signatureVerifier: CommandSignatureVerifier   │  │
│  │  configuration: CommandParserConfiguration     │  │
│  │  processedNonces: Set<String> (防重放)         │  │
│  └──────────────┬─────────────────────────────────┘  │
│                 │                                     │
│  ┌──────────────▼─────────────────────────────────┐  │
│  │           CommandDecoderRegistry                │  │
│  │  注册多种解码器:                                 │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────┐   │  │
│  │  │ Base64   │ │ JSON     │ │ HMAC-Signed  │   │  │
│  │  │ Decoder  │ │ Decoder  │ │ Decoder      │   │  │
│  │  └──────────┘ └──────────┘ └──────────────┘   │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │           CommandRouter                         │  │
│  │  .appId → 打开小程序                            │  │
│  │  .url   → 打开网页                              │  │
│  │  .deeplink → 系统处理                           │  │
│  │  .none  → 提示无有效口令                         │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │           ClipboardMonitor                      │  │
│  │  剪贴板监听 → 自动检测口令                       │  │
│  └────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
```

### 4.2 口令格式

```
格式 1: HMAC 签名口令（最安全）
  HMAC-SHA256(secret, payload) + Base64(JSON({url, appId, nonce, timestamp}))

格式 2: Base64 编码口令
  Base64(JSON({url, appId, ...}))

格式 3: 纯 URL 口令
  https://example.com/path
```

### 4.3 口令交互链路

```
用户复制口令到剪贴板
    │
    ├─ ClipboardMonitor 检测到剪贴板变化
    │     └─ 比对是否有新内容
    │
    ├─ CommandHandler (SuperApp) 拦截
    │     └─ checkClipboardOnForeground()
    │
    ├─ CommandParser.parse(clipboardContent)
    │     ├─ 遍历 decoderRegistry 尝试解码
    │     ├─ 成功 → CommandPayload
    │     └─ 失败 → CommandError
    │
    ├─ 签名验证（如有）
    │     ├─ signatureVerifier.verify()
    │     ├─ 检查 nonce（防重放）
    │     └─ 检查 timestamp（防过期）
    │
    └─ CommandRouter.route(payload)
          ├─ .appId → 打开小程序
          ├─ .url   → WebView 打开
          ├─ .deeplink → 系统处理
          └─ .none  → Alert "无效口令"
```

### 4.4 用户入口

| 用户操作 | 调用的口令系统 | 说明 |
|----------|---------------|------|
| 首页→QuickAction"粘贴口令" | CommandHandler.checkClipboardOnForeground() | 主动检查剪贴板 |
| 首页→扫描二维码 | QRScanner → CommandParser.parse() | 扫码获取口令 |
| 首页→扫描二维码(结果为URL) | 直接 openURL() | URL 类型直接打开 |
| 设置→口令管理 | TokenManageViewController | 管理 HMAC 密钥 |
| 后端 `/api/v1/command/generate` | 服务端生成签名口令 | 开发者 API |
| 后端 `/api/v1/command/resolve` | 服务端解析口令 | 开发者 API |

---

## 5. WebSocket 引擎

### 5.1 架构

```
WebSocketEngine
├── WebSocketClient (连接管理)
│   ├── 心跳保活 (ping/pong)
│   ├── 自动重连 (指数退避)
│   └── 状态机 (connecting/connected/disconnecting/closed)
├── WebSocketHandler (消息分发)
│   ├── JSON-RPC 2.0 协议
│   ├── Request/Response 模式
│   └── Notification 模式
└── WebSocketConfiguration
    ├── URL/Headers
    ├── 重连策略
    └── 超时设置
```

### 5.2 JSON-RPC 2.0 消息格式

```json
// Request
{"jsonrpc":"2.0","method":"cache.getStatus","params":{},"id":1}

// Response
{"jsonrpc":"2.0","result":{"totalSize":1024,"fileCount":5},"id":1}

// Notification
{"jsonrpc":"2.0","method":"message.received","params":{"title":"Hello"}}
```

---

## 6. AI 调试接口

### 6.1 架构

```
AI HTTP Server (:8765)
├── AIRouter
│   ├── GET /health
│   ├── POST /mcp (MCP 协议)
│   └── POST /webhook (Webhook Channel)
├── AI Tools (13个)
│   ├── ReadOnly (查询类)
│   │   ├── handler.list    → 列出所有 Handler
│   │   ├── handler.describe → 描述 Handler 方法
│   │   ├── cache.stats     → 缓存统计
│   │   ├── cache.inspect   → 缓存检查
│   │   └── message.history → 消息历史
│   ├── ReadWrite (操作类)
│   │   ├── cache.clear     → 清除缓存
│   │   ├── cache.prefetch  → 预缓存
│   │   ├── message.send    → 发送消息
│   │   └── command.execute → 执行命令
│   └── Builtin (内置)
│       ├── system.info     → 系统信息
│       ├── debug.log       → 调试日志
│       └── diagnostic.run  → 诊断运行
└── MCP Protocol (Model Context Protocol)
```

---

## 7. 调用关系图

### 7.1 用户操作 → 系统调用映射

```
┌─────────────────── 用户操作 ───────────────────┐
│                                                  │
│  首页-PushToken注册  ──→ PushNotificationManager │
│  首页-PushToken复制  ──→ UIPasteboard             │
│  首页-扫描二维码    ──→ QRScannerVC               │
│                      │                           │
│                      ├─ 结果是口令 → CommandParser│
│                      └─ 结果是URL  → openURL()   │
│                                                  │
│  首页-粘贴口令      ──→ CommandHandler            │
│                      └─ CommandParser.parse()    │
│                          └─ CommandRouter.route()│
│                                                  │
│  首页-生成Token     ──→ TokenManageVC             │
│  首页-调试          ──→ TabBar.switchTo(3)        │
│  首页-清理缓存      ──→ WebCacheManager.clearAll()│
│  首页-URLGrid点击   ──→ openURL() → WebView      │
│                      └─ CacheURLSchemeHandler     │
│                          └─ CacheRuleManager     │
│                                                  │
│  收信箱-FAB铃铛     ──→ BarkChannel.send()       │
│  收信箱-消息点击     ──→ MessageDetailVC          │
│  收信箱-搜索        ──→ InMemoryMessageStore      │
│                                                  │
│  发现页-下拉刷新    ──→ ManifestCacheManager      │
│  发现页-卡片点击     ──→ openURL() → WebView      │
│                                                  │
│  设置-服务器配置    ──→ ServerConfigManager       │
│  设置-口令管理      ──→ TokenManageVC             │
│  设置-API Key      ──→ APIKeyManager             │
│  设置-缓存管理      ──→ ManagementVC              │
│  设置-调试面板      ──→ DebugPanelVC              │
│  设置-缓存仪表盘    ──→ CacheDashboardVC          │
│                      └─ CacheStatsAggregator     │
│                          └─ 11个子系统统计        │
│                                                  │
│  WebView内JS调用    ──→ WebJavaScriptBridge       │
│                      └─ 35+ Handler              │
│                                                  │
│  WebSocket连接     ──→ WebSocketEngine            │
│                      └─ JSON-RPC 2.0             │
│                                                  │
│  AI调试接口        ──→ AIServer (:8765)           │
│                      └─ 13 Tools (MCP协议)        │
│                                                  │
└──────────────────────────────────────────────────┘
```

### 7.2 后端路由 (Server :8080)

| 方法 | 路由 | 功能 | 对应前端入口 |
|------|------|------|-------------|
| GET | `/health` | 健康检查 | App 启动检查 |
| GET | `/:key/:title/:body` | Bark 推送 | BarkChannel.send() |
| POST | `/register` | 设备注册 | PushNotificationManager |
| GET | `/api/v1/manifests` | 获取 Manifest | ManifestDownloader |
| POST | `/api/v1/command/generate` | 生成口令 | TokenManageVC |
| POST | `/api/v1/command/resolve` | 解析口令 | CommandParser |

---

## 附录：文件索引

| 体系 | 核心文件 | 行数(估) |
|------|---------|---------|
| Bridge | Sources/Core/WebJavaScriptBridge.swift | ~300 |
| Bridge | Sources/Handlers/** (35+ 文件) | ~3000 |
| Cache | Sources/Cache/** (30+ 文件) | ~2500 |
| Message | Sources/Message/** (10 文件) | ~800 |
| Command | Sources/CommandParser/** (5 文件) | ~400 |
| WebSocket | Sources/WebSocket/** (6 文件) | ~500 |
| AI | Sources/AI/** (5 文件) | ~400 |
