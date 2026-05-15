import Foundation
import RealmSwift
import WebBridgeKit

struct TestDataSeeder {

    private static let seededKey = "TestDataSeeder_Sealed"

    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func date(_ string: String) -> Date {
        return dateFormatter.date(from: string) ?? Date()
    }

    static func populateIfNeeded() {
        let needsSeed = !UserDefaults.standard.bool(forKey: seededKey)

        if needsSeed {
            print("[TestDataSeeder] 开始填充测试数据...")

            seedServerConfigs()
            seedAccessTokens()
            seedCommandTokens()
            seedFavorites()
            seedHistory()
            seedAPIKeys()
            seedCacheRules()
            seedPageCacheRules()

            UserDefaults.standard.set(true, forKey: seededKey)

            print("[TestDataSeeder] 测试数据填充完成")
        } else {
            print("[TestDataSeeder] 已填充过，跳过")
        }

        seedManifestCaches()

        seedPinnedURLs()
    }

    // MARK: - Server Configs

    private static func seedServerConfigs() {
        do {
            let config = ServerConfigManager.shared.realmConfiguration
            let realm = try Realm(configuration: config)
            if realm.object(ofType: ServerConfig.self, forPrimaryKey: "default") != nil { return }

            try realm.write {
                let defaultConfig = ServerConfig()
                defaultConfig.id = "default"
                defaultConfig.serverType = "default"
                defaultConfig.baseURL = nil
                defaultConfig.apiEndpoint = nil
                defaultConfig.isActive = true
                defaultConfig.updatedAt = date("2026-05-10T08:00:00Z")
                realm.add(defaultConfig)

                let localConfig = ServerConfig()
                localConfig.id = "local-hb"
                localConfig.serverType = "custom"
                localConfig.baseURL = "http://localhost:8080"
                localConfig.apiEndpoint = "/push"
                localConfig.isActive = true
                localConfig.updatedAt = date("2026-05-10T08:00:00Z")
                realm.add(localConfig)

                let prodConfig = ServerConfig()
                prodConfig.id = "prod-server"
                prodConfig.serverType = "custom"
                prodConfig.baseURL = "https://wbk.shanbox.19930810.xyz:8443"
                prodConfig.apiEndpoint = "/v1/push"
                prodConfig.isActive = true
                prodConfig.updatedAt = date("2026-05-09T12:00:00Z")
                realm.add(prodConfig)

                let barkConfig = ServerConfig()
                barkConfig.id = "bark-server"
                barkConfig.serverType = "custom"
                barkConfig.baseURL = "https://wbk.shanbox.19930810.xyz:8443"
                barkConfig.apiEndpoint = nil
                barkConfig.isActive = true
                barkConfig.updatedAt = date("2026-05-09T12:00:00Z")
                realm.add(barkConfig)

                let inactiveConfig = ServerConfig()
                inactiveConfig.id = "inactive-custom-014"
                inactiveConfig.serverType = "custom"
                inactiveConfig.baseURL = "https://wbk.shanbox.19930810.xyz:8443"
                inactiveConfig.apiEndpoint = "/v1/push"
                inactiveConfig.isActive = false
                inactiveConfig.updatedAt = date("2026-04-20T08:00:00Z")
                realm.add(inactiveConfig)

                let invalidUrlConfig = ServerConfig()
                invalidUrlConfig.id = "invalid-url-015"
                invalidUrlConfig.serverType = "custom"
                invalidUrlConfig.baseURL = "htp://not-a-valid-url"
                invalidUrlConfig.apiEndpoint = "/push"
                invalidUrlConfig.isActive = true
                invalidUrlConfig.updatedAt = date("2026-05-09T15:00:00Z")
                realm.add(invalidUrlConfig)
            }
            print("[TestDataSeeder] 服务器配置: 6 条")
        } catch {
            print("[TestDataSeeder] 服务器配置填充失败: \(error)")
        }
    }

    // MARK: - Access Tokens

