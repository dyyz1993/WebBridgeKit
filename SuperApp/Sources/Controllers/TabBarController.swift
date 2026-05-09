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

class TabBarController: UITabBarController {

    private let disposeBag = DisposeBag()

    private let separatorView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
        setupSeparator()
        bindMessages()

        self.selectedIndex = 0
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        separatorView.frame = CGRect(
            x: 0,
            y: 0,
            width: tabBar.bounds.width,
            height: 0.5
        )
    }

    private func bindMessages() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, let items = self.tabBar.items, items.count > 1 else { return }
            let messageItem = items[1]
            Task {
                let count = await MessageEngine.shared.getUnreadCount()
                await MainActor.run {
                    messageItem.badgeValue = count > 0 ? "\(count)" : nil
                }
            }
        }

        NotificationCenter.default.rx.notification(.didReceivePushMessage)
            .subscribe(onNext: { [weak self] notification in
                self?.handlePushJump(notification)
            })
            .disposed(by: disposeBag)
    }

    private func handlePushJump(_ notification: Notification) {
        guard let url = notification.userInfo?["url"] as? URL else { return }

        let params = notification.userInfo?["params"] as? [String: String]

        self.selectedIndex = 0
        if let mainNav = viewControllers?.first as? UINavigationController {
            WebBrowserManager.shared.openBrowser(
                url: url,
                params: WebBrowserParams(
                    displayMode: .normal,
                    payload: params
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
        struct Static {
            static var hasChecked = false
        }

        if Static.hasChecked { return }
        Static.hasChecked = true

        let isEnabled = UserDefaults.standard.bool(forKey: "EnableLastAppMemory")

        if isEnabled,
           let lastURLString = UserDefaults.standard.string(forKey: "LastOpenedURL"),
           let url = URL(string: lastURLString) {

            if let mainNav = viewControllers?.first as? UINavigationController {
                WebBrowserManager.shared.openBrowser(
                    url: url,
                    params: WebBrowserParams(displayMode: .normal),
                    from: mainNav,
                    animated: false
                )
            }
        }
    }

    // MARK: - Setup

    private func setupTabs() {
        let mainVC = createMainViewController()
        let inboxVC = createInboxViewController()
        let discoverVC = createDiscoverViewController()
        let settingsVC = createSettingsViewController()

        mainVC.tabBarItem = UITabBarItem(
            title: L10n.tr("tab.home"),
            image: LucideIcon.home.templateImage(pointSize: 20),
            selectedImage: LucideIcon.home.templateImage(pointSize: 20)
        )

        inboxVC.tabBarItem = UITabBarItem(
            title: L10n.tr("tab.inbox"),
            image: LucideIcon.inbox.templateImage(pointSize: 20),
            selectedImage: LucideIcon.inbox.templateImage(pointSize: 20)
        )

        discoverVC.tabBarItem = UITabBarItem(
            title: L10n.tr("tab.discover"),
            image: LucideIcon.compass.templateImage(pointSize: 20),
            selectedImage: LucideIcon.compass.templateImage(pointSize: 20)
        )

        settingsVC.tabBarItem = UITabBarItem(
            title: L10n.tr("tab.settings"),
            image: LucideIcon.settings.templateImage(pointSize: 20),
            selectedImage: LucideIcon.settings.templateImage(pointSize: 20)
        )

        viewControllers = [
            UINavigationController(rootViewController: mainVC),
            UINavigationController(rootViewController: inboxVC),
            UINavigationController(rootViewController: discoverVC),
            UINavigationController(rootViewController: settingsVC)
        ]
    }

    private func setupAppearance() {
        tabBar.isTranslucent = true
        tabBar.unselectedItemTintColor = ThemeColors.current.textSecondary
        tabBar.tintColor = UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
            appearance.shadowColor = nil
            appearance.shadowImage = nil
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
    }

    private func setupSeparator() {
        separatorView.backgroundColor = ThemeColors.current.border
        separatorView.isUserInteractionEnabled = false
        tabBar.addSubview(separatorView)
    }

    // MARK: - Create ViewControllers

    private func createMainViewController() -> MainViewController {
        let viewModel = MainViewModel()
        return MainViewController(viewModel: viewModel)
    }

    private func createInboxViewController() -> InboxViewController {
        let viewModel = InboxViewModel()
        return InboxViewController(viewModel: viewModel)
    }

    private func createDiscoverViewController() -> DiscoverViewController {
        return DiscoverViewController()
    }

    private func createSettingsViewController() -> SettingsViewController {
        let viewModel = SettingsViewModel()
        return SettingsViewController(viewModel: viewModel)
    }
}
