import SwiftUI
import UIKit
import WebBridgeKit

/// SwiftUI home presentation backed by the existing trusted-PWA runtime.
final class PWAAppCenterViewController: UIViewController {
    private let trustRegistry = HTMLAppTrustRegistry()
    private let permissionLedger = HTMLAppPermissionLedger.shared
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
        installHomeView()
        prepareOfficialPushIdentity()
        reloadApps()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        refreshPushState()
        reloadApps()
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

    private func installHomeView() {
        let rootView = PWAHomeView(
            viewModel: homeViewModel,
            onSendTest: { [weak self] title, body in self?.openPushExample(.plain, title: title, body: body) },
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
        let details = PWAAppDetailViewController(
            manifest: manifest,
            permissionLedger: permissionLedger,
            onOpen: { [weak self] in self?.launch(manifest) },
            onManageService: { [weak self] in self?.showGatewayManagement() }
        )
        navigationController?.pushViewController(details, animated: true)
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
        let view = PushExampleCatalogView { [weak self] type in
            self?.openPushExample(type)
        }
        navigationController?.pushViewController(UIHostingController(rootView: view), animated: true)
    }

    private func showGuideAndDebug() {
        let alert = UIAlertController(title: "手册与调试", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "PWA 接入手册", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(PWADeveloperGuideViewController(), animated: true)
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

    private func openPushExample(
        _ type: PushExampleType,
        title customTitle: String? = nil,
        body customBody: String? = nil
    ) {
        guard homeViewModel.isPushReady else {
            activateOfficialPush()
            return
        }

        let example = Self.examplePayload(for: type)
        guard let url = makeBarkURL(
            title: customTitle?.trimmedNonEmpty ?? example.title,
            body: customBody?.trimmedNonEmpty ?? example.body,
            queryItems: example.queryItems
        ) else {
            showMessage(title: "无法生成测试地址", message: "请检查推送服务地址是否有效。")
            return
        }
        #if DEBUG
        if Self.isOfficialPushUITest {
            homeViewModel.pushState = .ready
            return
        }
        #endif
        UIApplication.shared.open(url)
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

    private static func examplePayload(for type: PushExampleType) -> (
        title: String,
        body: String,
        queryItems: [URLQueryItem]
    ) {
        switch type {
        case .plain:
            return ("测试通知", "你好，这是一条来自 WebBridgeKit 的消息", [])
        case .markdown:
            return (
                "部署完成",
                "## 结果\n\n- 状态：成功\n- 环境：生产",
                [URLQueryItem(name: "contentType", value: "markdown"), URLQueryItem(name: "markdown", value: "1")]
            )
        case .otp:
            return (
                "登录验证码",
                "验证码 482901，5 分钟内有效",
                [
                    URLQueryItem(name: "contentType", value: "otp"),
                    URLQueryItem(name: "category", value: "otp"),
                    URLQueryItem(name: "verificationCode", value: "482901"),
                    URLQueryItem(name: "ttl", value: "300")
                ]
            )
        case .qr:
            return (
                "扫码登录",
                "使用 WebBridgeKit 扫描此二维码",
                [
                    URLQueryItem(name: "contentType", value: "qr"),
                    URLQueryItem(name: "qrPayload", value: "webbridgekit://login/example")
                ]
            )
        case .image:
            return (
                "图片预览",
                "查看远程图片及加载失败降级",
                [
                    URLQueryItem(name: "contentType", value: "image"),
                    URLQueryItem(name: "image", value: "https://example.com/preview.png")
                ]
            )
        case .chat:
            return (
                "Team Chat 新消息",
                "部署日志已经补充好了",
                [
                    URLQueryItem(name: "contentType", value: "chat"),
                    URLQueryItem(name: "category", value: "chat"),
                    URLQueryItem(name: "appId", value: "com.webbridgekit.fixture.chat"),
                    URLQueryItem(name: "route", value: "/conversations/release")
                ]
            )
        case .approval:
            return (
                "需要确认生产发布",
                "版本已经通过检查，等待你的决定",
                [
                    URLQueryItem(name: "contentType", value: "approval"),
                    URLQueryItem(name: "category", value: "approval"),
                    URLQueryItem(name: "requestId", value: "approval-browser-example"),
                    URLQueryItem(name: "actionState", value: "pending")
                ]
            )
        }
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
