//
//  TabConfigurationManager.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-31.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Manifest Models

/// Tab Bar 配置模型
public struct TabBarConfiguration: Codable {
    public let items: [TabItem]
    public let style: TabBarStyle

    public struct TabItem: Codable {
        public let id: String
        public let page: String
        public let url: String?
        public let title: String
        public let icon: String
        public let iconSelected: String
        public let badge: Int?

        enum CodingKeys: String, CodingKey {
            case id, page, url, title, icon
            case iconSelected = "icon_selected"
            case badge
        }
    }

    public struct TabBarStyle: Codable {
        public let backgroundColor: String
        public let selectedColor: String
        public let unselectedColor: String
        public let borderColor: String
        public let borderWidth: Int
        public let height: Int
        public let fontSize: Int?
        public let iconSize: Int?
    }
}

/// 应用配置模型
public struct AppConfiguration: Codable {
    public let version: String
    public let app: AppInfo
    public let tabBar: TabBarConfiguration
    public let preload: [String]
    public let network: NetworkConfiguration?

    public struct AppInfo: Codable {
        public let name: String
        public let theme: String
        public let versionCode: Int?
    }

    public struct NetworkConfiguration: Codable {
        public let cacheEnabled: Bool
        public let cacheMaxAge: Int
        public let timeout: Int
    }
}

// MARK: - Tab Configuration Manager

/// Tab Bar 配置管理器
/// 负责从远程 URL 加载 manifest.json 并解析为原生 Tab Bar
public class TabConfigurationManager {

    // MARK: - Singleton

    public static let shared = TabConfigurationManager()

    private init() {}

    // MARK: - Properties

    /// 当前配置
    private var currentConfiguration: AppConfiguration?

    /// 图标缓存
    private var iconCache: [String: UIImage] = [:]

    /// 配置 URL
    private var manifestURL: URL?

    // MARK: - Public Methods

    /// 设置 manifest URL
    /// - Parameter url: manifest.json 的 URL
    public func setManifestURL(_ url: URL) {
        self.manifestURL = url
    }

