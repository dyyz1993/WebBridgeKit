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
                    ("weather_index_html", "https://cdn.weather.com/app/index.html", "text/html", 24576, 8192, "/cache/weather/index.html"),
                    ("weather_main_css", "https://cdn.weather.com/app/styles/main.css", "text/css", 32768, 6144, "/cache/weather/styles/main.css"),
                    ("weather_js", "https://cdn.weather.com/app/scripts/weather.js", "application/javascript", 102400, 30720, "/cache/weather/scripts/weather.js"),
                    ("weather_sunny_svg", "https://cdn.weather.com/app/images/sunny.svg", "image/svg+xml", 4096, 2048, "/cache/weather/images/sunny.svg"),
                    ("weather_cities_json", "https://cdn.weather.com/app/data/cities.json", "application/json", 16384, 4096, "/cache/weather/data/cities.json"),
                    ("notes_index_html", "https://notes.md/editor/index.html", "text/html", 16384, 5120, "/cache/notes/index.html"),
                    ("notes_editor_css", "https://notes.md/editor/editor.css", "text/css", 24576, 4096, "/cache/notes/editor.css"),
                    ("notes_marked_js", "https://notes.md/editor/marked.min.js", "application/javascript", 45056, 16384, "/cache/notes/marked.min.js"),
                    ("notes_highlight_js", "https://notes.md/editor/highlight.js", "application/javascript", 65536, 24576, "/cache/notes/highlight.js"),
                    ("notes_editor_js", "https://notes.md/editor/editor.js", "application/javascript", 32768, 10240, "/cache/notes/editor.js"),
                    ("shop_vendor_js", "https://m.shop.example.com/static/js/vendor.js", "application/javascript", 524288, 153600, "/cache/shop/vendor.js"),
                    ("shop_app_js", "https://m.shop.example.com/static/js/app.js", "application/javascript", 204800, 61440, "/cache/shop/app.js"),
                    ("shop_banner1_webp", "https://m.shop.example.com/static/images/banner1.webp", "image/webp", 81920, 77824, "/cache/shop/banner1.webp"),
                    ("shop_iconfont_woff2", "https://m.shop.example.com/static/fonts/iconfont.woff2", "font/woff2", 45056, 43008, "/cache/shop/iconfont.woff2"),
                    ("shop_categories_json", "https://m.shop.example.com/static/data/categories.json", "application/json", 32768, 8192, "/cache/shop/categories.json"),
                    ("game_bgm_mp3", "https://play.casual.games/tetris/sounds/bgm.mp3", "audio/mpeg", 1048576, 1048576, "/cache/game/bgm.mp3"),
                    ("game_clear_wav", "https://play.casual.games/tetris/sounds/clear.wav", "audio/wav", 20480, 20480, "/cache/game/clear.wav"),
                    ("game_sprites_png", "https://play.casual.games/tetris/sprites.png", "image/png", 65536, 65536, "/cache/game/sprites.png"),
                    ("game_js", "https://play.casual.games/tetris/game.js", "application/javascript", 40960, 15360, "/cache/game/game.js"),
                    ("news_index_html", "https://news.daily/feed/index.html", "text/html", 12288, 4096, "/cache/news/index.html"),
                    ("news_feed_js", "https://news.daily/feed/feed.js", "application/javascript", 20480, 8192, "/cache/news/feed.js"),
                    ("news_styles_css", "https://news.daily/feed/styles.css", "text/css", 8192, 2048, "/cache/news/styles.css"),
                    ("docs_index_html", "https://docs.swift.org/getting-started/index.html", "text/html", 32768, 10240, "/cache/docs/index.html"),
                    ("docs_theme_css", "https://docs.swift.org/css/theme.css", "text/css", 40960, 12288, "/cache/docs/theme.css"),
                    ("docs_search_js", "https://docs.swift.org/js/search.js", "application/javascript", 61440, 20480, "/cache/docs/search.js"),
                    ("docs_nav_js", "https://docs.swift.org/js/navigation.js", "application/javascript", 32768, 10240, "/cache/docs/navigation.js"),
                    ("admin_index_html", "https://admin.example.com/dashboard/index.html", "text/html", 20480, 6144, "/cache/admin/index.html"),
                    ("admin_app_css", "https://admin.example.com/static/app.css", "text/css", 40960, 14336, "/cache/admin/app.css"),
                    ("admin_app_js", "https://admin.example.com/static/app.js", "application/javascript", 81920, 30720, "/cache/admin/app.js"),
                    ("admin_charts_js", "https://admin.example.com/static/charts.js", "application/javascript", 57344, 20480, "/cache/admin/charts.js"),
                    ("dashboard_index_html", "https://dashboard.example.com/index.html", "text/html", 28672, 8192, "/cache/dashboard/index.html"),
                    ("dashboard_app_js", "https://dashboard.example.com/app.js", "application/javascript", 184320, 61440, "/cache/dashboard/app.js"),
                    ("dashboard_chart_js", "https://dashboard.example.com/chart.js", "application/javascript", 102400, 30720, "/cache/dashboard/chart.js"),
                    ("dashboard_data_css", "https://dashboard.example.com/data.css", "text/css", 24576, 6144, "/cache/dashboard/data.css")
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
            print("[TestDataSeeder] 缓存条目: 34 条")
            UserDefaults.standard.set(true, forKey: storageKey)
        } catch {
            print("[TestDataSeeder] 缓存条目填充失败: \(error)")
        }
    }

    // MARK: - Messages

    static func seedMessages() {
        let defaults = UserDefaults.standard
        let key = "SuperCache_Messages"
        if defaults.data(forKey: key) != nil { return }

        let now = Date()
        let hour1Ago = now.addingTimeInterval(-3600)
        let hour2Ago = now.addingTimeInterval(-7200)
        let hour3Ago = now.addingTimeInterval(-10800)
        let hour4Ago = now.addingTimeInterval(-14400)
        let day1Ago = now.addingTimeInterval(-86400)
        let day2Ago = now.addingTimeInterval(-172800)
        let day3Ago = now.addingTimeInterval(-259200)

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
                    targetURL: "https://weather.com/beijing",
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
                    targetURL: "https://monitor.example.com/dashboard",
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
                    targetURL: "https://account.example.com/security",
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
                    targetURL: "https://weather.com/shanghai",
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
            print("[TestDataSeeder] 消息: \(messages.count) 条")
        } catch {
            print("[TestDataSeeder] 消息填充失败: \(error)")
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
                resources: ["index.html": "https://cdn.weather.com/app/index.html"],
                version: "2.1.0",
                appid: "weather-app",
                name: "北京天气",
                icon: "https://cdn.weather.com/app/icon.png",
                isPinned: true,
                lastAccessed: Date()
            )),
            ("notes-editor", Manifest(
                resources: ["index.html": "https://notes.md/editor/index.html"],
                version: "1.5.3",
                appid: "markdown-notes",
                name: "Markdown 笔记",
                icon: nil,
                lastAccessed: Date().addingTimeInterval(-3600)
            )),
            ("shop-mall", Manifest(
                resources: ["index.html": "https://m.shop.example.com/index.html"],
                version: "3.8.1",
                appid: "shop-mall-app",
                name: "优购商城",
                icon: "https://m.shop.example.com/static/logo.png",
                lastAccessed: Date().addingTimeInterval(-7200)
            )),
            ("game-tetris", Manifest(
                resources: ["index.html": "https://play.casual.games/tetris/"],
                version: "1.2.0",
                appid: "game-tetris",
                name: "俄罗斯方块",
                icon: nil,
                lastAccessed: Date().addingTimeInterval(-86400)
            )),
            ("news-daily", Manifest(
                resources: ["index.html": "https://news.daily/feed/"],
                version: "4.0.0",
                appid: "news-daily",
                name: "每日新闻",
                icon: nil,
                lastAccessed: Date().addingTimeInterval(-172800)
            )),
            ("docs-swift", Manifest(
                resources: ["index.html": "https://docs.swift.org/getting-started/"],
                version: "5.10",
                appid: "swift-docs",
                name: "Swift 文档",
                icon: nil,
                lastAccessed: Date().addingTimeInterval(-259200)
            )),
            ("admin-dashboard", Manifest(
                resources: ["index.html": "https://admin.example.com/dashboard/"],
                version: "2.0.1",
                appid: "admin-panel",
                name: "管理后台",
                icon: nil,
                lastAccessed: Date().addingTimeInterval(-432000)
            )),
            ("analytics-dashboard", Manifest(
                resources: ["index.html": "https://dashboard.example.com/"],
                version: "1.3.7",
                appid: "analytics-app",
                name: "数据分析",
                icon: "https://dashboard.example.com/logo.png",
                lastAccessed: Date().addingTimeInterval(-604800)
            ))
        ]

        for entry in entries {
            store.saveManifestSync(entry.manifest, for: entry.key)
            store.saveHTMLSync("<!DOCTYPE html><html><head><title>\(entry.manifest.name ?? entry.key)</title></head><body></body></html>", for: entry.key)
        }

        store.saveToDiskSync()

        print("[TestDataSeeder] Manifest 缓存: \(entries.count) 条")
    }
}
