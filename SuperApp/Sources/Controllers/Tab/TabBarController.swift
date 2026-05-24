//
//  TabBarController.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SwiftUI
import WebBridgeKit
import RxSwift
import RxCocoa

class TabBarController: UITabBarController {

    private let disposeBag = DisposeBag()

    private let separatorView = UIView()
    private var previousSelectedIndex: Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
        setupSeparator()
        bindMessages()
        delegate = self

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
        guard notification.userInfo?["url"] is URL else { return }
        self.selectedIndex = 0
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
            image: LucideIcon.home.templateImage(pointSize: ThemeTokens.Icons.Sizes.tab),
            selectedImage: LucideIcon.home.templateImage(pointSize: ThemeTokens.Icons.Sizes.tab)
        )
        mainVC.tabBarItem.accessibilityIdentifier = "tab.home"

        inboxVC.tabBarItem = UITabBarItem(
            title: L10n.tr("tab.inbox"),
            image: LucideIcon.inbox.templateImage(pointSize: ThemeTokens.Icons.Sizes.tab),
            selectedImage: LucideIcon.inbox.templateImage(pointSize: ThemeTokens.Icons.Sizes.tab)
        )
        inboxVC.tabBarItem.accessibilityIdentifier = "tab.inbox"

        discoverVC.tabBarItem = UITabBarItem(
            title: L10n.tr("tab.discover"),
            image: LucideIcon.compass.templateImage(pointSize: ThemeTokens.Icons.Sizes.tab),
            selectedImage: LucideIcon.compass.templateImage(pointSize: ThemeTokens.Icons.Sizes.tab)
        )
        discoverVC.tabBarItem.accessibilityIdentifier = "tab.discover"

        settingsVC.tabBarItem = UITabBarItem(
            title: L10n.tr("tab.settings"),
            image: LucideIcon.settings.templateImage(pointSize: ThemeTokens.Icons.Sizes.tab),
            selectedImage: LucideIcon.settings.templateImage(pointSize: ThemeTokens.Icons.Sizes.tab)
        )
        settingsVC.tabBarItem.accessibilityIdentifier = "tab.settings"

        viewControllers = [
            UINavigationController(rootViewController: mainVC),
            UINavigationController(rootViewController: inboxVC),
            UINavigationController(rootViewController: discoverVC),
            UINavigationController(rootViewController: settingsVC)
        ]
    }

    private func setupAppearance() {
        tabBar.isTranslucent = true
        tabBar.unselectedItemTintColor = ThemeTokens.Color.textSecondary
        tabBar.tintColor = ThemeTokens.Color.primary

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
        separatorView.backgroundColor = ThemeTokens.Color.border
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

    private func createSettingsViewController() -> UIViewController {
        let settingsView = SettingsView { [weak self] destination in
            self?.handleSettingsNavigation(destination)
        }
        let hostingVC = UIHostingController(rootView: settingsView)
        hostingVC.title = L10n.tr("tab.settings")
        return hostingVC
    }

    private func handleSettingsNavigation(_ destination: SettingsView.Destination) {
        guard let nav = selectedViewController as? UINavigationController else { return }

        switch destination {
        case .serverConfig:
            nav.pushViewController(ServerConfigViewController(viewModel: ServerConfigViewModel()), animated: true)
        case .tokenManage:
            nav.pushViewController(TokenManageViewController(viewModel: TokenManageViewModel()), animated: true)
        case .apiKeyManage:
            nav.pushViewController(APIKeyManageViewController(viewModel: APIKeyManageViewModel()), animated: true)
        case .cacheManagement:
            nav.pushViewController(ManagementViewController(), animated: true)
        case .favorites:
            nav.pushViewController(FavoriteViewController(viewModel: FavoriteViewModel()), animated: true)
        case .history:
            let vc = UIHostingController(rootView: RecentAccessHistoryView())
            vc.title = "最近访问"
            nav.pushViewController(vc, animated: true)
        case .notificationSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .appearance:
            break
        case .debugPanel:
            #if DEBUG
            let debugPanel = DebugPanelViewController()
            let debugNav = UINavigationController(rootViewController: debugPanel)
            debugNav.modalPresentationStyle = .fullScreen
            nav.present(debugNav, animated: true)
            #endif
        case .exportDiagnostics:
            #if DEBUG
            let vc = UIHostingController(rootView: DiagnosticsView())
            vc.title = L10n.tr("settings.diagnostics.title")
            nav.pushViewController(vc, animated: true)
            #endif
        case .cacheDashboard:
            nav.pushViewController(CacheDashboardViewController(viewModel: CacheDashboardViewModel()), animated: true)
        case .about:
            let vc = UIHostingController(rootView: AboutView())
            vc.title = L10n.tr("about.title")
            nav.pushViewController(vc, animated: true)
        }
    }
}

extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        UISelectionFeedbackGenerator().selectionChanged()

        guard let previousIndex = previousSelectedIndex,
              previousIndex != tabBarController.selectedIndex,
              let fromView = tabBarController.viewControllers?[previousIndex].view,
              let toView = viewController.view,
              fromView !== toView else {
            previousSelectedIndex = tabBarController.selectedIndex
            return
        }

        UIView.transition(
            from: fromView,
            to: toView,
            duration: ThemeTokens.Animation.normal.duration,
            options: .transitionCrossDissolve
        )

        previousSelectedIndex = tabBarController.selectedIndex
    }
}
