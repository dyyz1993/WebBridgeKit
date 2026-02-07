//
//  TabBarController.swift
//  DemoApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import WebBridgeKit

/// 主标签栏控制器
/// 管理 3 个主要功能模块：首页、收藏、设置
class TabBarController: UITabBarController {

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()

        // 设置初始页面
        // 默认进入首页
        self.selectedIndex = 0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkAndRestoreLastApp()
    }

    private func checkAndRestoreLastApp() {
        // 使用 static 变量确保只在 App 启动后的第一次显示时执行
        struct Static {
            static var hasChecked = false
        }
        
        if Static.hasChecked { return }
        Static.hasChecked = true
        
        let isEnabled = UserDefaults.standard.bool(forKey: "EnableLastAppMemory")
        
        if isEnabled,
           let lastURLString = UserDefaults.standard.string(forKey: "LastOpenedURL"),
           let url = URL(string: lastURLString) {
            
            print("🚀 [TabBar] Direct restoring last app: \(lastURLString)")
            
            // 获取首页的导航控制器
            if let mainNav = viewControllers?.first as? UINavigationController {
                // 使用 animated: false 实现“直接进入”效果
                WebBrowserManager.shared.openBrowserWithCache(
                    url: url,
                    params: WebBrowserParams(displayMode: .normal),
                    from: mainNav,
                    animated: false
                )
            }
        }
    }

    private func checkLastAppMemory() {
        // 功能已在 viewDidLoad 中被跳过，不再执行任何自动跳转
    }

    // MARK: - Setup

    private func setupTabs() {
        // 创建主要 Tab
        let mainVC = createMainViewController()
        let webAccessVC = createWebAccessViewController()
        let favoriteVC = createFavoriteViewController()
        let settingsVC = createSettingsViewController()
        let testVC = createTestCasesViewController()

        // 设置 Tab Bar Item
        mainVC.tabBarItem = UITabBarItem(
            title: "首页",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )

        webAccessVC.tabBarItem = UITabBarItem(
            title: "网页",
            image: UIImage(systemName: "safari"),
            selectedImage: UIImage(systemName: "safari.fill")
        )

        favoriteVC.tabBarItem = UITabBarItem(
            title: "收藏",
            image: UIImage(systemName: "star"),
            selectedImage: UIImage(systemName: "star.fill")
        )

        settingsVC.tabBarItem = UITabBarItem(
            title: "设置",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )

        testVC.tabBarItem = UITabBarItem(
            title: "测试",
            image: UIImage(systemName: "testtube.2"),
            selectedImage: UIImage(systemName: "testtube.2")
        )

        // 包装在 NavigationController 中
        let mainNav = UINavigationController(rootViewController: mainVC)
        let webAccessNav = UINavigationController(rootViewController: webAccessVC)
        let favoriteNav = UINavigationController(rootViewController: favoriteVC)
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        let testNav = UINavigationController(rootViewController: testVC)

        // 设置导航栏外观
        configureNavigationBar(mainNav.navigationBar)
        configureNavigationBar(webAccessNav.navigationBar)
        configureNavigationBar(favoriteNav.navigationBar)
        configureNavigationBar(settingsNav.navigationBar)
        configureNavigationBar(testNav.navigationBar)

        // 设置 View Controllers (包含测试 Tab)
        viewControllers = [mainNav, webAccessNav, testNav, favoriteNav, settingsNav]
    }

    private func setupAppearance() {
        // Tab Bar 外观
        tabBar.backgroundColor = UIColor.systemBackground
        tabBar.barTintColor = UIColor.systemBackground

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
    }

    private func configureNavigationBar(_ navigationBar: UINavigationBar) {
        navigationBar.prefersLargeTitles = true
        navigationBar.backgroundColor = UIColor.systemBackground

        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
        }
    }

    // MARK: - Create ViewControllers

    private func createMainViewController() -> UIViewController {
        return MainViewController(viewModel: MainViewModel())
    }

    private func createWebAccessViewController() -> UIViewController {
        return WebAccessViewController(viewModel: WebAccessViewModel())
    }

    private func createCacheManagementViewController() -> UIViewController {
        return CacheManagementViewController()
    }

    private func createTestCasesViewController() -> UIViewController {
        return ManifestTestCasesViewController()
    }

    private func createManifestCacheTestViewController() -> UIViewController {
        return ManifestCacheTestViewController()
    }

    private func createFavoriteViewController() -> UIViewController {
        return FavoriteViewController(viewModel: FavoriteViewModel())
    }

    private func createSettingsViewController() -> UIViewController {
        return SettingsViewController(viewModel: SettingsViewModel())
    }
}
