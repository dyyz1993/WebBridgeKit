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
    private let defaultStartupLaunchResolver = HTMLAppLaunchResolver(
        trustRegistry: HTMLAppRuntimeCenter.shared.trustRegistry
    )

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
        openDefaultStartupAppIfNeeded()
    }

    /// Opens the selected trusted app once for a cold Drel launch. This is
    /// intentionally app-ID based, never a saved arbitrary web URL.
    private func openDefaultStartupAppIfNeeded() {
        #if DREL_RELEASE_MINIMAL_SETTINGS
        return
        #else
        struct Static {
            static var hasChecked = false
        }

        if Static.hasChecked { return }
        Static.hasChecked = true

        SettingsPreferenceKeys.removeLegacyLastURLPreferencesIfNeeded()

        guard let appID = UserDefaults.standard.string(forKey: SettingsPreferenceKeys.defaultStartupAppID),
              !appID.isEmpty,
              let manifest = HTMLAppRuntimeCenter.shared.trustRegistry.manifest(for: appID),
              let startURL = URL(string: manifest.startURL),
              let mainNav = viewControllers?.first as? UINavigationController else {
            return
        }

        do {
            let target = try defaultStartupLaunchResolver.resolve(
                appID: manifest.appID,
                route: startURL.path,
                source: .direct
            )
            var payload = target.context.bridgePayload
            payload["webbridgekitOfflineMode"] = target.offlineMode.rawValue
            payload["webbridgekitPageURL"] = target.pageURL.absoluteString
            let params = WebBrowserParams(
                displayMode: .immersive,
                hideNavigationBar: true,
                hideStatusBar: true,
                hideTabBar: true,
                payload: payload,
                useManifestLoader: false,
                preferCachedContent: target.offlineMode == .partial
            )
            WebBrowserManager.shared.openBrowser(
                url: target.loaderURL,
                params: params,
                from: mainNav,
                animated: false
            )
        } catch {
            // A removed or invalid manifest must never block Drel's regular home.
            UserDefaults.standard.removeObject(forKey: SettingsPreferenceKeys.defaultStartupAppID)
        }
        #endif
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
        // The product contract requires scroll content to remain visually clear
        // of the navigation surface. A transparent, glass tab bar made cards
        // and text appear beneath the selected tab on iOS 26.
        tabBar.isTranslucent = false
        tabBar.unselectedItemTintColor = ThemeTokens.Color.textSecondary
        tabBar.tintColor = ThemeTokens.Color.primary

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = ThemeTokens.Color.tabBarBackground
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

    #if !DREL_CONTAINER_ONLY
    private func handleWebCacheAction(_ action: WebCacheHomeAction) {
        guard let nav = selectedViewController as? UINavigationController else { return }

        switch action {
        case .openCacheDashboard:
            #if !DREL_RELEASE_MINIMAL_SETTINGS
            nav.pushViewController(
                CacheDashboardViewController(viewModel: CacheDashboardViewModel()),
                animated: true
            )
            #endif
        case .openCacheManagement:
            nav.pushViewController(ManagementViewController(), animated: true)
        }
    }
    #endif

    #if !DREL_CONTAINER_ONLY
    private func handleBridgeLabAction(_ action: BridgeLabAction) {
        guard let nav = selectedViewController as? UINavigationController else { return }

        switch action {
        case .openLegacyShowcase:
            #if !DREL_CONTAINER_ONLY
            nav.pushViewController(BridgeShowcaseViewController(), animated: true)
            #else
            showAppShellInfo(title: "Bridge", message: "Bridge Showcase is available in DEBUG builds.")
            #endif
        case .openDebugLogs:
            #if !DREL_CONTAINER_ONLY
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

    #if !DREL_CONTAINER_ONLY
    private func handleTokenPushAction(_ action: TokenPushAction) {
        guard let nav = selectedViewController as? UINavigationController else { return }

        switch action {
        case .openTokenManager:
            nav.pushViewController(TokenManageViewController(viewModel: TokenManageViewModel()), animated: true)
        case .openAPIKeyManager:
            #if !DREL_RELEASE_MINIMAL_SETTINGS
            nav.pushViewController(APIKeyManageViewController(viewModel: APIKeyManageViewModel()), animated: true)
            #endif
        case .openNotificationDebug:
            #if !DREL_CONTAINER_ONLY
            nav.pushViewController(NotificationDebugViewController(), animated: true)
            #else
            showAppShellInfo(title: "Push", message: "Notification Debug is available in DEBUG builds.")
            #endif
        }
    }
    #endif

    #if !DREL_CONTAINER_ONLY
    private func handleDebugCenterAction(_ action: DebugCenterAction) {
        guard let nav = selectedViewController as? UINavigationController else { return }

        switch action {
        case .openDebugPanel:
            #if !DREL_CONTAINER_ONLY
            let debugPanel = DebugPanelViewController()
            let debugNav = UINavigationController(rootViewController: debugPanel)
            debugNav.modalPresentationStyle = .fullScreen
            nav.present(debugNav, animated: true)
            #else
            showAppShellInfo(title: "Debug", message: "Debug Panel is available in DEBUG builds.")
            #endif
        case .openDiagnostics:
            #if !DREL_CONTAINER_ONLY
            let vc = UIHostingController(rootView: DiagnosticsView())
            vc.title = L10n.tr("settings.diagnostics.title")
            nav.pushViewController(vc, animated: true)
            #else
            showAppShellInfo(title: "Diagnostics", message: "Diagnostics are available in DEBUG builds.")
            #endif
        case .openNetworkInspector:
            #if !DREL_CONTAINER_ONLY
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
            #if !DREL_CONTAINER_ONLY
            nav.pushViewController(ManifestCacheTestViewController(), animated: true)
            #else
            showAppShellInfo(title: "Manifest", message: "Manifest cache tests are available in DEBUG builds.")
            #endif
        case .openWebCache:
            #if !DREL_CONTAINER_ONLY
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
            #if !DREL_CONTAINER_ONLY
            let vc = UIHostingController(rootView: BridgeLabHomeView { [weak self] action in
                self?.handleBridgeLabAction(action)
            })
            vc.title = "Bridge 调试"
            nav.pushViewController(vc, animated: true)
            #endif
        case .openPushTools:
            #if !DREL_CONTAINER_ONLY
            let vc = UIHostingController(rootView: TokenPushHomeView { [weak self] action in
                self?.handleTokenPushAction(action)
            })
            vc.title = "Push 调试"
            nav.pushViewController(vc, animated: true)
            #endif
        }
    }
    #endif

    #if !DREL_CONTAINER_ONLY
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
            #if !DREL_RELEASE_MINIMAL_SETTINGS
            nav.pushViewController(
                CacheDashboardViewController(viewModel: CacheDashboardViewModel()),
                animated: true
            )
            #endif
        case .openCacheManagement:
            nav.pushViewController(ManagementViewController(), animated: true)
        case .openBridgeShowcase:
            #if !DREL_CONTAINER_ONLY
            nav.pushViewController(BridgeShowcaseViewController(), animated: true)
            #else
            showAppShellInfo(title: "Bridge", message: "Bridge Showcase is available in DEBUG builds.")
            #endif
        case .openTokenManager:
            nav.pushViewController(TokenManageViewController(viewModel: TokenManageViewModel()), animated: true)
        case .openAPIKeyManager:
            #if !DREL_RELEASE_MINIMAL_SETTINGS
            nav.pushViewController(APIKeyManageViewController(viewModel: APIKeyManageViewModel()), animated: true)
            #endif
        case .openNotificationDebug:
            #if !DREL_CONTAINER_ONLY
            nav.pushViewController(NotificationDebugViewController(), animated: true)
            #else
            showAppShellInfo(title: "Push", message: "Notification Debug is available in DEBUG builds.")
            #endif
        case .openMessageHistory:
            if let inboxIndex = AppTab.allCases.firstIndex(of: .notifications) {
                selectedIndex = inboxIndex
            }
        case .openDebugPanel:
            #if !DREL_CONTAINER_ONLY
            let debugPanel = DebugPanelViewController()
            let debugNav = UINavigationController(rootViewController: debugPanel)
            debugNav.modalPresentationStyle = .fullScreen
            nav.present(debugNav, animated: true)
            #else
            showAppShellInfo(title: "Debug", message: "Debug Panel is available in DEBUG builds.")
            #endif
        case .openDiagnostics:
            #if !DREL_CONTAINER_ONLY
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
            let channelVC = DrelPushChannelConfigurationViewController()
            // 配置页全屏呈现：不带底部 tab，侧滑返回时 tab bar 自动恢复
            // （与 AboutViewController 的先例一致）。
            channelVC.hidesBottomBarWhenPushed = true
            nav.pushViewController(channelVC, animated: true)
        case .tokenManage:
            nav.pushViewController(TokenManageViewController(viewModel: TokenManageViewModel()), animated: true)
        case .apiKeyManage:
            #if !DREL_RELEASE_MINIMAL_SETTINGS
            nav.pushViewController(APIKeyManageViewController(viewModel: APIKeyManageViewModel()), animated: true)
            #endif
        case .webGrants:
            #if DREL_CONTAINER_ONLY
            showAppShellInfo(
                title: "网页授权管理",
                message: "Drel 的首个 Store 版本不向远程网页开放原生 Bridge 能力。"
            )
            #else
            let vc = UIHostingController(rootView: WebOriginGrantsView())
            nav.pushViewController(vc, animated: true)
            #endif
        case .cacheManagement:
            nav.pushViewController(ManagementViewController(), animated: true)
        case .favorites:
            #if !DREL_RELEASE_MINIMAL_SETTINGS
            nav.pushViewController(FavoriteViewController(viewModel: FavoriteViewModel()), animated: true)
            #endif
        case .history:
            #if !DREL_RELEASE_MINIMAL_SETTINGS
            let vc = UIHostingController(rootView: RecentAccessHistoryView())
            vc.title = "最近访问"
            nav.pushViewController(vc, animated: true)
            #endif
        case .notificationSettings:
            NotificationSettingsOpener.open()
        case .pushEncryption:
            #if !DREL_RELEASE_MINIMAL_SETTINGS
            let vc = UIHostingController(rootView: PushEncryptionView())
            vc.title = "推送加密"
            nav.pushViewController(vc, animated: true)
            #endif
        case .defaultStartupApp:
            #if !DREL_RELEASE_MINIMAL_SETTINGS
            let vc = UIHostingController(rootView: DefaultStartupAppView())
            vc.title = "默认启动应用"
            nav.pushViewController(vc, animated: true)
            #else
            showAppShellInfo(title: "Default startup", message: "Saved web-tool startup is planned for a later Drel release.")
            #endif
        case .appearance:
            let vc = UIHostingController(rootView: AppearanceSettingsView())
            vc.title = L10n.tr("settings.appearance")
            nav.pushViewController(vc, animated: true)
        case .debugPanel:
            #if !DREL_CONTAINER_ONLY
            let debugPanel = DebugPanelViewController()
            let debugNav = UINavigationController(rootViewController: debugPanel)
            debugNav.modalPresentationStyle = .fullScreen
            nav.present(debugNav, animated: true)
            #endif
        case .exportDiagnostics:
            #if !DREL_CONTAINER_ONLY
            let vc = UIHostingController(rootView: DiagnosticsView())
            vc.title = L10n.tr("settings.diagnostics.title")
            nav.pushViewController(vc, animated: true)
            #endif
        case .cacheDashboard:
            #if !DREL_RELEASE_MINIMAL_SETTINGS
            nav.pushViewController(CacheDashboardViewController(viewModel: CacheDashboardViewModel()), animated: true)
            #endif
        case .debugCenter:
            #if !DREL_CONTAINER_ONLY
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
            #if !DREL_CONTAINER_ONLY
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
