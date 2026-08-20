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
        // Event-driven unread sync: every engine mutation (receive / read /
        // delete / clear) refreshes both the tab badge and the home-screen
        // icon badge. Replaces the old 2s polling timer, which stalls while
        // the inbox scroll view keeps the run loop in tracking mode.
        Task { [weak self] in
            await MessageEngine.shared.setOnStoreChanged { [weak self] in
                Task { await self?.syncUnreadBadges() }
            }
            await self?.syncUnreadBadges()
        }

        NotificationCenter.default.rx.notification(.didReceivePushMessage)
            .subscribe(onNext: { [weak self] notification in
                self?.handlePushJump(notification)
            })
            .disposed(by: disposeBag)
    }

    /// Unread count drives every badge surface: the notifications tab item
    /// and the app icon. Bark deliberately never tracks the icon badge (it
    /// only clears it with -1 on foreground); WebBridgeKit owns an inbox,
    /// so the icon badge mirrors the inbox unread count instead.
    private func syncUnreadBadges() async {
        let count = await MessageEngine.shared.getUnreadCount()
        await MainActor.run { [weak self] in
            guard let self = self,
                  let items = self.tabBar.items,
                  let messageIndex = AppTab.allCases.firstIndex(of: .notifications),
                  items.indices.contains(messageIndex) else { return }
            items[messageIndex].badgeValue = count > 0 ? "\(count)" : nil
        }
        await DefaultBadgeManager().setBadge(count)
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

        SettingsPreferenceKeys.migrateLegacyValuesIfNeeded()

        let isEnabled = UserDefaults.standard.bool(forKey: SettingsPreferenceKeys.rememberLastApp)

        if isEnabled,
           let lastURLString = UserDefaults.standard.string(forKey: SettingsPreferenceKeys.lastOpenedURL),
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
            let root: UIViewController
            switch tab {
            case .apps:
                root = PWAAppCenterViewController()
            case .notifications:
                root = createInboxViewController()
            case .settings:
                root = createSettingsViewController()
            }
            let nav = UINavigationController(rootViewController: root)
            // UINavigationController adopts its visible root item's title unless
            // the root owns the item, which would make the tab read "PWA 应用".
            root.tabBarItem = tab.makeTabBarItem()
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
        if tab == .settings {
            view = AnyView(
                SettingsView { [weak self] destination in
                    self?.handleSettingsNavigation(destination)
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
        hostingVC.view.accessibilityIdentifier = rootAccessibilityIdentifier(for: tab)
        hostingVC.tabBarItem = tab.makeTabBarItem()
        return hostingVC
    }

    private func rootAccessibilityIdentifier(for tab: AppTab) -> String {
        switch tab {
        case .apps:
            return "pwaCenter.table"
        case .notifications:
            return "InboxViewController"
        case .settings:
            return "SettingsViewController"
        }
    }

    #if DEBUG
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
    #endif

    #if DEBUG
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
    #endif

    #if DEBUG
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
    #endif

    #if DEBUG
    private func handleDebugCenterAction(_ action: DebugCenterAction) {
        guard let nav = selectedViewController as? UINavigationController else { return }

        switch action {
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
        case .openNetworkInspector:
            #if DEBUG
            nav.pushViewController(NetworkDebugViewController(), animated: true)
            #else
            showAppShellInfo(title: "Network", message: "Network inspector is available in DEBUG builds.")
            #endif
        case .openCacheDashboard:
            nav.pushViewController(
                CacheDashboardViewController(viewModel: CacheDashboardViewModel()),
                animated: true
            )
        case .openManifestCacheTests:
            #if DEBUG
            nav.pushViewController(ManifestCacheTestViewController(), animated: true)
            #else
            showAppShellInfo(title: "Manifest", message: "Manifest cache tests are available in DEBUG builds.")
            #endif
        case .openWebCache:
            #if DEBUG
            let vc = UIHostingController(rootView: WebCacheHomeView { [weak self] action in
                self?.handleWebCacheAction(action)
            })
            vc.title = "Web 缓存调试"
            nav.pushViewController(vc, animated: true)
            #endif
        case .showCrashScanGuide:
            showAppShellInfo(
                title: "崩溃扫描",
                message: "在项目根目录执行 bash scripts/scan-crash-logs.sh --json，要求 total 为 0。"
            )
        case .openBridgeLab:
            #if DEBUG
            let vc = UIHostingController(rootView: BridgeLabHomeView { [weak self] action in
                self?.handleBridgeLabAction(action)
            })
            vc.title = "Bridge 调试"
            nav.pushViewController(vc, animated: true)
            #endif
        case .openPushTools:
            #if DEBUG
            let vc = UIHostingController(rootView: TokenPushHomeView { [weak self] action in
                self?.handleTokenPushAction(action)
            })
            vc.title = "Push 调试"
            nav.pushViewController(vc, animated: true)
            #endif
        }
    }
    #endif

    #if DEBUG
    private func handleDeepLinkAction(_ action: DeepLinkAction) {
        guard let nav = selectedViewController as? UINavigationController else { return }

        switch action {
        case .openTarget(let url, let mode):
            WebBrowserManager.shared.openBrowser(
                url: url,
                params: WebBrowserParams(displayMode: mode),
                from: nav
            )
        case .openScheme(let url):
            UIApplication.shared.open(url)
        case .switchTab(let index):
            selectedIndex = max(0, min(index, AppTab.allCases.count - 1))
        }
    }
    #endif

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
        case .openMessageHistory:
            if let inboxIndex = AppTab.allCases.firstIndex(of: .notifications) {
                selectedIndex = inboxIndex
            }
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
            nav.pushViewController(GatewayConfigurationViewController(), animated: true)
        case .tokenManage:
            nav.pushViewController(TokenManageViewController(viewModel: TokenManageViewModel()), animated: true)
        case .apiKeyManage:
            nav.pushViewController(APIKeyManageViewController(viewModel: APIKeyManageViewModel()), animated: true)
        case .webGrants:
            let vc = UIHostingController(rootView: WebOriginGrantsView())
            nav.pushViewController(vc, animated: true)
        case .cacheManagement:
            nav.pushViewController(ManagementViewController(), animated: true)
        case .favorites:
            nav.pushViewController(FavoriteViewController(viewModel: FavoriteViewModel()), animated: true)
        case .history:
            let vc = UIHostingController(rootView: RecentAccessHistoryView())
            vc.title = "最近访问"
            nav.pushViewController(vc, animated: true)
        case .notificationSettings:
            NotificationSettingsOpener.open()
        case .pushEncryption:
            let vc = UIHostingController(rootView: PushEncryptionView())
            vc.title = "推送加密"
            nav.pushViewController(vc, animated: true)
        case .appearance:
            let vc = UIHostingController(rootView: AppearanceSettingsView())
            vc.title = L10n.tr("settings.appearance")
            nav.pushViewController(vc, animated: true)
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
        case .debugCenter:
            #if DEBUG
            let vc = UIHostingController(
                rootView: DebugCenterHomeView { [weak self] action in
                    self?.handleDebugCenterAction(action)
                }
            )
            vc.title = "Debug"
            nav.pushViewController(vc, animated: true)
            #else
            showAppShellInfo(title: "Debug", message: "Debug Center is available in DEBUG builds.")
            #endif
        case .deepLinks:
            #if DEBUG
            let vc = UIHostingController(
                rootView: DeepLinkHomeView { [weak self] action in
                    self?.handleDeepLinkAction(action)
                }
            )
            vc.title = "Links"
            nav.pushViewController(vc, animated: true)
            #else
            showAppShellInfo(title: "Links", message: "Deep Link tools are available in DEBUG builds.")
            #endif
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
