//
//  WebBrowserManager.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import os.log

// Framework imports

/// 浏览器管理器 - 单例模式
/// 负责管理浏览器页面的打开、关闭和历史记录
public class WebBrowserManager {

    // MARK: - Singleton

    public static let shared = WebBrowserManager()

    private init() {}

    // MARK: - Navigation History

    /// 导航历史项
    public struct NavigationItem {
        public let url: URL
        public let title: String?
        public let timestamp: Date
        public let viewController: UIViewController
        public let displayMode: WebBrowserParams.DisplayMode
    }

    /// 导航栈
    private var navigationStack: [NavigationItem] = []

    /// 当前索引
    public private(set) var currentIndex: Int = 0

    /// 当前活动的浏览器实例（不包括弹窗）
    public private(set) var currentBrowser: UIViewController?

    /// 当前活动的弹窗实例
    public private(set) var currentModal: ModalWebViewController?

    // MARK: - Open Browser

    /// 打开浏览器（统一入口）
    /// - Parameters:
    ///   - url: 要加载的 URL
    ///   - params: 浏览器配置参数
    ///   - sourceViewController: 来源 ViewController（可选）
    public func openBrowser(
        url: URL,
        params: WebBrowserParams? = nil,
        from sourceViewController: UIViewController? = nil
    ) {
        os_log("=== WebBrowserManager.openBrowser ===", log: OSLog.default, type: .info)
        os_log("URL: %@", log: OSLog.default, type: .info, url.absoluteString)

        // Ensure all UI operations happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                os_log("❌ WebBrowserManager 已被释放", log: OSLog.default, type: .error)
                return
            }
            let effectiveParams = params ?? WebBrowserParams.from(url: url)
            os_log("DisplayMode: %ld", log: OSLog.default, type: .info, effectiveParams.displayMode.rawValue)

