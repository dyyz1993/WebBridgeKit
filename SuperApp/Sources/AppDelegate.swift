//
//  AppDelegate.swift
//  SuperApp
//
//  Created on 2026-01-16.
//

import UIKit
import UserNotifications
import WebBridgeKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let start = Date()

        CrashLogManager.shared.initialize()
        NetworkMonitor.shared.startMonitoring()

        if let serverURL = ServerConfigManager.shared.getActiveBaseURL() {
            CrashLogManager.shared.serverBaseURL = serverURL
            CrashLogManager.shared.uploadPendingCrashReports()
        }

        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting") || ProcessInfo.processInfo.arguments.contains("--UITesting")
        if isUITesting {
            TestDataSeeder.populateIfNeeded()
            Self.cleanupInvalidHistoryURLs()
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                TestDataSeeder.populateIfNeeded()
                Self.cleanupInvalidHistoryURLs()
            }
        }

        // Removed startup clearAll() — it was deleting PersistentCache files that should survive app restarts.
        // Cache cleanup is now handled by WebCacheManager.scheduleAutoCleanup() which respects persistence.

        // 初始化 WebBridgeKit（异步执行，避免偶尔阻塞主线程导致卡 loading）
        // UI 测试时禁用 WebBridgeKit 预热，减少主线程压力和 WebKit 进程消耗
        if !ProcessInfo.processInfo.arguments.contains("-UITesting") {
            DispatchQueue.global(qos: .userInitiated).async {
                WebBridgeKitManager.shared.initialize()
            }
        } else {
            WebBridgeLogger.shared.info("WebBridgeKit initialized (warmup skipped for UI testing)")
        }

        let messageStore = UserDefaultsMessageStore(key: "SuperCache_Messages")
        Task {
            await MessageEngine.shared.setStore(messageStore)
        }

        // 创建窗口（支持摇一摇触发调试面板）
        window = DebugWindow(frame: UIScreen.main.bounds)

        // 创建根视图控制器（使用 TabBar）
        let tabBarController = TabBarController()

        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        // Initialize all new engines
        Task {
            await EngineBootstrap.shared.initialize(in: self.window)
        }

        // 注册推送通知
        UNUserNotificationCenter.current().delegate = self
        #if !targetEnvironment(simulator)
        registerForPushNotifications(application)
        #endif

        //  Support UI Fidelity Testing — show Component Catalog
        if ProcessInfo.processInfo.arguments.contains("--show-component-catalog") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                let catalogVC = ComponentCatalogViewController()
                let nav = UINavigationController(rootViewController: catalogVC)
                nav.modalPresentationStyle = .fullScreen
                self.window?.rootViewController?.present(nav, animated: false)
            }
        }

        //  Support automated testing via launch arguments
        if ProcessInfo.processInfo.arguments.contains("-RunAllTests") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let tabBarController = self.window?.rootViewController as? UITabBarController {
                    tabBarController.selectedIndex = 1
                    if let nav = tabBarController.viewControllers?[1] as? UINavigationController,
                       let testVC = nav.viewControllers.first as? ManifestTestCasesViewController {
                        testVC.runAllTests()
                    }
                }
            }
        }

        if !ProcessInfo.processInfo.arguments.contains("-UITesting") {
            DispatchQueue.global(qos: .utility).async {
                PushRelayManager.shared.connect()
            }
        }

        let duration = Date().timeIntervalSince(start)
        Log.info("App launch took \(String(format: "%.3f", duration))s", category: .performance)

        #if DEBUG
        registerNotificationFixtureIfRequested()
        showPWAAppCenterIfRequested()
        #endif

        return true
    }

    #if DEBUG
    private func registerNotificationFixtureIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--register-pwa-notification-fixture") else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        let fixture = notificationFixture()
        let manifest = HTMLAppManifest(
            appID: fixture.appID,
            name: fixture.name,
            startURL: "\(fixture.origin)\(fixture.route)",
            allowedOrigins: [fixture.origin],
            capabilities: [.notification],
            routes: fixture.routes,
            cache: HTMLAppCachePolicy(
                strategy: .manifest,
                version: "2026.08.10",
                persistent: true,
                restoresLastState: true
            )
        )
        do {
            try HTMLAppTrustRegistry().register(manifest)
            StructuredLogger.shared.info("Registered APNs route fixture", category: .navigation)
            openNotificationFixtureIfRequested()
        } catch {
            StructuredLogger.shared.error(
                "Unable to register APNs route fixture: \(error.localizedDescription)",
                category: .navigation
            )
        }
    }

    private func openNotificationFixtureIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--open-pwa-notification-fixture") else { return }
        let fixture = notificationFixture()
        let userInfo: [AnyHashable: Any] = [
            "version": "1",
            "appId": fixture.appID,
            "route": fixture.route,
            "title": fixture.notificationTitle,
            "body": fixture.notificationBody,
            "params": fixture.parameters
        ]
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            PushNotificationManager.shared.handleNotificationTap(
                userInfo: userInfo,
                rootViewController: self?.window?.rootViewController
            )
        }
    }

    private func notificationFixture() -> NotificationFixture {
        NotificationFixture(processInfo: ProcessInfo.processInfo)
    }

    private struct NotificationFixture {
        let origin: String
        let appID: String
        let name: String
        let route: String
        let routes: [String]
        let parameters: [String: String]
        let notificationTitle: String
        let notificationBody: String

        init(processInfo: ProcessInfo) {
            origin = processInfo.environment["WBK_PWA_FIXTURE_ORIGIN"] ?? "http://localhost:8081"
            let requestedCase = processInfo.environment["WBK_PWA_FIXTURE_CASE"]

            switch requestedCase {
            case "task":
                appID = "com.webbridgekit.fixture.agent-console"
                name = "Agent Console Fixture"
                route = "/test_resources/pwa-agent-console/index.html"
                routes = [route, "/test_resources/pwa-agent-console/approval.html"]
                parameters = ["taskId": "run-20260810", "status": "completed"]
                notificationTitle = "运行任务已完成"
                notificationBody = "点击查看任务输出并继续处理"
            case "approval":
                appID = "com.webbridgekit.fixture.agent-console"
                name = "Agent Console Fixture"
                route = "/test_resources/pwa-agent-console/approval.html"
                routes = ["/test_resources/pwa-agent-console/index.html", route]
                parameters = ["requestId": "approval-42", "source": "remote-task"]
                notificationTitle = "需要你的确认"
                notificationBody = "打开审批页面后仍需手动确认"
            default:
                appID = "com.webbridgekit.fixture.chat"
                name = "Chat Fixture"
                route = processInfo.environment["WBK_PWA_FIXTURE_ROUTE"] ?? "/test_resources/pwa-notification/index.html"
                routes = Array(Set([
                    route,
                    "/test_resources/pwa-notification/index.html",
                    "/test_resources/pwa-notification/approval.html"
                ])).sorted()
                parameters = ["conversationId": "user-42", "messageId": "message-7"]
                notificationTitle = "收到一条新消息"
                notificationBody = "点击回到与 User 42 的对话"
            }
        }
    }

    private func showPWAAppCenterIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--show-pwa-app-center") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let tabBarController = self?.window?.rootViewController as? TabBarController else { return }
            tabBarController.selectedIndex = 0
            guard let navigationController = tabBarController.selectedViewController as? UINavigationController else { return }
            navigationController.pushViewController(PWAAppCenterViewController(), animated: false)
        }
    }
    #endif

    func applicationWillEnterForeground(_ application: UIApplication) {
        Log.info("App entering foreground", category: .general)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Log.info("App entering background", category: .general)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        if !ProcessInfo.processInfo.arguments.contains("-UITesting") {
            TokenManager.shared.parseTokenFromClipboard()
            CommandHandler.shared.checkClipboardOnForeground()
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if url.scheme == "webbridgekit" {
            // 解析真实的 URL
            // 假设格式为 webbridgekit://open?url=https%3A%2F%2Fgoogle.com
            if url.host == "open" {
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let queryItems = components.queryItems,
                   let targetURLString = queryItems.first(where: { $0.name == "url" })?.value,
                   let targetURL = URL(string: targetURLString) {

                    WebBrowserManager.shared.openBrowser(url: targetURL)
                    return true
                }
            } else if url.host == "tab" {
                // 切换 Tab
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let queryItems = components.queryItems,
                   let indexString = queryItems.first(where: { $0.name == "index" })?.value,
                   let index = Int(indexString),
                   let tabBarController = window?.rootViewController as? UITabBarController {

                    tabBarController.selectedIndex = index
                    return true
                }
            } else if url.host == "command" {
                // Handle webbridgekit://command/<token> — resolve token from server
                let tokenString = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard !tokenString.isEmpty else { return false }
                UIPasteboard.general.string = "webbridgekit://command/\(tokenString)"
                Task { @MainActor in
                    CommandHandler.shared.checkClipboardOnForeground()
                }
                return true
            } else if url.host == "runalltests" {
                if let tabBarController = window?.rootViewController as? UITabBarController,
                   let nav = tabBarController.viewControllers?[1] as? UINavigationController,
                   let testVC = nav.viewControllers.first as? ManifestTestCasesViewController {
                    tabBarController.selectedIndex = 1
                    // Use performSelector to avoid direct dependency if needed, but here it's fine
                    testVC.runAllTests()
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Push Notifications

    private func registerForPushNotifications(_ application: UIApplication) {
        if ProcessInfo.processInfo.arguments.contains("-UITesting") {
            return
        }

        UNUserNotificationCenter.current().delegate = self

        #if !targetEnvironment(simulator)
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        #endif
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        _ = tokenParts.joined()
        PushNotificationManager.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)

        // 将 Token 发送给服务器
        // APIKeyManager.shared.updateDeviceToken(token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let request = notification.request
        Task {
            let payload = makeMessagePayload(
                identifier: request.identifier,
                userInfo: request.content.userInfo,
                content: request.content
            )
            try? await MessageEngine.shared.receive(payload)
        }

        let mode = notification.request.content.userInfo["mode"] as? String
        if mode == "silent" || mode == "passive" {
            completionHandler([])
        } else {
            completionHandler([.banner, .list, .sound, .badge])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let content = response.notification.request.content
        var routingInfo = userInfo
        routingInfo["title"] = userInfo["title"] as? String ?? content.title
        routingInfo["body"] = userInfo["body"] as? String ?? content.body

        DispatchQueue.main.async { [weak self] in
            PushNotificationManager.shared.handleNotificationTap(
                userInfo: routingInfo,
                rootViewController: self?.window?.rootViewController
            )
        }

        Task {
            let payload = makeMessagePayload(
                identifier: response.notification.request.identifier,
                userInfo: userInfo,
                content: content
            )
            try? await MessageEngine.shared.receive(payload)
        }

        completionHandler()
    }

    private func makeMessagePayload(
        identifier: String,
        userInfo: [AnyHashable: Any],
        content: UNNotificationContent
    ) -> MessagePayload {
        let aps = userInfo["aps"] as? [String: Any]
        let rawMarkdown = userInfo["markdown"] as? String
        let markdown = rawMarkdown == "1" || rawMarkdown?.lowercased() == "true"
            ? (userInfo["body"] as? String ?? content.body)
            : rawMarkdown
        let level = notificationLevel(
            userInfo["level"] as? String ?? aps?["interruption-level"] as? String
        )
        let requestID = userInfo["requestId"] as? String
        let replacementID = userInfo["id"] as? String
        let payloadID = (userInfo["messageId"] as? String) ?? replacementID ?? identifier

        var stringUserInfo = notificationStringDictionary(userInfo)
        if let params = userInfo["params"] as? [String: Any] {
            for (key, value) in params {
                if let string = notificationString(value) {
                    stringUserInfo[key] = string
                }
            }
        }

        return MessagePayload(
            id: payloadID,
            title: userInfo["title"] as? String ?? content.title,
            body: userInfo["body"] as? String ?? content.body,
            markdown: markdown,
            subtitle: userInfo["subtitle"] as? String ?? content.subtitle,
            channel: userInfo["channel"] as? String ?? "apns",
            category: userInfo["category"] as? String,
            priority: messagePriority(for: level),
            sound: userInfo["sound"] as? String,
            badge: notificationInt(userInfo["badge"]) ?? content.badge?.intValue,
            group: userInfo["group"] as? String,
            threadId: (userInfo["threadId"] as? String)
                ?? (userInfo["thread-id"] as? String)
                ?? (aps?["thread-id"] as? String),
            targetURL: userInfo["url"] as? String,
            targetAppId: (userInfo["appId"] as? String) ?? (userInfo["appid"] as? String),
            route: userInfo["route"] as? String,
            targetMode: notificationTargetMode(userInfo),
            verificationCode: userInfo["verificationCode"] as? String,
            expiresAt: notificationExpiration(userInfo),
            imageURL: userInfo["image"] as? String,
            iconURL: userInfo["icon"] as? String,
            interruptionLevel: MessageInterruptionLevel(rawValue: level ?? ""),
            soundVolume: notificationDouble(userInfo["volume"]),
            isCall: notificationBool(userInfo["call"]),
            copyText: userInfo["copy"] as? String,
            isAutoCopy: notificationBool(userInfo["autoCopy"] ?? userInfo["automaticallyCopy"]),
            isArchive: notificationBool(userInfo["isArchive"]),
            ttl: notificationDouble(userInfo["ttl"]),
            replacementID: replacementID,
            isDeleted: notificationBool(userInfo["delete"]),
            actionState: MessageActionState(
                rawValue: ((userInfo["state"] as? String) ?? (userInfo["actionState"] as? String) ?? "").lowercased()
            ),
            requestID: requestID,
            contentType: MessageContentType(
                rawValue: ((userInfo["type"] as? String) ?? (userInfo["contentType"] as? String) ?? "").lowercased()
            ),
            qrPayload: userInfo["qrPayload"] as? String,
            statePath: userInfo["statePath"] as? String,
            revision: notificationInt(userInfo["revision"]),
            presentation: MessagePresentation(
                rawValue: (userInfo["presentation"] as? String ?? "").lowercased()
            ),
            approval: notificationApproval(userInfo["approval"]),
            userInfo: stringUserInfo
        )
    }

    private func notificationApproval(_ value: Any?) -> MessageApproval? {
        guard let object = value as? [String: Any],
              let rawActions = object["actions"] as? [[String: Any]] else { return nil }
        let actions = rawActions.compactMap { action -> MessageApprovalAction? in
            guard let id = action["id"] as? String,
                  let title = action["title"] as? String,
                  !id.isEmpty,
                  !title.isEmpty else { return nil }
            return MessageApprovalAction(
                id: id,
                title: title,
                style: MessageApprovalActionStyle(rawValue: action["style"] as? String ?? ""),
                requiresReason: notificationBool(action["requiresReason"]),
                resultState: MessageActionState(rawValue: action["resultState"] as? String ?? "")
            )
        }
        return actions.isEmpty ? nil : MessageApproval(actions: actions)
    }

    private func notificationStringDictionary(_ userInfo: [AnyHashable: Any]) -> [String: String] {
        userInfo.reduce(into: [:]) { result, item in
            guard let key = item.key as? String, let value = notificationString(item.value) else { return }
            result[key] = value
        }
    }

    private func notificationString(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            return value
        case let value as NSNumber:
            return value.stringValue
        default:
            return nil
        }
    }

    private func notificationInt(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }

    private func notificationDouble(_ value: Any?) -> Double? {
        switch value {
        case let value as Double:
            return value
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value)
        default:
            return nil
        }
    }

    private func notificationTargetMode(_ userInfo: [AnyHashable: Any]) -> String? {
        if let mode = userInfo["mode"] as? String { return mode }
        switch userInfo["display"] as? String {
        case "sheet", "inline": return "modal"
        case "full": return "immersive"
        default: return nil
        }
    }

    private func notificationLevel(_ value: String?) -> String? {
        switch value {
        case "time-sensitive", "timeSensitive": return "timeSensitive"
        case "passive", "active", "critical": return value
        default: return nil
        }
    }

    private func notificationBool(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        case let value as String:
            return value == "1" || value.lowercased() == "true"
        default:
            return nil
        }
    }

    private func notificationExpiration(_ userInfo: [AnyHashable: Any]) -> Date? {
        guard let rawValue = userInfo["expiresAt"] else { return nil }
        if let timestamp = rawValue as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        }
        if let timestamp = rawValue as? NSNumber {
            return Date(timeIntervalSince1970: timestamp.doubleValue)
        }
        if let value = rawValue as? String {
            return ISO8601DateFormatter().date(from: value)
        }
        return nil
    }

    private func messagePriority(for level: String?) -> MessagePriority {
        switch MessageInterruptionLevel(rawValue: level ?? "") {
        case .critical:
            return .critical
        case .timeSensitive:
            return .high
        case .passive:
            return .low
        default:
            return .normal
        }
    }

    // MARK: - DEBUG Helpers

    /// 注入测试URL到历史记录（仅DEBUG模式）
    private func injectTestURLsForDebugging() {
    }

    private static func cleanupInvalidHistoryURLs() {
        let key = "AppDelegate_DidCleanupAllData_v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        Task { @MainActor in
            let favoriteManager = URLFavoriteManager.shared
            let allFavorites = (try? await favoriteManager.getAllFavorites()) ?? []
            for fav in allFavorites {
                if let url = URL(string: fav.url) {
                    try? await favoriteManager.deleteFavorite(url: url)
                }
            }

            let historyManager = WebPageHistoryManager.shared
            try? await historyManager.clearAllHistory()

            let recommended = PresetURLCatalog.recommendedItems
            var seeded = 0
            for item in recommended {
                guard let url = URL(string: item.url) else { continue }
                if (try? await favoriteManager.findFavorite(url: url)) == nil {
                    _ = try? await favoriteManager.addFavorite(url: url, title: item.title)
                    seeded += 1
                }
            }
            WebBridgeLogger.shared.info("Data reset: cleared \(allFavorites.count) favs, seeded \(seeded) recommended")

            UserDefaults.standard.set(true, forKey: key)
        }
    }
}

// MARK: - DebugWindow

#if DEBUG
private class DebugWindow: UIWindow {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }

        let debugPanel = DebugPanelViewController()
        let nav = UINavigationController(rootViewController: debugPanel)
        nav.modalPresentationStyle = .fullScreen

        topViewController()?.present(nav, animated: true)
    }

    private func topViewController() -> UIViewController? {
        let root = rootViewController
        return getTopViewController(from: root)
    }

    private func getTopViewController(from vc: UIViewController?) -> UIViewController? {
        guard let vc = vc else { return nil }
        if let presented = vc.presentedViewController {
            return getTopViewController(from: presented)
        }
        if let nav = vc as? UINavigationController {
            return getTopViewController(from: nav.visibleViewController)
        }
        if let tab = vc as? UITabBarController {
            return getTopViewController(from: tab.selectedViewController)
        }
        return vc
    }
}
#else
private typealias DebugWindow = UIWindow
#endif
