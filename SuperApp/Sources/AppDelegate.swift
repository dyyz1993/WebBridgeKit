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

        // 🔥 Clear all cache on startup as requested - Perform on background to avoid blocking main thread
        // For UI Testing, we skip this to avoid race conditions or main thread stalls during early launch
        if !ProcessInfo.processInfo.arguments.contains("-UITesting") {
            // 注意：WebCacheManager 内部已经处理了线程安全（WKWebView 在主线程，Realm 在后台线程）
            print("🗑️ [AppDelegate] Triggering global cache clearing...")
            WebCacheManager.shared.clearAll()
        } else {
            print("🧪 [AppDelegate] Skipping clearAll during UI testing")
        }

        // 初始化 WebBridgeKit
        // UI 测试时禁用 WebBridgeKit 预热，减少主线程压力和 WebKit 进程消耗
        if ProcessInfo.processInfo.arguments.contains("-UITesting") {
            print("🧪 [AppDelegate] UI Testing detected, disabling WebBridgeKit warmup")
            // 仅记录初始化，不调用池预热
            WebBridgeLogger.shared.info("WebBridgeKit initialized (warmup skipped for UI testing)")
        } else {
            WebBridgeKit.shared.initialize()
        }

        // Initialize all new engines
        Task {
            await EngineBootstrap.shared.initialize(in: self.window)
        }

        // 注册推送通知
        registerForPushNotifications(application)

        // 创建窗口（支持摇一摇触发调试面板）
        window = DebugWindow(frame: UIScreen.main.bounds)

        // 创建根视图控制器（使用 TabBar）
        let tabBarController = TabBarController()

        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        // 🔥 Support automated testing via launch arguments
        if ProcessInfo.processInfo.arguments.contains("-RunAllTests") {
            print("🧪 [AppDelegate] Automated testing triggered via launch argument")
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

        // 🔥 UI Testing shortcut: Auto-switch to test tab to avoid UI interactions
        if ProcessInfo.processInfo.arguments.contains("-UITesting") && !ProcessInfo.processInfo.arguments.contains("-NoAutoTab") {
            print("🧪 [AppDelegate] UI Testing detected, auto-switching to Test tab")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // 减少延迟，尽快切换
                if let tabBarController = self.window?.rootViewController as? UITabBarController {
                    tabBarController.selectedIndex = 1
                    print("✅ [AppDelegate] Switched to index 1")
                }
            }
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        if !ProcessInfo.processInfo.arguments.contains("-UITesting") {
            TokenManager.shared.parseTokenFromClipboard()
            CommandHandler.shared.checkClipboardOnForeground()
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        print("🔗 [AppDelegate] openURL called: \(url.absoluteString)")

        // 如果是 webbridgekit:// 协议，则在 App 内部打开
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
        // UI 测试时禁用推送注册，避免系统弹窗干扰
        if ProcessInfo.processInfo.arguments.contains("-UITesting") {
            print("🧪 [AppDelegate] Skipping push registration during UI testing")
            return
        }

        UNUserNotificationCenter.current().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, _ in
            print("🔔 [AppDelegate] Push authorization granted: \(granted)")
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("🔔 [AppDelegate] Device Token: \(token)")

        // 将 Token 发送给服务器
        // APIKeyManager.shared.updateDeviceToken(token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ [AppDelegate] Failed to register for remote notifications: \(error)")
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 在前台收到通知时，显示通知
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("🔔 [AppDelegate] Did receive notification response with userInfo: \(userInfo)")

        // 解析推送内容并转发到 MessageEngine
        Task {
            let payload = MessagePayload(
                title: userInfo["title"] as? String ?? response.notification.request.content.title,
                body: userInfo["body"] as? String ?? response.notification.request.content.body,
                channel: "apns",
                targetURL: userInfo["url"] as? String,
                targetAppId: userInfo["appid"] as? String,
                targetMode: userInfo["mode"] as? String,
                userInfo: userInfo as? [String: String]
            )
            try? await MessageEngine.shared.receive(payload)
        }

        completionHandler()
    }

    // MARK: - DEBUG Helpers

    /// 注入测试URL到历史记录（仅DEBUG模式）
    private func injectTestURLsForDebugging() {
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
