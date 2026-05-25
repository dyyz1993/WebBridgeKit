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

        //  Clear cache on background to avoid blocking main thread (does NOT clear favorites/history)
        if !ProcessInfo.processInfo.arguments.contains("-UITesting") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                WebCacheManager.shared.clearAll()
            }
        }

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

        return true
    }

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

        // 将 Token 发送给服务器
        // APIKeyManager.shared.updateDeviceToken(token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
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

        Task {
            let payload = MessagePayload(
                title: userInfo["title"] as? String ?? response.notification.request.content.title,
                body: userInfo["body"] as? String ?? response.notification.request.content.body,
                channel: userInfo["channel"] as? String ?? "apns",
                targetURL: userInfo["url"] as? String,
                targetAppId: userInfo["appid"] as? String,
                targetMode: userInfo["mode"] as? String,
                userInfo: userInfo as? [String: String] ?? [:]
            )
            try? await MessageEngine.shared.receive(payload)
        }

        completionHandler()
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
