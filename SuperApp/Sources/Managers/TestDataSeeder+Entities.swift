//
//  TestDataSeeder+Entities.swift
//  SuperApp
//
//  Extracted from TestDataSeeder.swift
//

import Foundation
import RealmSwift
import WebBridgeKit

extension TestDataSeeder {

    // MARK: - Cache Entries

    static func seedCacheEntries() {
        let storageKey = "TestDataSeeder_CacheEntries"
        guard !UserDefaults.standard.bool(forKey: storageKey) else { return }

        do {
            let config = WebResourceCacheManager.shared.configuration
            let realm = try Realm(configuration: config)

            try realm.write {
                let entries: [(key: String, url: String, mime: String, orig: Int64, comp: Int64, filePath: String)] = [
                    ("weather_index_html", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-interaction.html", "text/html", 24576, 8192, "/cache/weather/index.html"),
                    ("weather_main_css", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-interaction.html", "text/css", 32768, 6144, "/cache/weather/styles/main.css"),
                    ("weather_js", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-interaction.html", "application/javascript", 102400, 30720, "/cache/weather/scripts/weather.js"),
                    ("weather_sunny_svg", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-interaction.html", "image/svg+xml", 4096, 2048, "/cache/weather/images/sunny.svg"),
                    ("weather_cities_json", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-interaction.html", "application/json", 16384, 4096, "/cache/weather/data/cities.json"),
                    ("notes_index_html", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-device.html", "text/html", 16384, 5120, "/cache/notes/index.html"),
                    ("notes_editor_css", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-device.html", "text/css", 24576, 4096, "/cache/notes/editor.css"),
                    ("notes_marked_js", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-device.html", "application/javascript", 45056, 16384, "/cache/notes/marked.min.js"),
                    ("notes_highlight_js", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-device.html", "application/javascript", 65536, 24576, "/cache/notes/highlight.js"),
                    ("notes_editor_js", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-device.html", "application/javascript", 32768, 10240, "/cache/notes/editor.js"),
                    ("shop_vendor_js", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-media.html", "application/javascript", 524288, 153600, "/cache/shop/vendor.js"),
                    ("shop_app_js", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-media.html", "application/javascript", 204800, 61440, "/cache/shop/app.js"),
                    ("shop_banner1_webp", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-media.html", "image/webp", 81920, 77824, "/cache/shop/banner1.webp"),
                    ("shop_iconfont_woff2", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-media.html", "font/woff2", 45056, 43008, "/cache/shop/iconfont.woff2"),
                    ("shop_categories_json", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-media.html", "application/json", 32768, 8192, "/cache/shop/categories.json"),
                    ("game_bgm_mp3", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-navigation.html", "audio/mpeg", 1048576, 1048576, "/cache/game/bgm.mp3"),
                    ("game_clear_wav", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-navigation.html", "audio/wav", 20480, 20480, "/cache/game/clear.wav"),
                    ("game_sprites_png", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-navigation.html", "image/png", 65536, 65536, "/cache/game/sprites.png"),
                    ("game_js", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-navigation.html", "application/javascript", 40960, 15360, "/cache/game/game.js"),
                    ("news_index_html", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-permission.html", "text/html", 12288, 4096, "/cache/news/index.html"),
                    ("news_feed_js", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-permission.html", "application/javascript", 20480, 8192, "/cache/news/feed.js"),
                    ("news_styles_css", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-permission.html", "text/css", 8192, 2048, "/cache/news/styles.css"),
                    ("docs_index_html", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-cache.html", "text/html", 32768, 10240, "/cache/docs/index.html"),
                    ("docs_theme_css", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-cache.html", "text/css", 40960, 12288, "/cache/docs/theme.css"),
                    ("docs_search_js", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-cache.html", "application/javascript", 61440, 20480, "/cache/docs/search.js"),
                    ("docs_nav_js", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-cache.html", "application/javascript", 32768, 10240, "/cache/docs/navigation.js"),
                    ("admin_index_html", "https://wbk.shanbox.19930810.xyz:8443/admin", "text/html", 20480, 6144, "/cache/admin/index.html"),
                    ("admin_app_css", "https://wbk.shanbox.19930810.xyz:8443/admin", "text/css", 40960, 14336, "/cache/admin/app.css"),
                    ("admin_app_js", "https://wbk.shanbox.19930810.xyz:8443/admin", "application/javascript", 81920, 30720, "/cache/admin/app.js"),
                    ("admin_charts_js", "https://wbk.shanbox.19930810.xyz:8443/admin", "application/javascript", 57344, 20480, "/cache/admin/charts.js"),
                    ("dashboard_index_html", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/engine-dashboard.html", "text/html", 28672, 8192, "/cache/dashboard/index.html"),
                    ("dashboard_app_js", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/engine-dashboard.html", "application/javascript", 184320, 61440, "/cache/dashboard/app.js"),
                    ("dashboard_chart_js", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/engine-dashboard.html", "application/javascript", 102400, 30720, "/cache/dashboard/chart.js"),
                    ("dashboard_data_css", "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/engine-dashboard.html", "text/css", 24576, 6144, "/cache/dashboard/data.css")
                ]

                let now = Date()
                let day3Ago = Calendar.current.date(byAdding: .day, value: -3, to: now)!
                let day1Ago = Calendar.current.date(byAdding: .day, value: -1, to: now)!
                let day40Ago = Calendar.current.date(byAdding: .day, value: -40, to: now)!

                for (idx, e) in entries.enumerated() {
                    let entry = CacheEntryRealm()
                    entry.key = e.key
                    entry.url = e.url
                    entry.mimeType = e.mime
                    entry.originalSize = e.orig
                    entry.compressedSize = e.comp
                    entry.isCompressed = e.comp < e.orig
                    entry.compressionRatio = e.orig > 0 ? Double(e.comp) / Double(e.orig) : 1.0
                    entry.filePath = e.filePath
                    entry.accessCount = Int.random(in: 1...50)

                    if e.key.hasPrefix("game_") || e.key.hasPrefix("shop_") {
                        entry.lastAccessedAt = day1Ago
                        entry.createdAt = day3Ago
                    } else if e.key.hasPrefix("news_") {
                        entry.lastAccessedAt = day40Ago
                        entry.createdAt = day40Ago
                    } else {
                        entry.lastAccessedAt = now.addingTimeInterval(-Double(idx) * 3600)
                        entry.createdAt = now.addingTimeInterval(-Double.random(in: 86400...2592000))
                    }
                    realm.add(entry)
                }
            }
            UserDefaults.standard.set(true, forKey: storageKey)
        } catch {
        }
    }

    // MARK: - Messages

    static func seedMessages(forceRefresh: Bool = false) {
        let defaults = UserDefaults.standard
        let key = "SuperCache_Messages"
        if !forceRefresh, defaults.data(forKey: key) != nil { return }

        let now = Date()
        let hour1Ago = now.addingTimeInterval(-3600)
        let hour2Ago = now.addingTimeInterval(-7200)
        let hour3Ago = now.addingTimeInterval(-10800)
        let hour4Ago = now.addingTimeInterval(-14400)
        let day1Ago = now.addingTimeInterval(-86400)
        let day2Ago = now.addingTimeInterval(-172800)
        let day3Ago = now.addingTimeInterval(-259200)
        let nativeApprovalRequestID = ProcessInfo.processInfo.environment["WBK_UI_APPROVAL_REQUEST_ID"]
            ?? "approval-native-demo-016"

        let messages: [StoredMessage] = [
            StoredMessage(
                id: "stored-read-001",
                payload: MessagePayload(
                    id: "msg-apns-001",
                    title: "天气预报",
                    body: "今天北京晴，25°C，适合户外活动",
                    subtitle: "北京",
                    channel: "apns",
                    category: "weather",
                    priority: .normal,
                    sound: "default",
                    badge: 3,
                    group: "weather-updates",
                    threadId: "weather-beijing",
                    targetURL: "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-interaction.html",
                    createdAt: hour1Ago
                ),
                isRead: true,
                readAt: hour1Ago.addingTimeInterval(300),
                receivedAt: hour1Ago
            ),
            StoredMessage(
                id: "stored-unread-002",
                payload: MessagePayload(
                    id: "msg-bark-002",
                    title: "服务器告警",
                    body: "CPU 使用率超过 90%，请及时处理",
                    channel: "bark",
                    category: "alert",
                    priority: .high,
                    sound: "alarm.caf",
                    badge: 1,
                    group: "server-alerts",
                    threadId: "server-prod-01",
                    targetURL: "https://wbk.shanbox.19930810.xyz:8443/admin",
                    userInfo: ["server": "prod-01", "metric": "cpu", "threshold": "90"],
                    createdAt: hour2Ago
                ),
                isRead: false,
                receivedAt: hour2Ago
            ),
            StoredMessage(
                id: "stored-bridge-003",
                payload: MessagePayload(
                    id: "msg-bridge-003",
                    title: "订单已确认",
                    body: "您的订单 #20260510001 已确认，预计明天送达",
                    subtitle: "优购商城",
                    channel: "bridge",
                    category: "order",
                    priority: .normal,
                    group: "shop-orders",
                    threadId: "order-20260510001",
                    targetAppId: "shop-mall-app",
                    targetMode: "modal",
                    userInfo: ["orderId": "20260510001", "status": "confirmed"],
                    createdAt: hour3Ago
                ),
                isRead: false,
                receivedAt: hour3Ago
            ),
            StoredMessage(
                id: "stored-sys-004",
                payload: MessagePayload(
                    id: "msg-sys-004",
                    title: "系统维护通知",
                    body: "系统将于今晚 22:00-23:00 进行维护升级",
                    channel: "system",
                    category: "system",
                    priority: .low,
                    group: "system-notices",
                    contentType: .plain,
                    createdAt: hour4Ago
                ),
                isRead: true,
                readAt: hour4Ago.addingTimeInterval(600),
                receivedAt: hour4Ago
            ),
            StoredMessage(
                id: "stored-critical-005",
                payload: MessagePayload(
                    id: "msg-critical-005",
                    title: "安全告警",
                    body: "检测到异常登录，请立即确认是否为本人操作",
                    subtitle: "账户安全",
                    channel: "apns",
                    category: "security",
                    priority: .critical,
                    sound: "critical.caf",
                    badge: 1,
                    group: "security-alerts",
                    targetURL: "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-interaction.html",
                    userInfo: ["alertType": "abnormal_login", "ip": "203.0.113.42", "location": "上海"],
                    createdAt: now.addingTimeInterval(-1800)
                ),
                isRead: false,
                receivedAt: now.addingTimeInterval(-1800)
            ),
            StoredMessage(
                id: "stored-apns-weather2",
                payload: MessagePayload(
                    id: "msg-apns-weather2",
                    title: "降雨提醒",
                    body: "上海今晚有中到大雨，出门请携带雨具",
                    subtitle: "上海",
                    channel: "apns",
                    category: "weather",
                    priority: .normal,
                    sound: "default",
                    group: "weather-updates",
                    threadId: "weather-shanghai",
                    targetURL: "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-interaction.html",
                    createdAt: day1Ago
                ),
                isRead: true,
                readAt: day1Ago.addingTimeInterval(1200),
                receivedAt: day1Ago
            ),
            StoredMessage(
                id: "stored-apns-game",
                payload: MessagePayload(
                    id: "msg-apns-game",
                    title: "好友挑战",
                    body: "你的好友小明在俄罗斯方块中获得了 9800 分，来超越他吧！",
                    subtitle: "小游戏",
                    channel: "apns",
                    category: "game",
                    priority: .normal,
                    sound: "default",
                    group: "game-invites",
                    targetAppId: "game-tetris",
                    targetMode: "push",
                    userInfo: ["gameId": "tetris", "score": "9800"],
                    createdAt: day1Ago.addingTimeInterval(-3600)
                ),
                isRead: false,
                receivedAt: day1Ago.addingTimeInterval(-3600)
            ),
            StoredMessage(
                id: "stored-bark-deploy",
                payload: MessagePayload(
                    id: "msg-bark-deploy",
                    title: "部署完成",
                    body: "v3.5.2 已成功部署到生产环境",
                    channel: "bark",
                    category: "deployment",
                    priority: .normal,
                    group: "server-alerts",
                    threadId: "deploy-prod",
                    userInfo: ["version": "3.5.2", "env": "production"],
                    createdAt: day2Ago
                ),
                isRead: true,
                readAt: day2Ago.addingTimeInterval(300),
                receivedAt: day2Ago
            ),
            StoredMessage(
                id: "stored-bark-monitor",
                payload: MessagePayload(
                    id: "msg-bark-monitor",
                    title: "内存告警",
                    body: "服务器 prod-02 内存使用率 85%，建议关注",
                    channel: "bark",
                    category: "alert",
                    priority: .high,
                    sound: "alarm.caf",
                    group: "server-alerts",
                    userInfo: ["server": "prod-02", "metric": "memory", "threshold": "85"],
                    createdAt: day2Ago.addingTimeInterval(-7200)
                ),
                isRead: true,
                readAt: day2Ago.addingTimeInterval(-7200 + 600),
                receivedAt: day2Ago.addingTimeInterval(-7200)
            ),
            StoredMessage(
                id: "stored-bridge-merchant",
                payload: MessagePayload(
                    id: "msg-bridge-merchant",
                    title: "优惠活动",
                    body: "618大促预热！精选商品低至3折，点击查看",
                    subtitle: "优购商城",
                    channel: "bridge",
                    category: "promotion",
                    priority: .normal,
                    group: "shop-promo",
                    targetAppId: "shop-mall-app",
                    targetMode: "modal",
                    userInfo: ["promotionId": "618-warmup"],
                    createdAt: day3Ago
                ),
                isRead: false,
                receivedAt: day3Ago
            ),
            StoredMessage(
                id: "stored-markdown-011",
                payload: MessagePayload(
                    id: "msg-markdown-011",
                    title: "运行任务已完成",
                    body: "任务输出摘要已生成",
                    markdown: """
                    # 发布任务已完成

                    > 生产环境已完成发布。建议在观察窗口结束前关注核心指标，并保留回滚通道。

                    ## 执行清单

                    - [x] 数据库迁移
                    - [x] 生产包上传
                    - [ ] 灰度观察（30 分钟）

                    ## 关键指标

                    | 指标 | 当前值 | 阈值 |
                    | :--- | ---: | ---: |
                    | 错误率 | 0.02% | < 0.10% |
                    | P95 延迟 | 184 ms | < 250 ms |
                    | 发布耗时 | 2 分 18 秒 | < 5 分钟 |

                    ## 回滚命令

                    ```bash
                    wbk deploy rollback --release 2026.08.12.1
                    ```

                    任务标识：`run-20260510`。结果：**成功**，无需人工干预。

                    [打开 Agent Console](https://example.com/agent-console)
                    """,
                    subtitle: "PWA · Agent Console",
                    channel: "bridge",
                    category: "task",
                    priority: .normal,
                    group: "agent-tasks",
                    targetAppId: "agent-console",
                    contentType: .markdown,
                    userInfo: ["taskId": "run-20260510", "status": "completed"],
                    createdAt: day3Ago.addingTimeInterval(-1800)
                ),
                isRead: false,
                receivedAt: day3Ago.addingTimeInterval(-1800),
                bodyType: "markdown"
            ),
            StoredMessage(
                id: "stored-verification-012",
                payload: MessagePayload(
                    id: "msg-verification-012",
                    title: "登录验证码",
                    body: "验证码 482 901，5 分钟内有效。请勿泄露给他人。",
                    subtitle: "WebBridgeKit",
                    channel: "system",
                    category: "verification",
                    priority: .high,
                    group: "verification-codes",
                    verificationCode: "482 901",
                    expiresAt: now.addingTimeInterval(5 * 60),
                    contentType: .otp,
                    createdAt: now.addingTimeInterval(-120)
                ),
                isRead: false,
                receivedAt: now.addingTimeInterval(-120)
            ),
            StoredMessage(
                id: "stored-qr-015",
                payload: MessagePayload(
                    id: "msg-qr-015",
                    title: "桌面端登录二维码",
                    body: "请使用已登录设备扫码确认，本二维码 10 分钟内有效。",
                    subtitle: "WebBridgeKit",
                    channel: "system",
                    category: "login",
                    priority: .normal,
                    group: "login-requests",
                    expiresAt: now.addingTimeInterval(10 * 60),
                    replacementID: "login-20260811",
                    contentType: .qr,
                    qrPayload: "webbridgekit://login?requestId=login-20260811",
                    createdAt: now.addingTimeInterval(-450)
                ),
                isRead: false,
                receivedAt: now.addingTimeInterval(-450)
            ),
            StoredMessage(
                id: "stored-image-017",
                payload: MessagePayload(
                    id: "msg-image-017",
                    title: "设计稿预览已生成",
                    body: "通知中心新版视觉预览已经生成，可在详情中查看图片。",
                    subtitle: "PWA · Design Review",
                    channel: "apns",
                    category: "design",
                    priority: .normal,
                    group: "design-reviews",
                    imageURL: "http://localhost:8081/test_resources/images/photo1.jpg",
                    contentType: .image,
                    createdAt: now.addingTimeInterval(-420)
                ),
                isRead: false,
                receivedAt: now.addingTimeInterval(-420)
            ),
            StoredMessage(
                id: "stored-image-failure-018",
                payload: MessagePayload(
                    id: "msg-image-failure-018",
                    title: "图片加载失败示例",
                    body: "即使远端图片不可用，通知正文和其他操作仍然可以正常使用。",
                    subtitle: "WebBridgeKit",
                    channel: "system",
                    category: "design",
                    priority: .low,
                    group: "design-reviews",
                    imageURL: "https://127.0.0.1:1/missing.png",
                    contentType: .image,
                    createdAt: now.addingTimeInterval(-410)
                ),
                isRead: true,
                readAt: now.addingTimeInterval(-400),
                receivedAt: now.addingTimeInterval(-410)
            ),
            StoredMessage(
                id: "stored-chat-route-013",
                payload: MessagePayload(
                    id: "msg-chat-route-013",
                    title: "林默发来新消息",
                    body: "刚刚把部署日志补充好了，你方便时看一下。",
                    subtitle: "PWA · Team Chat",
                    channel: "apns",
                    category: "chat",
                    priority: .normal,
                    sound: "default",
                    group: "team-chat-linmo",
                    threadId: "chat-linmo",
                    targetAppId: "com.webbridgekit.fixture.chat",
                    route: "/test_resources/pwa-notification/index.html",
                    targetMode: "immersive",
                    soundVolume: 6,
                    isArchive: true,
                    contentType: .chat,
                    userInfo: ["conversationId": "linmo", "messageId": "chat-108"],
                    createdAt: now.addingTimeInterval(-300)
                ),
                isRead: false,
                receivedAt: now.addingTimeInterval(-300)
            ),
            StoredMessage(
                id: "stored-approval-native-016",
                payload: MessagePayload(
                    id: "msg-approval-native-016",
                    title: "确认部署到生产环境",
                    body: "版本 2.4.0 已通过自动化测试，等待你决定是否继续发布。",
                    subtitle: "PWA · Agent Console",
                    channel: "apns",
                    category: "approval",
                    priority: .high,
                    group: "agent-approvals",
                    replacementID: nativeApprovalRequestID,
                    actionState: .pending,
                    requestID: nativeApprovalRequestID,
                    contentType: .approval,
                    revision: 1,
                    presentation: .native,
                    approval: MessageApproval(actions: [
                        MessageApprovalAction(
                            id: "approve",
                            title: "通过并发布",
                            style: .primary,
                            resultState: .approved
                        ),
                        MessageApprovalAction(
                            id: "reject",
                            title: "拒绝",
                            style: .destructive,
                            requiresReason: true,
                            resultState: .rejected
                        )
                    ]),
                    createdAt: now.addingTimeInterval(-540)
                ),
                isRead: false,
                receivedAt: now.addingTimeInterval(-540)
            ),
            StoredMessage(
                id: "stored-approval-media-014",
                payload: MessagePayload(
                    id: "msg-approval-media-014",
                    title: "需要确认生产发布",
                    body: "远程任务已完成预检。打开审批页后，请手动确认是否继续发布。",
                    subtitle: "PWA · Agent Console",
                    channel: "bridge",
                    category: "approval",
                    priority: .high,
                    sound: "alarm.caf",
                    group: "agent-approvals",
                    targetAppId: "com.webbridgekit.fixture.agent-console",
                    route: "/test_resources/pwa-agent-console/approval.html",
                    targetMode: "modal",
                    imageURL: "https://cloak.xbrowser.dev:5801/fixtures/pwa-agent-console/icon-192.png",
                    interruptionLevel: .timeSensitive,
                    soundVolume: 8,
                    copyText: "approval-42",
                    isArchive: true,
                    ttl: 24 * 60 * 60,
                    replacementID: "approval-42",
                    actionState: .pending,
                    requestID: "approval-42",
                    contentType: .approval,
                    statePath: "/api/approvals/approval-42",
                    revision: 1,
                    userInfo: ["requestId": "approval-42", "source": "remote-task"],
                    createdAt: now.addingTimeInterval(-600)
                ),
                isRead: false,
                receivedAt: now.addingTimeInterval(-600)
            ),
            StoredMessage(
                id: "stored-sys-update",
                payload: MessagePayload(
                    id: "msg-sys-update",
                    title: "版本更新",
                    body: "WebBridgeKit v2.6.0 已发布，新增深色模式支持",
                    channel: "system",
                    category: "update",
                    priority: .low,
                    group: "system-notices",
                    userInfo: ["version": "2.6.0"],
                    createdAt: day3Ago.addingTimeInterval(-3600)
                ),
                isRead: false,
                receivedAt: day3Ago.addingTimeInterval(-3600)
            )
        ]

        do {
            let data = try JSONEncoder().encode(messages)
            defaults.set(data, forKey: key)
        } catch {
        }
    }

    // MARK: - Manifest Caches

    static func seedManifestCaches() {
        _seedManifestCachesImpl()
        if !ProcessInfo.processInfo.arguments.contains("-UITesting") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                _seedManifestCachesImpl()
            }
        }
    }

    static func _seedManifestCachesImpl() {
        let store = ManifestStore.shared
        let allKeys = store.getAllPageKeys()
        guard allKeys.isEmpty else { return }

        let entries: [(key: String, manifest: Manifest)] = [
            ("weather-beijing", Manifest(
                resources: ["index.html": "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-interaction.html"],
                version: "2.1.0",
                appid: "weather-app",
                name: "北京天气",
                icon: "https://wbk.shanbox.19930810.xyz:8443/favicon.ico",
                isPinned: true,
                lastAccessed: Date()
            )),
            ("notes-editor", Manifest(
                resources: ["index.html": "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-device.html"],
                version: "1.5.3",
                appid: "markdown-notes",
                name: "Markdown 笔记",
                icon: nil,
                lastAccessed: Date().addingTimeInterval(-3600)
            )),
            ("shop-mall", Manifest(
                resources: ["index.html": "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-media.html"],
                version: "3.8.1",
                appid: "shop-mall-app",
                name: "优购商城",
                icon: "https://wbk.shanbox.19930810.xyz:8443/favicon.ico",
                lastAccessed: Date().addingTimeInterval(-7200)
            )),
            ("game-tetris", Manifest(
                resources: ["index.html": "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-navigation.html"],
                version: "1.2.0",
                appid: "game-tetris",
                name: "俄罗斯方块",
                icon: nil,
                lastAccessed: Date().addingTimeInterval(-86400)
            )),
            ("news-daily", Manifest(
                resources: ["index.html": "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-permission.html"],
                version: "4.0.0",
                appid: "news-daily",
                name: "每日新闻",
                icon: nil,
                lastAccessed: Date().addingTimeInterval(-172800)
            )),
            ("docs-swift", Manifest(
                resources: ["index.html": "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-cache.html"],
                version: "5.10",
                appid: "swift-docs",
                name: "Swift 文档",
                icon: nil,
                lastAccessed: Date().addingTimeInterval(-259200)
            )),
            ("admin-dashboard", Manifest(
                resources: ["index.html": "https://wbk.shanbox.19930810.xyz:8443/admin"],
                version: "2.0.1",
                appid: "admin-panel",
                name: "管理后台",
                icon: nil,
                lastAccessed: Date().addingTimeInterval(-432000)
            )),
            ("analytics-dashboard", Manifest(
                resources: ["index.html": "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/engine-dashboard.html"],
                version: "1.3.7",
                appid: "analytics-app",
                name: "数据分析",
                icon: "https://wbk.shanbox.19930810.xyz:8443/favicon.ico",
                lastAccessed: Date().addingTimeInterval(-604800)
            ))
        ]

        for entry in entries {
            store.saveManifestSync(entry.manifest, for: entry.key)
            store.saveHTMLSync("<!DOCTYPE html><html><head><title>\(entry.manifest.name ?? entry.key)</title></head><body></body></html>", for: entry.key)
        }

        store.saveToDiskSync()

    }
}
