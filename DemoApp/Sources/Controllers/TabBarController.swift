//
//  TabBarController.swift
//  DemoApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit

/// 主标签栏控制器
/// 管理 3 个主要功能模块：首页、收藏、设置
class TabBarController: UITabBarController {

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
    }

    // MARK: - Setup

    private func setupTabs() {
        // 创建 3 个 Tab
        let mainVC = createMainViewController()
        let favoriteVC = createFavoriteViewController()
        let settingsVC = createSettingsViewController()

        // 设置 Tab Bar Item
        mainVC.tabBarItem = UITabBarItem(
            title: "首页",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
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

        // 包装在 NavigationController 中
        let mainNav = UINavigationController(rootViewController: mainVC)
        let favoriteNav = UINavigationController(rootViewController: favoriteVC)
        let settingsNav = UINavigationController(rootViewController: settingsVC)

        // 设置导航栏外观
        configureNavigationBar(mainNav.navigationBar)
        configureNavigationBar(favoriteNav.navigationBar)
        configureNavigationBar(settingsNav.navigationBar)

        // 设置 View Controllers
        viewControllers = [mainNav, favoriteNav, settingsNav]
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

    private func createFavoriteViewController() -> UIViewController {
        return FavoriteViewController(viewModel: FavoriteViewModel())
    }

    private func createSettingsViewController() -> UIViewController {
        return SettingsViewController(viewModel: SettingsViewModel())
    }
}