    private static func seedAccessTokens() {
        do {
            let config = AccessTokenManager.shared.realmConfiguration
            let realm = try Realm(configuration: config)
            if realm.object(ofType: AccessToken.self, forPrimaryKey: "token-perm-001") != nil { return }

            try realm.write {
                let perm = AccessToken()
                perm.id = "token-perm-001"
                perm.url = "https://wbk.shanbox.19930810.xyz:8443"
                perm.token = "ABC123XYZ"
                perm.title = "我的永久口令"
                perm.validDuration = -1
                perm.createdAt = date("2026-01-01T00:00:00Z")
                perm.expiresAt = date("2026-01-01T00:00:00Z")
                perm.accessCount = 42
                realm.add(perm)

                let active = AccessToken()
                active.id = "token-active-002"
                active.url = "http://localhost:8080"
                active.token = "WXyz7890"
                active.title = "临时测试口令"
                active.validDuration = 86400
                active.createdAt = date("2026-05-10T08:00:00Z")
                active.expiresAt = date("2026-05-11T08:00:00Z")
                active.accessCount = 3
                realm.add(active)

                let expired = AccessToken()
                expired.id = "token-expired-003"
                expired.url = "http://localhost:8080"
                expired.token = "EXPIRED!"
                expired.title = "过期口令"
                expired.validDuration = 3600
                expired.createdAt = date("2026-05-01T00:00:00Z")
                expired.expiresAt = date("2026-05-01T01:00:00Z")
                expired.accessCount = 15
                realm.add(expired)

                let week = AccessToken()
                week.id = "token-7day-004"
                week.url = "https://wbk.shanbox.19930810.xyz:8443"
                week.token = "WeekTokn"
                week.title = "周卡口令"
                week.validDuration = 604800
                week.createdAt = date("2026-05-08T00:00:00Z")
                week.expiresAt = date("2026-05-15T00:00:00Z")
                week.accessCount = 0
                realm.add(week)

                let emptyToken = AccessToken()
                emptyToken.id = "token-empty-025"
                emptyToken.url = ""
                emptyToken.token = ""
                emptyToken.title = "未注册（空令牌）"
                emptyToken.validDuration = 0
                emptyToken.createdAt = date("2026-05-11T00:00:00Z")
                emptyToken.expiresAt = date("1970-01-01T00:00:00Z")
                emptyToken.accessCount = 0
                realm.add(emptyToken)
            }
            print("[TestDataSeeder] 访问口令: 5 条")
        } catch {
            print("[TestDataSeeder] 访问口令填充失败: \(error)")
        }
    }

    // MARK: - Cache Entries (moved to TestDataSeeder+Entities.swift)

    // MARK: - Messages (moved to TestDataSeeder+Entities.swift)

    // MARK: - Favorites

    private static let baseURL = "https://wbk.shanbox.19930810.xyz:8443"

    private static func seedFavorites() {
        let fk = "TestDataSeeder_Favorites_Sealed"
        do {
            let config = URLFavoriteManager.shared.realmConfiguration
            print("[TestDataSeeder] Favorites Realm config: \(config.fileURL?.path ?? "nil") schemaVersion=\(config.schemaVersion)")

            let realm = try Realm(configuration: config)
            if realm.object(ofType: URLFavorite.self, forPrimaryKey: "fav-e2e-001") != nil {
                UserDefaults.standard.set(true, forKey: fk)
                return
            }
            if UserDefaults.standard.bool(forKey: fk) && !realm.objects(URLFavorite.self).isEmpty { return }

            try realm.write {
                let favs: [(id: String, url: String, title: String, pinned: Bool, order: Int, cache: Bool, cacheType: String, date: String)] = [
                    ("fav-e2e-001", baseURL + "/test_resources/e2e-test.html", "E2E 测试", true, 0, true, "offline", "2026-05-13T08:00:00Z"),
                    ("fav-dashboard-002", baseURL + "/test_resources/engine-dashboard.html", "引擎总览", true, 1, true, "offline", "2026-05-13T09:00:00Z"),
                    ("fav-cache-003", baseURL + "/test_resources/cache-showcase.html", "缓存引擎", true, 2, true, "smart", "2026-05-13T10:00:00Z"),
                    ("fav-msg-004", baseURL + "/test_resources/message-showcase.html", "消息引擎", true, 3, true, "smart", "2026-05-13T11:00:00Z"),
                    ("fav-ws-005", baseURL + "/test_resources/websocket-showcase.html", "WebSocket", false, 4, true, "smart", "2026-05-13T12:00:00Z"),
                    ("fav-bridge-006", baseURL + "/test_resources/bridge-hub.html", "Bridge 测试", false, 5, false, "live", "2026-05-13T13:00:00Z"),
                    ("fav-admin-007", baseURL + "/admin", "管理后台", false, 6, false, "live", "2026-05-13T14:00:00Z"),
                    ("fav-health-008", baseURL + "/health", "健康检查", false, 7, false, "live", "2026-05-13T15:00:00Z"),
                    ("fav-dev-009", "http://192.168.0.4:5173", "Dev Server", false, 8, false, "live", "2026-05-14T00:00:00Z"),
                    ("fav-tester-010", baseURL + "/test_resources/all-in-one-tester.html", "综合测试", true, 9, true, "offline", "2026-05-14T02:00:00Z")
                ]

                for f in favs {
                    let fav = URLFavorite()
                    fav.id = f.id
                    fav.url = f.url
                    fav.title = f.title
                    fav.isPinned = f.pinned
                    fav.sortOrder = f.order
                    fav.enableCacheMode = f.cache
                    fav.cacheType = f.cacheType
                    fav.createdAt = date(f.date)
                    realm.add(fav)
                }
            }
            UserDefaults.standard.set(true, forKey: fk)
            print("[TestDataSeeder] 收藏夹: 9 条 (total in realm: \(realm.objects(URLFavorite.self).count))")

            // 增量添加：192.168.0.4:5173 开发服务器(已存在种子数据时单独补充)
            if realm.object(ofType: URLFavorite.self, forPrimaryKey: "fav-dev-009") == nil {
                try realm.write {
                    let fav = URLFavorite()
                    fav.id = "fav-dev-009"
                    fav.url = "http://192.168.0.4:5173"
                    fav.title = "Dev Server"
                    fav.isPinned = false
                    fav.sortOrder = 8
                    fav.enableCacheMode = false
                    fav.cacheType = "live"
                    fav.createdAt = date("2026-05-14T00:00:00Z")
                    realm.add(fav)
                }
                print("[TestDataSeeder] 收藏夹: 增量添加 Dev Server (192.168.0.4:5173)")
            }
        } catch {
            print("[TestDataSeeder] 收藏夹填充失败: \(error.localizedDescription)")
        }
    }

