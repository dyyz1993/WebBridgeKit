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
        viewControllers = AppTab.allCases.map { tab in
            let root = createAppShellViewController(tab: tab)
            let nav = UINavigationController(rootViewController: root)
            nav.tabBarItem = tab.makeTabBarItem()
            return nav
        }
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

    private func createAppShellViewController(tab: AppTab) -> UIViewController {
        let view: AnyView
        if tab == .web {
            view = AnyView(
                WebCacheHomeView { [weak self] action in
                    self?.handleWebCacheAction(action)
                }
            )
        } else if tab == .bridge {
            view = AnyView(
                BridgeLabHomeView { [weak self] action in
                    self?.handleBridgeLabAction(action)
                }
            )
        } else if tab == .tokenPush {
            view = AnyView(
                TokenPushHomeView { [weak self] action in
                    self?.handleTokenPushAction(action)
                }
            )
        } else {
            view = AnyView(
                AppShellView(tab: tab) { [weak self] action in
                    self?.handleAppShellAction(action)
                }
            )
        }
        let hostingVC = UIHostingController(rootView: view)
        hostingVC.title = tab.title
        hostingVC.tabBarItem = tab.makeTabBarItem()
        return hostingVC
    }

    private func handleWebCacheAction(_ action: WebCacheHomeAction) {
        guard let nav = selectedViewController as? UINavigationController else { return }

        switch action {
        case .openCacheDashboard:
            nav.pushViewController(
                CacheDashboardViewController(viewModel: CacheDashboardViewModel()),
                animated: true
            )
        case .openCacheManagement:
            nav.pushViewController(ManagementViewController(), animated: true)
        }
    }

    private func handleBridgeLabAction(_ action: BridgeLabAction) {
        guard let nav = selectedViewController as? UINavigationController else { return }

        switch action {
        case .openLegacyShowcase:
            #if DEBUG
            nav.pushViewController(BridgeShowcaseViewController(), animated: true)
            #else
            showAppShellInfo(title: "Bridge", message: "Bridge Showcase is available in DEBUG builds.")
            #endif
        case .openDebugLogs:
            #if DEBUG
            let debugPanel = DebugPanelViewController()
            let debugNav = UINavigationController(rootViewController: debugPanel)
            debugNav.modalPresentationStyle = .fullScreen
            nav.present(debugNav, animated: true)
            #else
            showAppShellInfo(title: "Debug", message: "Debug Panel is available in DEBUG builds.")
            #endif
        }
    }

    private func handleTokenPushAction(_ action: TokenPushAction) {
        guard let nav = selectedViewController as? UINavigationController else { return }

        switch action {
        case .openTokenManager:
            nav.pushViewController(TokenManageViewController(viewModel: TokenManageViewModel()), animated: true)
        case .openAPIKeyManager:
            nav.pushViewController(APIKeyManageViewController(viewModel: APIKeyManageViewModel()), animated: true)
        case .openNotificationDebug:
            #if DEBUG
            nav.pushViewController(NotificationDebugViewController(), animated: true)
            #else
            showAppShellInfo(title: "Push", message: "Notification Debug is available in DEBUG builds.")
            #endif
        }
    }

    private func handleAppShellAction(_ action: AppShellAction) {
        guard let nav = selectedViewController as? UINavigationController else { return }

        switch action {
        case .openWebCatalog:
            nav.pushViewController(
                PresetURLCatalogViewController(viewModel: PresetURLCatalogViewModel()),
                animated: true
            )
        case .openCacheDashboard:
            nav.pushViewController(
                CacheDashboardViewController(viewModel: CacheDashboardViewModel()),
                animated: true
            )
        case .openCacheManagement:
            nav.pushViewController(ManagementViewController(), animated: true)
        case .openBridgeShowcase:
            #if DEBUG
            nav.pushViewController(BridgeShowcaseViewController(), animated: true)
            #else
            showAppShellInfo(title: "Bridge", message: "Bridge Showcase is available in DEBUG builds.")
            #endif
        case .openTokenManager:
            nav.pushViewController(TokenManageViewController(viewModel: TokenManageViewModel()), animated: true)
        case .openAPIKeyManager:
            nav.pushViewController(APIKeyManageViewController(viewModel: APIKeyManageViewModel()), animated: true)
        case .openNotificationDebug:
            #if DEBUG
            nav.pushViewController(NotificationDebugViewController(), animated: true)
            #else
            showAppShellInfo(title: "Push", message: "Notification Debug is available in DEBUG builds.")
            #endif
        case .openDebugPanel:
            #if DEBUG
            let debugPanel = DebugPanelViewController()
            let debugNav = UINavigationController(rootViewController: debugPanel)
            debugNav.modalPresentationStyle = .fullScreen
            nav.present(debugNav, animated: true)
            #else
            showAppShellInfo(title: "Debug", message: "Debug Panel is available in DEBUG builds.")
            #endif
        case .openDiagnostics:
            #if DEBUG
            let vc = UIHostingController(rootView: DiagnosticsView())
            vc.title = L10n.tr("settings.diagnostics.title")
            nav.pushViewController(vc, animated: true)
            #else
            showAppShellInfo(title: "Diagnostics", message: "Diagnostics are available in DEBUG builds.")
            #endif
        case .openDeepLinkExamples:
            showDeepLinkExamples()
        case .openCommandExamples:
            showAppShellInfo(
                title: "UI v4",
                message: "This entry is reserved for the next module pass. The detailed implementation contract is in docs/ui-v4/SCREEN_SPECS.md."
            )
        }
    }

    private func showDeepLinkExamples() {
        showAppShellInfo(
            title: "协议跳转模板",
            message: """
            webbridgekit://open?url=https%3A%2F%2Fexample.com
            webbridgekit://tab?index=0
            webbridgekit://command/<token>
            """
        )
    }

    private func showAppShellInfo(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        selectedViewController?.present(alert, animated: true)
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
