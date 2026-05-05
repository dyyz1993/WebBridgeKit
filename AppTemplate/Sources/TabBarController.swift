//
//  TabBarController.swift
//  AppTemplate
//
//  Created on 2025-05-05.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import WebBridgeKit

/// 主标签栏控制器
/// 管理 5 个功能模块：Web、Handlers、Logs、Diagnostics、Settings
class TabBarController: UITabBarController {

    #if DEBUG
    // Debug-related tabs
    private var debugTabs: [UITabBarItem] = []
    #endif

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()

        // 设置初始页面
        selectedIndex = 0
    }

    // MARK: - Setup

    private func setupTabs() {
        // 创建主要 Tab
        let webVC = createWebViewController()

        #if DEBUG
        let handlersVC = createHandlersViewController()
        let logsVC = createLogsViewController()
        let diagnosticsVC = createDiagnosticsViewController()
        let settingsVC = createSettingsViewController()

        // 设置 Tab Bar Item
        webVC.tabBarItem = UITabBarItem(
            title: "Web",
            image: UIImage(systemName: "globe"),
            selectedImage: UIImage(systemName: "globe.fill")
        )

        handlersVC.tabBarItem = UITabBarItem(
            title: "Handlers",
            image: UIImage(systemName: "square.grid.2x2"),
            selectedImage: UIImage(systemName: "square.grid.2x2.fill")
        )

        logsVC.tabBarItem = UITabBarItem(
            title: "Logs",
            image: UIImage(systemName: "doc.text"),
            selectedImage: UIImage(systemName: "doc.text.fill")
        )

        diagnosticsVC.tabBarItem = UITabBarItem(
            title: "Diagnostics",
            image: UIImage(systemName: "stethoscope"),
            selectedImage: UIImage(systemName: "stethoscope.fill")
        )

        settingsVC.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )

        // 保存 debug tabs
        debugTabs = [handlersVC.tabBarItem, logsVC.tabBarItem, diagnosticsVC.tabBarItem, settingsVC.tabBarItem]

        // 包装导航控制器 (5 tabs in DEBUG mode)
        viewControllers = [
            UINavigationController(rootViewController: webVC),
            UINavigationController(rootViewController: handlersVC),
            UINavigationController(rootViewController: logsVC),
            UINavigationController(rootViewController: diagnosticsVC),
            UINavigationController(rootViewController: settingsVC)
        ]
        #else
        // Release mode: only Web tab
        webVC.tabBarItem = UITabBarItem(
            title: "Web",
            image: UIImage(systemName: "globe"),
            selectedImage: UIImage(systemName: "globe.fill")
        )

        viewControllers = [
            UINavigationController(rootViewController: webVC)
        ]
        #endif
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

    private func createWebViewController() -> RootViewController {
        return RootViewController()
    }

    private func createHandlersViewController() -> DebugPanelViewController {
        return DebugPanelViewController()
    }

    private func createLogsViewController() -> LogViewerViewController {
        return LogViewerViewController()
    }

    private func createDiagnosticsViewController() -> DiagnosticViewController {
        return DiagnosticViewController()
    }

    private func createSettingsViewController() -> EnvironmentViewController {
        return EnvironmentViewController()
    }
}