    // MARK: - History

    private static func seedHistory() {
        do {
            let config = WebPageHistoryManager.shared.realmConfiguration
            let realm = try Realm(configuration: config)
            if realm.object(ofType: WebPageHistory.self, forPrimaryKey: "hist-weather-001") != nil { return }

            let now = Date()

            try realm.write {
                let histories: [(id: String, url: String, title: String, cached: Bool, size: Int64, pinned: Bool, favorite: Bool, visits: Int, ruleId: String?, ruleName: String?, excluded: Bool, agoSeconds: TimeInterval)] = [
                    ("hist-weather-001", "https://wbk.shanbox.19930810.xyz:8443/test_resources/bridge-interaction.html", "Bridge 交互测试", true, 184320, true, true, 35, nil, nil, false, 3600),
                    ("hist-shop-002", "https://wbk.shanbox.19930810.xyz:8443/test_resources/bridge-media.html", "Bridge 媒体测试", true, 1155072, true, true, 28, nil, nil, false, 5400),
                    ("hist-notes-003", "https://wbk.shanbox.19930810.xyz:8443/test_resources/bridge-device.html", "Bridge 设备测试", true, 92160, false, true, 42, nil, nil, false, 7200),
                    ("hist-admin-004", "https://wbk.shanbox.19930810.xyz:8443/admin", "管理后台", true, 163840, true, true, 15, nil, nil, false, 10800),
                    ("hist-news-005", "https://wbk.shanbox.19930810.xyz:8443/test_resources/bridge-permission.html", "Bridge 权限测试", true, 40960, false, false, 30, nil, nil, false, 86400),
                    ("hist-dashboard-006", "https://wbk.shanbox.19930810.xyz:8443/test_resources/engine-dashboard.html", "引擎总览", true, 2179072, false, true, 22, nil, nil, false, 14400),
                    ("hist-docs-007", "https://wbk.shanbox.19930810.xyz:8443/test_resources/bridge-cache.html", "Bridge 缓存测试", true, 204800, false, true, 45, nil, nil, false, 21600),
                    ("hist-local-008", "http://localhost:8080/health", "本地服务", false, 0, false, false, 1, nil, nil, false, 28800)
                ]

                for h in histories {
                    let hist = WebPageHistory()
                    hist.id = h.id
                    hist.url = h.url
                    hist.title = h.title
                    hist.isCached = h.cached
                    hist.cachedSize = h.size
                    hist.isPinned = h.pinned
                    hist.isFavorite = h.favorite
                    hist.visitCount = h.visits
                    hist.lastVisitDate = now.addingTimeInterval(-h.agoSeconds)
                    hist.cacheDate = h.cached ? now.addingTimeInterval(-h.agoSeconds - 3600) : nil
                    hist.ruleId = h.ruleId
                    hist.ruleName = h.ruleName
                    hist.isExcluded = h.excluded
                    if h.cached {
                        hist.htmlPath = "/var/mobile/WebPageCache/\(h.id)/index.html"
                    }
                    realm.add(hist)
                }
            }
            print("[TestDataSeeder] 访问历史: 16 条")
        } catch {
            print("[TestDataSeeder] 访问历史填充失败: \(error)")
        }
    }

