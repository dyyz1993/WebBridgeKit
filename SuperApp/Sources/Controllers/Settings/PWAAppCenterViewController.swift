import SwiftUI
import UIKit
import UserNotifications
import WebBridgeKit

/// SwiftUI home presentation backed by the existing trusted-PWA runtime.
final class PWAAppCenterViewController: UIViewController {
    // Single shared runtime so manifests, grants, and prompts stay in sync
    // with the permission center, browser container, and bridge handlers.
    private let runtime = HTMLAppRuntimeCenter.shared
    private var trustRegistry: HTMLAppTrustRegistry { runtime.trustRegistry }
    private var permissionLedger: HTMLAppPermissionLedger { runtime.permissionLedger }
    private let launchResolver = HTMLAppLaunchResolver()
    private let gatewayRegistry = HTMLAppGatewayRegistry()
    private lazy var onboardingService = HTMLAppGatewayOnboardingService(
        gatewayRegistry: gatewayRegistry,
        trustRegistry: trustRegistry,
        permissionLedger: permissionLedger
    )

    private lazy var homeViewModel = PWAHomeViewModel(
        pushURL: "",
        pushState: .identityPreparing
    )
    private var hostingController: UIHostingController<PWAHomeView>?
    private var manifests: [HTMLAppManifest] = []
    private var isBootstrappingOfficialGateway = false
    private var officialGatewayUnavailable = false
    private var officialPushIdentity: String?
    private let pushRegistrationFlag = "com.webbridgekit.officialPush.registered"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "首页"
        view.backgroundColor = ThemeTokens.Color.background
        syncRuntimeGatewayIdentity()
        installAppSettingsHandoff()
        installHomeView()
        prepareOfficialPushIdentity()
        reloadApps()
    }

    /// Container entry: the PWA browser menu's "应用设置" funnels into the same
    /// permission management page as the App Center detail entry.
    private func installAppSettingsHandoff() {
        WebBrowserManager.shared.appPermissionSettingsPresenter = { [weak self] host, manifest in
            guard let self else { return }
            let permissions = PWAPermissionCenterViewController(appID: manifest.appID)
            if let nav = host.navigationController {
                nav.pushViewController(permissions, animated: true)
            } else {
                self.present(UINavigationController(rootViewController: permissions), animated: true)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        syncRuntimeGatewayIdentity()
        refreshPushState()
        reloadApps()
        observeDidBecomeActive()
    }

    private func syncRuntimeGatewayIdentity() {
        if let active = gatewayRegistry.activeGateway() {
            runtime.gatewayIdentity = "\(active.id)#\(active.publicKeyID ?? "unsigned")"
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private var pushServerURL: String {
        ServerConfigManager.shared.getActiveBaseURL()
            ?? UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server")
            ?? "https://wbk.shanbox.19930810.xyz:8443"
    }

    private var pushURL: String {
        guard let officialPushIdentity, !officialPushIdentity.isEmpty else { return "" }
        let base = pushServerURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(base)/\(officialPushIdentity)"
    }

    /// Re-checks push permission when the app becomes active. Without this,
    /// returning from iOS Settings after enabling notifications doesn't fire
    /// `viewWillAppear` (the view was already visible under the Settings app),
    /// so the push card would keep showing "enable" forever.
    private func observeDidBecomeActive() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPushState()
        }
    }

    private func installHomeView() {
        let rootView = PWAHomeView(
            viewModel: homeViewModel,
            onSendTest: { [weak self] title, body in
                guard let plain = PushExample.example(id: "plain") else { return }
                self?.openPushExample(plain, title: title, body: body)
            },
            onCopyPushURL: { [weak self] in self?.copyPushURL() },
            onConfigurePush: { [weak self] in self?.activateOfficialPush() },
            onSelectApp: { [weak self] appID in self?.showAppDetails(appID: appID) },
            onManageApps: { [weak self] in self?.showGatewayManagement() },
            onOpenAPIExamples: { [weak self] in self?.showAPIExamples() },
            onOpenGuideAndDebug: { [weak self] in self?.showGuideAndDebug() }
        )
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.view.backgroundColor = ThemeTokens.Color.background
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }

    private func refreshPushState() {
        homeViewModel.pushURL = pushURL
        if officialPushIdentity == nil {
            prepareOfficialPushIdentity()
        }

        #if DEBUG
        if Self.isOfficialPushUITest { return }
        #endif

        // Re-query the real system authorization on every appear: the user
        // may have granted permission in iOS Settings after denying the
        // in-app prompt, and the cached flag would keep showing "enable"
        // forever without this refresh.
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self else { return }
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    if UserDefaults.standard.bool(forKey: self.pushRegistrationFlag) {
                        self.homeViewModel.pushState = .ready
                    } else {
                        // Permission now exists; complete the registration
                        // that the earlier denial blocked. Clear the stale
                        // .denied state FIRST, otherwise activateOfficialPush()
                        // re-opens Settings and traps the user in a loop.
                        self.homeViewModel.pushState = .registering
                        self.activateOfficialPush()
                    }
                case .denied:
                    self.homeViewModel.pushState = .denied
                default:
                    self.homeViewModel.pushState = .permissionRequired
                }
            }
        }
    }

    private func prepareOfficialPushIdentity() {
        homeViewModel.pushState = .identityPreparing
        do {
            #if DEBUG
            if Self.isOfficialPushUITest,
               let fixture = ProcessInfo.processInfo.environment["WBK_OFFICIAL_PUSH_TEST_IDENTITY"],
               !fixture.isEmpty {
                officialPushIdentity = fixture
            } else {
                officialPushIdentity = try OfficialPushIdentityStore.shared.currentOrCreate()
            }
            #else
            officialPushIdentity = try OfficialPushIdentityStore.shared.currentOrCreate()
            #endif
            homeViewModel.pushURL = pushURL
            #if DEBUG
            if Self.isOfficialPushUITest {
                homeViewModel.pushState = ProcessInfo.processInfo.environment["WBK_OFFICIAL_PUSH_TEST_STATE"] == "initial-ready"
                    ? .ready
                    : .permissionRequired
            } else {
                homeViewModel.pushState = UserDefaults.standard.bool(forKey: pushRegistrationFlag)
                    ? .ready
                    : .permissionRequired
            }
            #else
            homeViewModel.pushState = UserDefaults.standard.bool(forKey: pushRegistrationFlag)
                ? .ready
                : .permissionRequired
            #endif
        } catch {
            homeViewModel.pushState = .recoverableError(error.localizedDescription)
        }
    }

    private func activateOfficialPush() {
        if homeViewModel.pushState == .denied {
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsURL)
            return
        }
        guard let officialPushIdentity else {
            prepareOfficialPushIdentity()
            return
        }

        homeViewModel.pushState = .registering
        PushNotificationManager.shared.activateOfficialPush(
            serverURL: pushServerURL,
            key: officialPushIdentity
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .ready:
                UserDefaults.standard.set(true, forKey: self.pushRegistrationFlag)
                self.homeViewModel.pushState = .ready
            case .denied:
                self.homeViewModel.pushState = .denied
            case .failed(let message):
                self.homeViewModel.pushState = .recoverableError(message)
            }
        }
    }

    private func reloadApps() {
        manifests = trustRegistry.registeredManifests()
        updateHomeApps()

        guard manifests.isEmpty,
              gatewayRegistry.activeGateway() == nil,
              !isBootstrappingOfficialGateway,
              !officialGatewayUnavailable else { return }
        bootstrapOfficialGateway()
    }

    private func updateHomeApps() {
        homeViewModel.apps = manifests.map { manifest in
            PWAHomeViewModel.AppItem(
                id: manifest.appID,
                name: manifest.name,
                icon: appIcon(for: manifest),
                tint: appTint(for: manifest)
            )
        }
        if !manifests.isEmpty {
            homeViewModel.appState = .ready
        } else if officialGatewayUnavailable {
            homeViewModel.appState = .unavailable
        } else if isBootstrappingOfficialGateway {
            homeViewModel.appState = .loading
        } else {
            homeViewModel.appState = .ready
        }
    }

    private func bootstrapOfficialGateway() {
        isBootstrappingOfficialGateway = true
        homeViewModel.appState = .loading
        onboardingService.validate(HTMLAppGatewayDefaults.official) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBootstrappingOfficialGateway = false
                switch result {
                case .success(let report):
                    do {
                        try self.onboardingService.activate(report)
                        self.manifests = self.trustRegistry.registeredManifests()
                        self.officialGatewayUnavailable = false
                    } catch {
                        self.officialGatewayUnavailable = true
                    }
                case .failure:
                    self.officialGatewayUnavailable = true
                }
                self.updateHomeApps()
            }
        }
    }

    private func appIcon(for manifest: HTMLAppManifest) -> LucideIcon {
        let value = "\(manifest.appID) \(manifest.name)".lowercased()
        if value.contains("chat") { return .paperplane }
        if value.contains("agent") || value.contains("console") { return .terminal }
        if value.contains("approval") { return .clipboard }
        if value.contains("markdown") { return .docText }
        return .appFill
    }

    private func appTint(for manifest: HTMLAppManifest) -> UIColor {
        let value = manifest.appID.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) % 4
        }
        switch value {
        case 0: return ThemeTokens.Color.primary
        case 1: return ThemeTokens.Color.info
        case 2: return ThemeTokens.Color.warning
        default: return ThemeTokens.Color.accent
        }
    }

    private func showAppDetails(appID: String) {
        guard let manifest = manifests.first(where: { $0.appID == appID }) else { return }
        let grants = permissionLedger.grants(for: manifest.appID)
        let offline = manifest.cache.persistent ? "强离线包" : (manifest.cache.restoresLastState ? "缓存优先" : "在线")
        let message = """
        App ID：\(manifest.appID)
        离线策略：\(offline)（\(manifest.cache.version)）
        已声明能力：\(manifest.capabilities.map(\.rawValue).joined(separator: "、").ifEmpty("无"))
        已授予能力：\(grants.map { $0.capability.rawValue }.joined(separator: "、").ifEmpty("无"))

        推送只能定位到页面；权限和敏感操作仍需用户在应用内确认。
        """
        let alert = UIAlertController(title: manifest.name, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "打开应用", style: .default) { [weak self] _ in self?.launch(manifest) })
        alert.addAction(UIAlertAction(title: "权限与原生能力", style: .default) { [weak self] _ in
            guard let self else { return }
            self.navigationController?.pushViewController(
                PWAPermissionCenterViewController(appID: manifest.appID),
                animated: true
            )
        })
        alert.addAction(UIAlertAction(title: "管理应用服务", style: .default) { [weak self] _ in
            self?.showGatewayManagement()
        })
        alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
        // 仅 iPad（regular 宽度）需要 popover 锚点；iPhone 上无条件配置会把
        // actionSheet 变成居中窄浮卡（宽度异常、遮挡宫格）——用户实测报告。
        if let popover = alert.popoverPresentationController,
           traitCollection.horizontalSizeClass == .regular {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        present(alert, animated: true)
    }

    private func launch(_ manifest: HTMLAppManifest) {
        guard let startURL = URL(string: manifest.startURL) else { return }
        do {
            let target = try launchResolver.resolve(appID: manifest.appID, route: startURL.path)
            var payload = target.context.bridgePayload
            payload["webbridgekitOfflineMode"] = target.offlineMode.rawValue
            payload["webbridgekitPageURL"] = target.pageURL.absoluteString
            let params = WebBrowserParams(
                displayMode: .immersive,
                hideNavigationBar: true,
                hideStatusBar: true,
                hideTabBar: true,
                payload: payload,
                useManifestLoader: target.offlineMode == .strong,
                preferCachedContent: target.offlineMode == .partial
            )
            WebBrowserManager.shared.openBrowser(url: target.loaderURL, params: params, from: self)
        } catch {
            showMessage(title: "无法打开 PWA", message: error.localizedDescription)
        }
    }

    private func copyPushURL() {
        guard homeViewModel.isPushReady else { return }
        UIPasteboard.general.string = pushURL
        HUDService.shared.showSuccess(withStatus: "推送地址已复制")
    }

    private func showTokenManager() {
        navigationController?.pushViewController(
            TokenManageViewController(viewModel: TokenManageViewModel()),
            animated: true
        )
    }

    @objc private func showGatewayManagement() {
        navigationController?.pushViewController(GatewayConfigurationViewController(), animated: true)
    }

    private func showAPIExamples() {
        let view = PushExampleCatalogView(
            onTry: { [weak self] example in
                self?.openPushExample(example)
            },
            onCopy: { [weak self] example in
                self?.copyExampleURL(example)
            },
            onOpenSounds: { [weak self] in
                self?.showRingtonePicker()
            }
        )
        navigationController?.pushViewController(UIHostingController(rootView: view), animated: true)
    }

    private func showGuideAndDebug() {
        let alert = UIAlertController(title: "手册与调试", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "PWA 接入手册", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(PWADeveloperGuideViewController(), animated: true)
        })
        alert.addAction(UIAlertAction(title: "推送铃声", style: .default) { [weak self] _ in
            self?.showRingtonePicker()
        })
        alert.addAction(UIAlertAction(title: "推送加密", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(
                UIHostingController(rootView: PushEncryptionView()), animated: true
            )
        })
        alert.addAction(UIAlertAction(title: "分组静音", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(
                UIHostingController(rootView: GroupMuteView()), animated: true
            )
        })
        alert.addAction(UIAlertAction(title: "管理自有服务", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(GatewayConfigurationViewController(), animated: true)
        })
        #if DEBUG
        alert.addAction(UIAlertAction(title: "Push 调试工具", style: .default) { [weak self] _ in
            guard let self else { return }
            let view = TokenPushHomeView { [weak self] action in self?.handleTokenPushAction(action) }
            self.navigationController?.pushViewController(UIHostingController(rootView: view), animated: true)
        })
        #endif
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        present(alert, animated: true)
    }

    #if DEBUG
    private func handleTokenPushAction(_ action: TokenPushAction) {
        switch action {
        case .openTokenManager:
            showTokenManager()
        case .openAPIKeyManager:
            navigationController?.pushViewController(APIKeyManageViewController(viewModel: APIKeyManageViewModel()), animated: true)
        case .openNotificationDebug:
            #if DEBUG
            navigationController?.pushViewController(NotificationDebugViewController(), animated: true)
            #endif
        }
    }
    #endif

    private func openPushExample(
        _ example: PushExample,
        title customTitle: String? = nil,
        body customBody: String? = nil
    ) {
        openPushURL(
            title: customTitle?.trimmedNonEmpty ?? example.pushTitle,
            body: customBody?.trimmedNonEmpty ?? example.pushBody,
            queryItems: example.queryItems
        )
    }

    private func copyExampleURL(_ example: PushExample) {
        copyPushURL(title: example.pushTitle, body: example.pushBody, queryItems: example.queryItems)
    }

    // MARK: - Push URL actions

    private func openPushURL(title: String, body: String, queryItems: [URLQueryItem]) {
        guard homeViewModel.isPushReady else {
            activateOfficialPush()
            return
        }

        guard let url = makeBarkURL(title: title, body: body, queryItems: queryItems) else {
            showMessage(title: "无法生成测试地址", message: "请检查推送服务地址是否有效。")
            return
        }
        #if DEBUG
        if Self.isOfficialPushUITest {
            homeViewModel.pushState = .ready
            return
        }
        // UI tests send through the in-app browser so the app stays
        // foregrounded (willPresent records the message); manual use opens
        // mobile Safari, which is the documented Bark URL behavior users
        // expect from a "send" action.
        if ProcessInfo.processInfo.arguments.contains("--uitest-inapp-send") {
            WebBrowserManager.shared.openBrowser(url: url, params: WebBrowserParams(), from: self)
            return
        }
        #endif
        UIApplication.shared.open(url)
    }

    private func copyPushURL(title: String, body: String, queryItems: [URLQueryItem]) {
        guard homeViewModel.isPushReady else {
            activateOfficialPush()
            return
        }

        guard let url = makeBarkURL(title: title, body: body, queryItems: queryItems) else {
            showMessage(title: "无法生成测试地址", message: "请检查推送服务地址是否有效。")
            return
        }
        UIPasteboard.general.string = url.absoluteString
        HUDService.shared.showSuccess(withStatus: "推送 URL 已复制")
    }

    // MARK: - Ringtone picker

    private func showRingtonePicker() {
        let view = PushRingtoneView(
            onTry: { [weak self] sound in self?.tryRingtone(sound) },
            onCopy: { [weak self] sound in self?.copyRingtoneURL(sound) }
        )
        navigationController?.pushViewController(UIHostingController(rootView: view), animated: true)
    }

    private func tryRingtone(_ sound: String) {
        openPushURL(
            title: "铃声试听",
            body: "铃声 \(sound) 的推送示例",
            // iOS resolves push sound names against full filenames; the extensionless
        // Bark convention falls back to the default tone on this device.
        queryItems: [URLQueryItem(name: "sound", value: "\(sound).caf")]
        )
    }

    private func copyRingtoneURL(_ sound: String) {
        copyPushURL(
            title: "铃声试听",
            body: "铃声 \(sound) 的推送示例",
            // iOS resolves push sound names against full filenames; the extensionless
        // Bark convention falls back to the default tone on this device.
        queryItems: [URLQueryItem(name: "sound", value: "\(sound).caf")]
        )
    }

    private func makeBarkURL(title: String, body: String, queryItems: [URLQueryItem]) -> URL? {
        let base = pushServerURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let officialPushIdentity else { return nil }
        let path = [officialPushIdentity, title, body].compactMap(Self.encodePathSegment).joined(separator: "/")
        guard var components = URLComponents(string: "\(base)/\(path)") else { return nil }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }

    private static func encodePathSegment(_ value: String) -> String? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/%?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed)
    }

    private func showMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    #if DEBUG
    private static var isOfficialPushUITest: Bool {
        return ProcessInfo.processInfo.isWebBridgeKitUITesting
            && ProcessInfo.processInfo.environment["WBK_OFFICIAL_PUSH_TEST_STATE"] != nil
    }
    #endif
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func ifEmpty(_ replacement: String) -> String { isEmpty ? replacement : self }
}
