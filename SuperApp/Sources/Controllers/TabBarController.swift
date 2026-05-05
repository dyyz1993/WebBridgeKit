//
//  TabBarController.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import WebBridgeKit
import RxSwift
import RxCocoa

/// 主标签栏控制器
/// 管理 3 个主要功能模块：首页、收藏、设置
class TabBarController: UITabBarController {

    // MARK: - Lifecycle

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
        bindMessages()

        // 设置初始页面
        // 默认进入首页
        self.selectedIndex = 0
    }

    private func bindMessages() {
        // 监听未读消息数，动态更新 TabBar Badge
        MessageManager.shared.unreadCount
            .subscribe(onNext: { [weak self] count in
                guard let self = self, let items = self.tabBar.items, items.count > 1 else { return }
                let messageItem = items[1]
                messageItem.badgeValue = count > 0 ? "\(count)" : nil
            })
            .disposed(by: disposeBag)

        // 监听推送通知，处理全局跳转逻辑
        NotificationCenter.default.rx.notification(.didReceivePushMessage)
            .subscribe(onNext: { [weak self] notification in
                self?.handlePushJump(notification)
            })
            .disposed(by: disposeBag)
    }

    private func handlePushJump(_ notification: Notification) {
        guard let url = notification.userInfo?["url"] as? URL else { return }
        let message = notification.userInfo?["message"] as? WebhookMessage
        
        print("🚀 [TabBar] Handling push jump to: \(url.absoluteString)")
        
        // 切换到首页并打开浏览器
        self.selectedIndex = 0
        if let mainNav = viewControllers?.first as? UINavigationController {
            WebBrowserManager.shared.openBrowser(
                url: url,
                params: WebBrowserParams(
                    displayMode: .normal,
                    payload: message?.params
                ),
                from: mainNav
            )
        }
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
                // 使用 animated: false 实现"直接进入"效果
                WebBrowserManager.shared.openBrowser(
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
        let testCasesVC = createTestCasesViewController()
        let manageVC = createManagementViewController()
        let settingsVC = createSettingsViewController()

        // 设置 Tab Bar Item
        mainVC.tabBarItem = UITabBarItem(
            title: "首页",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )

        testCasesVC.tabBarItem = UITabBarItem(
            title: "用例",
            image: UIImage(systemName: "checklist"),
            selectedImage: UIImage(systemName: "checklist")
        )

        manageVC.tabBarItem = UITabBarItem(
            title: "管理",
            image: UIImage(systemName: "square.grid.2x2"),
            selectedImage: UIImage(systemName: "square.grid.2x2.fill")
        )

        settingsVC.tabBarItem = UITabBarItem(
            title: "设置",
            image: UIImage(systemName: "person"),
            selectedImage: UIImage(systemName: "person.fill")
        )

        // 包装导航控制器
        viewControllers = [
            UINavigationController(rootViewController: mainVC),
            UINavigationController(rootViewController: testCasesVC),
            UINavigationController(rootViewController: manageVC),
            UINavigationController(rootViewController: settingsVC)
        ]
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

    private func createMainViewController() -> MainViewController {
        let viewModel = MainViewModel()
        return MainViewController(viewModel: viewModel)
    }

    private func createTestCasesViewController() -> ManifestTestCasesViewController {
        return ManifestTestCasesViewController()
    }

    private func createManagementViewController() -> ManagementViewController {
        return ManagementViewController()
    }

    private func createSettingsViewController() -> SettingsViewController {
        let viewModel = SettingsViewModel()
        return SettingsViewController(viewModel: viewModel)
    }
}