    // MARK: - API Keys

    private static func seedAPIKeys() {
        let storageKey = "SuperCache_APIKeys"
        let defaults = UserDefaults.standard
        if defaults.data(forKey: storageKey) != nil { return }

        let keys = [
            APIKey(
                id: "key-bark-001",
                name: "Bark 推送密钥",
                value: "sk-a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
                createdAt: date("2026-04-01T00:00:00Z"),
                expiresAt: nil,
                description: "用于 Bark 推送通道的服务端密钥",
                isEnabled: true,
                boundGroupId: "bark-push"
            ),
            APIKey(
                id: "key-expired-002",
                name: "测试密钥（已过期）",
                value: "sk-xyz987abc456def",
                createdAt: date("2026-01-01T00:00:00Z"),
                expiresAt: date("2026-03-01T00:00:00Z"),
                description: "仅用于测试的临时密钥",
                isEnabled: true,
                boundGroupId: nil
            ),
            APIKey(
                id: "key-short-003",
                name: "临时调试密钥",
                value: "sk-temp123456789abcdef",
                createdAt: date("2026-05-09T00:00:00Z"),
                expiresAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                description: "调试用，48小时有效",
                isEnabled: true,
                boundGroupId: "debug-group"
            ),
            APIKey(
                id: "key-disabled-004",
                name: "旧版推送密钥",
                value: "sk-oldkey1234567890",
                createdAt: date("2025-12-01T00:00:00Z"),
                expiresAt: nil,
                description: "已弃用的推送密钥",
                isEnabled: false,
                boundGroupId: nil
            ),
            APIKey(
                id: "key-webhook-005",
                name: "Webhook 签名密钥",
                value: "whsec_abcdef1234567890fedcba0987654321",
                createdAt: date("2026-05-01T00:00:00Z"),
                expiresAt: nil,
                description: "用于验证 GitHub Webhook 签名",
                isEnabled: true,
                boundGroupId: nil
            )
        ]

        do {
            let data = try JSONEncoder().encode(keys)
            defaults.set(data, forKey: storageKey)
            print("[TestDataSeeder] API Key: \(keys.count) 条")
        } catch {
            print("[TestDataSeeder] API Key 填充失败: \(error)")
        }
    }

    // MARK: - Cache Rules

    private static func seedCacheRules() {
        let rules = CacheRuleManager.shared

        let cacheRules: [CacheRule] = [
            CacheRule(
                id: "rule-domain-001",
                name: "缓存所有 CDN 资源",
                type: .domain,
                pattern: "*.wbk.shanbox.19930810.xyz",
                resourceType: .staticResource,
                isEnabled: true,
                priority: 10
            ),
            CacheRule(
                id: "rule-glob-002",
                name: "缓存所有 JS/CSS",
                type: .glob,
                pattern: "https://wbk.shanbox.19930810.xyz:8443/**/*.{js,css}",
                resourceType: .staticResource,
                isEnabled: true,
                priority: 20
            ),
            CacheRule(
                id: "rule-regex-003",
                name: "API 数据缓存",
                type: .regex,
                pattern: "https://wbk\\.shanbox\\.19930810\\.xyz:8443/v[0-9]+/data.*",
                resourceType: .dynamicResource,
                isEnabled: true,
                priority: 5
            ),
            CacheRule(
                id: "rule-exact-004",
                name: "首页精确缓存",
                type: .exact,
                pattern: "https://wbk.shanbox.19930810.xyz:8443/index.html",
                resourceType: .staticResource,
                isEnabled: true,
                priority: 15
            ),
            CacheRule(
                id: "rule-disabled-005",
                name: "旧版缓存规则",
                type: .domain,
                pattern: "old.wbk.shanbox.19930810.xyz",
                resourceType: .staticResource,
                isEnabled: false,
                priority: 0
            )
        ]

        for rule in cacheRules {
            rules.addRule(rule)
        }
        print("[TestDataSeeder] 缓存规则: \(cacheRules.count) 条")
    }

    // MARK: - Command Tokens

