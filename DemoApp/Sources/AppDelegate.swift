//
//  AppDelegate.swift
//  DemoApp
//
//  Created on 2026-01-16.
//

import UIKit
import WebBridgeKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // 🔥 Clear all cache on startup as requested
        WebCacheManager.shared.clearAll()

        // 初始化 WebBridgeKit
        WebBridgeKit.shared.initialize()

        // 创建窗口
        window = UIWindow(frame: UIScreen.main.bounds)

        // 创建根视图控制器（使用 TabBar）
        let tabBarController = TabBarController()

        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        // 🔥 Support automated testing via launch arguments
        if ProcessInfo.processInfo.arguments.contains("-RunAllTests") {
            print("🧪 [AppDelegate] Automated testing triggered via launch argument")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let tabBarController = self.window?.rootViewController as? UITabBarController,
                   let nav = tabBarController.viewControllers?[2] as? UINavigationController,
                   let testVC = nav.viewControllers.first as? ManifestTestCasesViewController {
                    tabBarController.selectedIndex = 2
                    testVC.runAllTests()
                }
            }
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // 每次 App 进入前台时，尝试解析剪贴板口令
        TokenManager.shared.parseTokenFromClipboard()
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
                    
                    WebBrowserManager.shared.openBrowserWithCache(url: targetURL)
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
                   let nav = tabBarController.viewControllers?[2] as? UINavigationController,
                   let testVC = nav.viewControllers.first as? ManifestTestCasesViewController {
                    tabBarController.selectedIndex = 2
                    // Use performSelector to avoid direct dependency if needed, but here it's fine
                    testVC.runAllTests()
                    return true
                }
            }
        }
        
        return false
    }

    // MARK: - DEBUG Helpers

    /// 注入测试URL到历史记录（仅DEBUG模式）
    private func injectTestURLsForDebugging() {
    }
}