            switch effectiveParams.displayMode {
            case .modal:
                self.openModalBrowser(url: url, params: effectiveParams, from: sourceViewController)
            case .immersive:
                self.openImmersiveBrowser(url: url, params: effectiveParams, from: sourceViewController)
            case .normal:
                self.openNormalBrowser(url: url, params: effectiveParams, from: sourceViewController)
            }
        }
    }

    /// 从通知打开浏览器（供 AppDelegate 调用）
    public func openBrowser(from notification: Notification) {
        guard let pageName = notification.userInfo?["page"] as? String else {
            print("❌ [WebBrowserManager] BarkOpenWebPage notification missing page name")
            return
        }

        print("📱 [WebBrowserManager] Opening web page: \(pageName)")

        // 构建内部 URL
        var components = URLComponents(string: "webbridgekit://internal")
        components?.queryItems = [URLQueryItem(name: "page", value: pageName)]

        if let url = components?.url {
            openBrowser(url: url, from: getTopViewController())
        }
    }

    // MARK: - Private Open Methods

    private func openNormalBrowser(url: URL, params: WebBrowserParams, from sourceViewController: UIViewController?) {
        os_log("=== openNormalBrowser ===", log: OSLog.default, type: .info)

        guard let navController = getNavigationController(from: sourceViewController) else {
            os_log("❌ 找不到 NavigationController", log: OSLog.default, type: .error)
            print("❌ [WebBrowserManager] No navigation controller found")

            // 尝试获取顶层的 view controller
            if let topVC = getTopViewController() {
                os_log("顶层 VC: %@", log: OSLog.default, type: .info, String(describing: type(of: topVC)))
            }
            return
        }

        os_log("✅ 找到 NavigationController", log: OSLog.default, type: .info)
        let webVC = createWebViewController(for: url, params: params)
        addToNavigationStack(webVC, url: url, params: params)

        navController.pushViewController(webVC, animated: true)
        currentBrowser = webVC

        os_log("✅ 已推送浏览器到导航栈", log: OSLog.default, type: .info)
        print("✅ [WebBrowserManager] Pushed normal browser to navigation stack")
    }

    private func openImmersiveBrowser(url: URL, params: WebBrowserParams, from sourceViewController: UIViewController?) {
        guard let navController = getNavigationController(from: sourceViewController) else {
            print("❌ [WebBrowserManager] No navigation controller found")
            return
        }

        let webVC = createWebViewController(for: url, params: params)
        addToNavigationStack(webVC, url: url, params: params)

        navController.pushViewController(webVC, animated: true)
        currentBrowser = webVC

        print("✅ [WebBrowserManager] Pushed immersive browser to navigation stack")
    }

    private func openModalBrowser(url: URL, params: WebBrowserParams, from sourceViewController: UIViewController?) {
        guard let presentingVC = sourceViewController ?? getTopViewController() else {
            print("❌ [WebBrowserManager] No view controller to present modal")
            return
        }

        // 获取模态配置
        let config = params.toModalConfig()

        // 创建 ModalWebViewController
        let modalVC: ModalWebViewController
        if isLocalURL(url) {
            let pageName = getPageName(from: url)
            modalVC = ModalWebViewController(htmlName: pageName, config: config)
        } else {
            modalVC = ModalWebViewController(url: url, config: config)
        }

        modalVC.modalPresentationStyle = .overFullScreen
        modalVC.modalTransitionStyle = .crossDissolve

        currentModal = modalVC
        presentingVC.present(modalVC, animated: true)

        print("✅ [WebBrowserManager] Presented modal browser")
    }

    // MARK: - Close Browser

    /// 关闭当前浏览器
    /// - Parameters:
    ///   - animated: 是否使用动画
    ///   - reason: 关闭原因
    public func closeBrowser(animated: Bool = true, reason: WebBrowserParams.CloseReason = .userAction) {
        // Ensure all UI operations happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 如果有弹窗，先关闭弹窗
            if let modal = self.currentModal {
                self.dismissModal(modal, animated: animated)
                self.currentModal = nil
                return
            }

            // 关闭正常的浏览器页面
            guard let navController = self.getNavigationController(),
                  navController.viewControllers.count > 1 else {
                print("⚠️ [WebBrowserManager] Cannot close - only one page in stack")
                return
            }

            // 从导航栈弹出
            navController.popViewController(animated: animated)

            // 更新历史栈
            if self.currentIndex > 0 {
                self.currentIndex -= 1
            }

            // 从导航栈中移除
            if !self.navigationStack.isEmpty && self.currentIndex < self.navigationStack.count {
                self.navigationStack.remove(at: self.currentIndex)
            }

            self.currentBrowser = navController.topViewController

            print("✅ [WebBrowserManager] Closed browser, reason: \(reason)")
        }
    }

    private func dismissModal(_ modal: UIViewController, animated: Bool) {
        if let presented = modal.presentingViewController {
            presented.dismiss(animated: animated)
        }
    }

    // MARK: - History Management

    /// 获取导航历史
    public func getNavigationHistory() -> [NavigationItem] {
        return navigationStack
    }

    /// 后退
    /// - Parameter steps: 后退的步数
    /// - Returns: 是否成功
    @discardableResult
    public func goBack(steps: Int = 1) -> Bool {
        // 检查是否在主线程
        if Thread.isMainThread {
            return executeGoBack(steps: steps)
        } else {
            var result = false
            DispatchQueue.main.sync { [weak self] in
                result = self?.executeGoBack(steps: steps) ?? false
            }
            return result
        }
    }

    private func executeGoBack(steps: Int) -> Bool {
        guard let navController = getNavigationController() else {
            print("⚠️ [WebBrowserManager] Cannot go back - no navigation controller")
            return false
        }

        // 直接使用 UINavigationController 的 viewControllers 数量判断
        let canGoBack = navController.viewControllers.count > 1

        if canGoBack {
            for _ in 0..<steps {
                // 检查是否还能后退
                if navController.viewControllers.count > 1 {
                    navController.popViewController(animated: true)
                } else {
                    break
                }
            }
            currentBrowser = navController.topViewController

            // 更新内部索引（简化处理，直接设为当前数量-1）
            currentIndex = max(0, navController.viewControllers.count - 1)

            print("✅ [WebBrowserManager] Went back \(steps) steps")
            return true
        } else {
            print("⚠️ [WebBrowserManager] Cannot go back - at beginning of stack")
            return false
        }
    }

    /// 前进
    /// - Parameter steps: 前进的步数
    /// - Returns: 是否成功
    @discardableResult
    public func goForward(steps: Int = 1) -> Bool {
        // 检查是否在主线程
        if Thread.isMainThread {
            return executeGoForward(steps: steps)
        } else {
            var result = false
            DispatchQueue.main.sync { [weak self] in
                result = self?.executeGoForward(steps: steps) ?? false
            }
            return result
        }
    }

    private func executeGoForward(steps: Int) -> Bool {
        let targetIndex = currentIndex + steps

        guard targetIndex < navigationStack.count else {
            print("⚠️ [WebBrowserManager] Cannot go forward - at end of stack")
            return false
        }

        guard let navController = getNavigationController() else {
            print("⚠️ [WebBrowserManager] Cannot go forward - no navigation controller")
            return false
        }

        let item = navigationStack[targetIndex]
        navController.pushViewController(item.viewController, animated: true)
        currentIndex = targetIndex
        currentBrowser = item.viewController

        print("✅ [WebBrowserManager] Went forward \(steps) steps")
        return true
    }

    // MARK: - Current State

    /// 获取当前浏览器实例
    public func getCurrentBrowser() -> UIViewController? {
        return currentModal ?? currentBrowser
    }

    // MARK: - Helper Methods

    private func createWebViewController(for url: URL, params: WebBrowserParams) -> UIViewController {
        // 🔥 关键：必须在创建时就设置 hidesBottomBarWhenPushed（在 push 之前）
        // 使用 WebBrowserViewController 以支持页面自动缓存功能
        let webVC: WebBrowserViewController
        if isLocalURL(url) {
            // 对于本地URL，需要特殊处理
            let pageName = getPageName(from: url)
            webVC = WebBrowserViewController(url: url)  // 使用便捷初始化
            webVC.title = params.customTitle ?? pageName
        } else {
            webVC = WebBrowserViewController(url: url)  // 使用便捷初始化
            webVC.title = params.customTitle ?? url.host

            // 🔥 添加到历史记录追踪（只追踪外部URL）
            WebPageHistoryManager.shared.addOrUpdateHistory(url: url, title: webVC.title)
            print("📝 [WebBrowserManager] Added to history: \(url.absoluteString)")
        }

        // 🔥 必须在 push 之前设置 hidesBottomBarWhenPushed
        webVC.hidesBottomBarWhenPushed = params.hideTabBar

        return webVC
    }

    private func addToNavigationStack(_ viewController: UIViewController, url: URL, params: WebBrowserParams) {
        let item = NavigationItem(
            url: url,
            title: viewController.title,
            timestamp: Date(),
            viewController: viewController,
            displayMode: params.displayMode
        )

        // 如果当前不在栈顶，移除后面的项
        if currentIndex < navigationStack.count - 1 {
            navigationStack = Array(navigationStack.prefix(currentIndex + 1))
        }

        navigationStack.append(item)
        currentIndex = navigationStack.count - 1
    }

    private func isLocalURL(_ url: URL) -> Bool {
        return url.scheme == "bark" || url.pathExtension == "html"
    }

    private func getPageName(from url: URL) -> String {
        if url.scheme == "bark", let page = getValueFromQuery(url: url, key: "page") {
            return page
        }
        return url.deletingPathExtension().lastPathComponent
    }

    private func getValueFromQuery(url: URL, key: String) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.first(where: { $0.name == key })?.value
    }

    // MARK: - Navigation Controller Helpers

    private func getNavigationController(from sourceViewController: UIViewController? = nil) -> UINavigationController? {
        if let source = sourceViewController {
            return findNavigationController(from: source)
        }
        return findNavigationController(from: getTopViewController())
    }

    private func findNavigationController(from viewController: UIViewController?) -> UINavigationController? {
        guard let viewController = viewController else { return nil }

        // 🔥 修复：先向上查找 parent 链（这是关键的修复）
        var current: UIViewController? = viewController
        while let parent = current?.parent {
            if let navController = parent as? UINavigationController {
                os_log("✅ 通过 parent 找到 NavigationController", log: OSLog.default, type: .info)
                return navController
            }
            current = parent
        }

        // Direct navigation controller
        if let navController = viewController as? UINavigationController {
            return navController
        }

        // Tab bar controller - check selected view controller
        if let tabBarController = viewController as? UITabBarController,
           let selected = tabBarController.selectedViewController {
            return findNavigationController(from: selected)
        }

        // Split view controller - check detail view controller
        if #available(iOS 14.0, *),
           let splitViewController = viewController as? UISplitViewController {
            // For iPad, the detail view controller is usually what we want
            if let detail = splitViewController.viewControllers.last {
                return findNavigationController(from: detail)
            }
        }

        // Check presented view controller
        if let presented = viewController.presentedViewController {
            return findNavigationController(from: presented)
        }

        // Check child view controllers
        for child in viewController.children {
            if let nav = findNavigationController(from: child) {
                return nav
            }
        }

        os_log("❌ findNavigationController 未找到 NavigationController", log: OSLog.default, type: .error)
        return nil
    }

    private func getTopViewController() -> UIViewController? {
        // Get the first available window with rootViewController
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where window.rootViewController != nil {
                return findTopViewController(from: window.rootViewController!)
            }
        }
        return nil
    }

    private func findTopViewController(from viewController: UIViewController) -> UIViewController {
        var topController = viewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        return topController
    }
}

// MARK: - WebViewController Extensions
// Note: configure(with:) is now defined in WebViewController.swift