    /// 加载配置
    /// - Parameter completion: 完成回调
    public func loadConfiguration(completion: @escaping (Result<AppConfiguration, Error>) -> Void) {
        guard let url = manifestURL else {
            completion(.failure(TabConfigError.noManifestURL))
            return
        }

        WebBridgeLogger.shared.log(.info, "[TabConfig] Loading manifest from: \(url.absoluteString)")

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                WebBridgeLogger.shared.log(.error, "[TabConfig] Failed to load: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(TabConfigError.noData))
                return
            }

            do {
                let config = try JSONDecoder().decode(AppConfiguration.self, from: data)
                self.currentConfiguration = config
                WebBridgeLogger.shared.log(.info, "[TabConfig] Loaded successfully: \(config.app.name)")
                completion(.success(config))
            } catch {
                WebBridgeLogger.shared.log(.error, "[TabConfig] Failed to decode: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }

        task.resume()
    }

    /// 预加载所有配置的页面
    /// - Parameter completion: 完成回调
    public func preloadPages(completion: @escaping (Int, Int) -> Void) {
        guard let config = currentConfiguration else {
            completion(0, 0)
            return
        }

        let pages = config.preload
        var successCount = 0

        WebBridgeLogger.shared.log(.info, "[TabConfig] Preloading \(pages.count) pages...")

        let group = DispatchGroup()

        for page in pages {
            group.enter()
            PageCacheManager.shared.preloadPage(named: page) { success in
                if success {
                    successCount += 1
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            WebBridgeLogger.shared.log(.info, "[TabConfig] Preloaded \(successCount)/\(pages.count) pages")
            completion(successCount, pages.count)
        }
    }

    /// 创建原生 Tab Bar Controller
    /// - Parameter completion: 完成回调
    public func createTabBarController(completion: @escaping (Result<UITabBarController, Error>) -> Void) {
        guard let config = currentConfiguration else {
            completion(.failure(TabConfigError.noConfiguration))
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion(.failure(TabConfigError.unknownError))
                return
            }

            let tabBarController = UITabBarController()
            var viewControllers: [UIViewController] = []

            // 创建每个 Tab
            for item in config.tabBar.items {
                let navController = self.createTabViewController(for: item, style: config.tabBar.style)
                viewControllers.append(navController)
            }

            tabBarController.viewControllers = viewControllers

            // 应用样式
            self.applyStyle(to: tabBarController, style: config.tabBar.style)

            WebBridgeLogger.shared.log(.info, "[TabConfig] Created TabBarController with \(viewControllers.count) tabs")
            completion(.success(tabBarController))
        }
    }

    // MARK: - Private Methods

    private func createTabViewController(for item: TabBarConfiguration.TabItem, style: TabBarConfiguration.TabBarStyle) -> UINavigationController {
        // 创建 WebView 容器
        let webVC = WebTabViewController(pageName: item.page, url: item.url)
        webVC.title = item.title
        webVC.tabBarItem = createTabBarItem(for: item, style: style)

        let navController = UINavigationController(rootViewController: webVC)
        return navController
    }

    private func createTabBarItem(for item: TabBarConfiguration.TabItem, style: TabBarConfiguration.TabBarStyle) -> UITabBarItem {
        let tabItem = UITabBarItem(title: item.title, image: nil, tag: 0)

        // 加载图标
        if let icon = loadIcon(from: item.icon) {
            tabItem.image = icon.withRenderingMode(.alwaysOriginal)
        }

        if let selectedIcon = loadIcon(from: item.iconSelected) {
            tabItem.selectedImage = selectedIcon.withRenderingMode(.alwaysOriginal)
        }

        // 设置角标
        if let badge = item.badge, badge > 0 {
            tabItem.badgeValue = "\(badge)"
        }

        return tabItem
    }

    private func loadIcon(from urlString: String) -> UIImage? {
        // 检查缓存
        if let cached = iconCache[urlString] {
            return cached
        }

        guard let url = URL(string: urlString) else { return nil }

        // 同步加载图标（实际应用中应该使用异步加载 + 占位图）
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            iconCache[urlString] = image
            return image
        }

        return nil
    }

    private func applyStyle(to tabBarController: UITabBarController, style: TabBarConfiguration.TabBarStyle) {
        let tabBar = tabBarController.tabBar

        // 背景色
        if let bgColor = UIColor(hex: style.backgroundColor) {
            tabBar.backgroundColor = bgColor
            tabBar.barTintColor = bgColor
        }

        // 选中颜色
        if let selectedColor = UIColor(hex: style.selectedColor) {
            tabBar.tintColor = selectedColor
        }

        // 未选中颜色
        if let unselectedColor = UIColor(hex: style.unselectedColor) {
            tabBar.unselectedItemTintColor = unselectedColor
        }

        // 边框
        if let borderColor = UIColor(hex: style.borderColor) {
            tabBar.layer.borderColor = borderColor.cgColor
            tabBar.layer.borderWidth = CGFloat(style.borderWidth)
        }

        // iOS 15+ 外观
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()

            if let bgColor = UIColor(hex: style.backgroundColor) {
                appearance.backgroundColor = bgColor
            }

            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - WebTabViewController

/// Tab 页面的 WebView 容器
/// 特点：当不可见时暂停 JS 执行，可见时恢复
private class WebTabViewController: WebBrowserViewController {

    private var pageName: String

    init(pageName: String, url: String?) {
        self.pageName = pageName

        // 从 URL 加载
        let loadURL: URL
        if let urlString = url, let url = URL(string: urlString) {
            loadURL = url
        } else {
            // 默认 URL - 使用页面名称
            guard let defaultURL = URL(string: "http://localhost:8080/\(pageName).html") else {
                fatalError("Failed to create default URL for page: \(pageName)")
            }
            loadURL = defaultURL
        }

        super.init(viewModel: WebBrowserViewModel(url: loadURL))
        WebBridgeLogger.shared.log(.info, "[WebTabVC] Created for: \(pageName)")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        WebBridgeLogger.shared.log(.info, "[WebTabVC] \(pageName) will appear - resuming")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        WebBridgeLogger.shared.log(.info, "[WebTabVC] \(pageName) did appear - active")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        WebBridgeLogger.shared.log(.info, "[WebTabVC] \(pageName) will disappear - pausing")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        WebBridgeLogger.shared.log(.info, "[WebTabVC] \(pageName) did disappear - inactive")

        // ⚠️ 关键：当 Tab 不可见时，WebView 会自动暂停
        // 不需要手动操作，iOS 会优化性能
    }
}

// MARK: - UIColor Extension

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - Errors

public enum TabConfigError: LocalizedError {
    case noManifestURL
    case noConfiguration
    case noData
    case unknownError

    public var errorDescription: String? {
        switch self {
        case .noManifestURL:
            return "Manifest URL not set"
        case .noConfiguration:
            return "No configuration loaded"
        case .noData:
            return "No data received"
        case .unknownError:
            return "Unknown error"
        }
    }
}