    private static func seedCommandTokens() {
        let storageKey = "TestDataSeeder_CommandTokens"
        let defaults = UserDefaults.standard
        if defaults.data(forKey: storageKey) != nil { return }

        let now = ISO8601DateFormatter().string(from: Date())

        let tokens: [[String: String]] = [
            [
                "id": "cmd-url-001",
                "type": "urlScheme",
                "data": "wbk://open?url=https%3A%2F%2Fwbk.shanbox.19930810.xyz%3A8443%2Ftest_resources%2Fbridge-hub.html%26title%3DTest",
                "format": "urlScheme",
                "signature": "sig_url_a1b2c3d4e5f6",
                "createdAt": now,
                "expiresAt": "",
                "label": "URL Scheme 令牌"
            ],
            [
                "id": "cmd-b64-002",
                "type": "base64",
                "data": "eyJhY3Rpb24iOiJvcGVuIiwidXJlIjoiaHR0cHM6Ly93Ymsuc2hhbmJveC4xOTkzMDgxMC54eXo6ODQ0MyJ9",
                "format": "base64",
                "signature": "sig_b64_x7y8z9w0v1u",
                "createdAt": now,
                "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400)),
                "label": "Base64 编码令牌"
            ],
            [
                "id": "cmd-text-003",
                "type": "plainText",
                "data": "Hello from WebBridgeKit command!",
                "format": "plainText",
                "signature": "sig_txt_m2n3o4p5q6r",
                "createdAt": now,
                "expiresAt": "",
                "label": "纯文本令牌"
            ],
            [
                "id": "cmd-json-004",
                "type": "json",
                "data": "{\"action\":\"navigate\",\"url\":\"https://wbk.shanbox.19930810.xyz:8443/admin\",\"params\":{\"tab\":\"overview\"}}",
                "format": "plainText",
                "signature": "sig_json_s7t8u9v0w1x",
                "createdAt": now,
                "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(172800)),
                "label": "JSON 格式令牌"
            ]
        ]

        do {
            let data = try JSONEncoder().encode(tokens)
            defaults.set(data, forKey: storageKey)
            print("[TestDataSeeder] Command Token: \(tokens.count) 条")
        } catch {
            print("[TestDataSeeder] Command Token 填充失败: \(error)")
        }
    }

    // MARK: - Page Cache Rules

    private static func seedPageCacheRules() {
        let manager = PageCacheRuleManager.shared
        let existing = manager.getAllRules()
        guard existing.isEmpty else { return }

        let rules: [PageCacheRule] = [
            PageCacheRule(
                id: "preset-baidu",
                name: "百度",
                includePatterns: ["https://*.baidu.com/**"],
                excludePatterns: ["https://*.baidu.com/login/**"],
                isEnabled: true,
                createdAt: date("2026-05-01T08:00:00Z")
            ),
            PageCacheRule(
                id: "preset-vip-video",
                name: "VIP 视频",
                includePatterns: ["https://*.vip.com/video/**", "https://*.vip.com/movie/**"],
                excludePatterns: ["https://*.vip.com/login*", "https://*.vip.com/register*"],
                isEnabled: true,
                createdAt: date("2026-05-02T10:00:00Z")
            ),
            PageCacheRule(
                id: "preset-github",
                name: "GitHub",
                includePatterns: ["https://github.com/**"],
                excludePatterns: [],
                isEnabled: true,
                createdAt: date("2026-05-03T12:00:00Z")
            ),
            PageCacheRule(
                id: "custom-multi-004",
                name: "多模式自定义规则",
                includePatterns: [
                    "https://wbk.shanbox.19930810.xyz:8443/**/*.{html,css,js}",
                    "https://wbk.shanbox.19930810.xyz:8443/v1/static/**"
                ],
                excludePatterns: ["**/admin/**", "**/login*"],
                isEnabled: true,
                createdAt: date("2026-05-09T08:00:00Z"),
                lastCachedAt: date("2026-05-10T06:00:00Z")
            ),
            PageCacheRule(
                id: "custom-disabled-005",
                name: "已禁用的测试规则",
                includePatterns: ["https://wbk.shanbox.19930810.xyz:8443/**"],
                excludePatterns: [],
                isEnabled: false,
                createdAt: date("2026-04-15T08:00:00Z")
            )
        ]

        var addedCount = 0
        for rule in rules where manager.addRule(rule) { addedCount += 1 }

        print("[TestDataSeeder] Page Cache Rule: \(addedCount) 条")
    }

    // MARK: - Manifest Caches (moved to TestDataSeeder+Entities.swift)

    // MARK: - Pinned URLs

    private static func seedPinnedURLs() {
        let key = "TestDataSeeder_PinnedURLs_v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let recommended = PresetURLCatalog.recommendedItems
        let manager = URLFavoriteManager.shared
        for item in recommended {
            guard let url = URL(string: item.url) else { continue }
            if manager.findFavorite(url: url) == nil {
                manager.addFavorite(url: url, title: item.title)
            }
        }
        WebBridgeLogger.shared.log(.info, "Seeded \(recommended.count) recommended pinned URLs")

        UserDefaults.standard.set(true, forKey: key)
    }
}
