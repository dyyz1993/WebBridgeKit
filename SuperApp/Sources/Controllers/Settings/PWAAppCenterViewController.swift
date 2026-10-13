import Foundation
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
    // Keep the resolver on the live shared registry. A resolver constructed
    // with its own registry snapshots UserDefaults before first-run gateway
    // onboarding and cannot see apps registered moments later.
    private lazy var launchResolver = HTMLAppLaunchResolver(trustRegistry: trustRegistry)
    private let offlinePackageLocator = HTMLAppOfflinePackageLocator()
    private let offlinePackageInstaller = HTMLAppOfflinePackageInstaller()
    private let presentationMetadataStore = HTMLAppPresentationMetadataStore()
    private let receivedAppStore = HTMLAppPushActivationStore()
    private let gatewayRegistry = HTMLAppGatewayRegistry()
    private lazy var onboardingService = HTMLAppGatewayOnboardingService(
        gatewayRegistry: gatewayRegistry,
        trustRegistry: trustRegistry,
        permissionLedger: permissionLedger,
        presentationMetadataStore: presentationMetadataStore
    )

    private lazy var homeViewModel = PWAHomeViewModel(
        pushURL: "",
        pushState: .identityPreparing
    )
    private var hostingController: UIHostingController<PWAHomeView>?
    private var manifests: [HTMLAppManifest] = []
    private var isBootstrappingOfficialGateway = false
    private var officialGatewayUnavailable = false
    private var lastGatewayFailureAt: Date?
    /// 网关校验失败后的重试冷却期；首页每次再现最多重试一次。
    private static let gatewayRetryCooldown: TimeInterval = 30
    private var officialPushIdentity: String?
    private let pushRegistrationFlag = "com.webbridgekit.officialPush.registered"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "首页"
        view.backgroundColor = ThemeTokens.Color.background
        #if !DREL_RELEASE_MINIMAL_SETTINGS
        syncRuntimeGatewayIdentity()
        installAppSettingsHandoff()
        #endif
        installHomeView()
        prepareOfficialPushIdentity()
        #if !DREL_RELEASE_MINIMAL_SETTINGS
        reloadApps()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshAppsAfterPushActivation),
            name: .htmlAppPushDidActivate,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPushState),
            name: DrelPushChannelStore.didChangeNotification,
            object: nil
        )
        #endif
    }

    @objc private func refreshAppsAfterPushActivation() {
        refreshVisibleApps()
        updateHomeApps()
    }

    /// Container entry: the PWA browser menu's "应用设置" funnels into the same
    /// permission management page as the App Center detail entry.
    private func installAppSettingsHandoff() {
        #if DREL_CONTAINER_ONLY
        WebBrowserManager.shared.appPermissionSettingsPresenter = nil
        #else
        WebBrowserManager.shared.appPermissionSettingsPresenter = { [weak self] host, manifest in
            guard let self else { return }
            let permissions = PWAPermissionCenterViewController(appID: manifest.appID)
            if let nav = host.navigationController {
                nav.pushViewController(permissions, animated: true)
            } else {
                self.present(UINavigationController(rootViewController: permissions), animated: true)
            }
        }
        #endif
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        #if !DREL_RELEASE_MINIMAL_SETTINGS
        syncRuntimeGatewayIdentity()
        #endif
        refreshPushState()
        #if !DREL_RELEASE_MINIMAL_SETTINGS
        reloadApps()
        #endif
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
        // Custom delivery is represented by its own persisted self-hosted
        // configuration. The official Drel address must never inherit a
        // legacy Bark/server preference.
        HTMLAppGatewayDefaults.official.baseURL
    }

    private var pushURL: String {
        let channel = DrelPushChannelStore.shared.activeChannel(officialPushURL: officialPushURL)
        if !channel.isOfficial {
            return channel.pushURL
        }
        return officialPushURL
    }

    private var officialPushURL: String {
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
            onManagePushAddress: { [weak self] in self?.showPushAddressManagement() },
            onConfigurePush: { [weak self] in self?.configureActivePushChannel() },
            onSelectPushChannel: { [weak self] channel in self?.selectPushChannel(channel) },
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

    @objc private func refreshPushState() {
        refreshPushChannels()
        homeViewModel.pushURL = pushURL
        if officialPushIdentity == nil {
            prepareOfficialPushIdentity()
        }

        if DrelPushChannelStore.shared.isActiveSelfHosted(officialPushURL: officialPushURL) {
            // A direct self-hosted configuration is persisted only after its
            // pairing and APNs registration succeed. It has an independent
            // registration lifecycle and must not request official setup.
            homeViewModel.pushState = .ready
            return
        }

        #if !DREL_CONTAINER_ONLY
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
            #if !DREL_CONTAINER_ONLY
            if Self.isOfficialPushUITest,
               let fixture = ProcessInfo.processInfo.environment["WBK_OFFICIAL_PUSH_TEST_IDENTITY"],
               !fixture.isEmpty {
                officialPushIdentity = fixture
            } else {
                officialPushIdentity = try OfficialPushIdentityStore.shared.currentOrMigrateToShortIdentity()
            }
            #else
            officialPushIdentity = try OfficialPushIdentityStore.shared.currentOrMigrateToShortIdentity()
            #endif
            refreshPushChannels()
            homeViewModel.pushURL = pushURL
            #if !DREL_CONTAINER_ONLY
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

    private func refreshPushChannels() {
        let channels = DrelPushChannelStore.shared.channels(officialPushURL: officialPushURL)
        homeViewModel.pushChannels = channels
        homeViewModel.activePushChannelID = DrelPushChannelStore.shared
            .activeChannel(officialPushURL: officialPushURL).id
    }

    private func selectPushChannel(_ channel: DrelPushChannel) {
        DrelPushChannelStore.shared.select(channel)
        refreshPushState()
    }

    private func configureActivePushChannel() {
        if DrelPushChannelStore.shared.isActiveSelfHosted(officialPushURL: officialPushURL) {
            navigationController?.pushViewController(SelfHostedPushConfigurationViewController(), animated: true)
        } else {
            activateOfficialPush()
        }
    }

    private func reloadApps() {
        refreshVisibleApps()
        updateHomeApps()

        // Keep the verified catalog current for push-route validation, but do
        // not render it directly. An app becomes visible only after a trusted
        // push has targeted it and recorded a user-local activation.
        let gateway = gatewayRegistry.activeGateway() ?? HTMLAppGatewayDefaults.official
        // 一次瞬时失败不应永久钉死在「不可用」：冷却期后允许在首页再现时重试。
        if officialGatewayUnavailable,
           let last = lastGatewayFailureAt,
           Date().timeIntervalSince(last) < Self.gatewayRetryCooldown {
            return
        }
        guard !isBootstrappingOfficialGateway else { return }
        bootstrapGateway(gateway)
    }

    private func refreshVisibleApps() {
        manifests = trustRegistry.registeredManifests().filter {
            receivedAppStore.contains($0.appID)
        }
    }

    private func updateHomeApps() {
        homeViewModel.apps = manifests.map { manifest in
            let metadata = presentationMetadataStore.metadata(for: manifest.appID)
            let displayName = metadata?.name ?? manifest.name
            return PWAHomeViewModel.AppItem(
                id: manifest.appID,
                name: displayName,
                iconURL: metadata?.iconURLs.last,
                iconCacheKey: "\(manifest.appID)|\(manifest.webManifest?.sha256 ?? "no-web-manifest")",
                fallbackInitial: appInitial(name: displayName, appID: manifest.appID),
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

    private func bootstrapGateway(_ gateway: HTMLAppGatewayConfiguration) {
        isBootstrappingOfficialGateway = true
        homeViewModel.appState = .loading
        onboardingService.validate(gateway) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBootstrappingOfficialGateway = false
                switch result {
                case .success(let report):
                    do {
                        try self.onboardingService.activate(report)
                        self.refreshVisibleApps()
                        self.officialGatewayUnavailable = false
                        self.lastGatewayFailureAt = nil
                    } catch {
                        self.officialGatewayUnavailable = true
                        self.lastGatewayFailureAt = Date()
                    }
                case .failure:
                    self.officialGatewayUnavailable = true
                    self.lastGatewayFailureAt = Date()
                }
                self.updateHomeApps()
            }
        }
    }

    private func appInitial(name: String, appID: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmedName.first { return String(first).uppercased() }
        let appComponent = appID.split(separator: ".").last.map(String.init) ?? appID
        if let first = appComponent.first { return String(first).uppercased() }
        return "D"
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
        let offline = offlinePackageSummary(for: manifest)
        #if DREL_CONTAINER_ONLY
        let message = """
        App ID：\(manifest.appID)
        离线策略：\(offline)

        此版本以安全网页容器运行。推送可定位到页面，但远程页面不能调用原生 Bridge 能力。
        """
        #else
        let grants = permissionLedger.grants(for: manifest.appID)
        let message = """
        App ID：\(manifest.appID)
        离线策略：\(offline)
        已声明能力：\(manifest.capabilities.map(\.rawValue).joined(separator: "、").ifEmpty("无"))
        已授予能力：\(grants.map { $0.capability.rawValue }.joined(separator: "、").ifEmpty("无"))

        推送只能定位到页面；权限和敏感操作仍需用户在应用内确认。
        """
        #endif
        let alert = UIAlertController(title: manifest.name, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "打开应用", style: .default) { [weak self] _ in self?.launch(manifest) })
        if manifest.effectiveOfflineCache.isStrongOfflineEligible {
            let hasCurrentPackage = hasCurrentOfflinePackage(for: manifest)
            alert.addAction(UIAlertAction(
                title: hasCurrentPackage ? "更新离线包" : "下载离线包",
                style: .default
            ) { [weak self] _ in
                self?.prepareOfflinePackage(manifest)
            })
            if hasCurrentPackage {
                alert.addAction(UIAlertAction(title: "删除离线包", style: .destructive) { [weak self] _ in
                    self?.confirmOfflinePackageRemoval(for: manifest)
                })
            }
        }
        let defaultStartupAppID = UserDefaults.standard.string(forKey: SettingsPreferenceKeys.defaultStartupAppID)
        if defaultStartupAppID == manifest.appID {
            alert.addAction(UIAlertAction(title: "取消默认启动应用", style: .default) { _ in
                UserDefaults.standard.removeObject(forKey: SettingsPreferenceKeys.defaultStartupAppID)
            })
        } else {
            alert.addAction(UIAlertAction(title: "设为默认启动应用", style: .default) { _ in
                UserDefaults.standard.set(manifest.appID, forKey: SettingsPreferenceKeys.defaultStartupAppID)
            })
        }
        #if !DREL_CONTAINER_ONLY
        alert.addAction(UIAlertAction(title: "权限与原生能力", style: .default) { [weak self] _ in
            guard let self else { return }
            self.navigationController?.pushViewController(
                PWAPermissionCenterViewController(appID: manifest.appID),
                animated: true
            )
        })
        #endif
        #if !DREL_CONTAINER_ONLY
        alert.addAction(UIAlertAction(title: "管理应用服务", style: .default) { [weak self] _ in
            self?.showGatewayManagement()
        })
        #endif
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
        // Launch does not implicitly install or update code. A user may open
        // the network version at any time, while installing/updating an
        // offline package remains the distinct, explicit action in details.
        launchResolved(manifest)
    }

    private func prepareOfflinePackage(_ manifest: HTMLAppManifest) {
        HUDService.shared.show("正在验证并准备离线包…")
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.offlinePackageInstaller.install(appManifest: manifest)
                // 包更新后重解析绑定的 Web App Manifest，刷新名称/主题/图标元数据，
                // 否则首页磁贴会一直显示旧图标（离线包 v2→v3 实测发现的缺陷）。
                let resolved = try await HTMLAppWebManifestAdapter().load(forTrustedParent: manifest)
                try presentationMetadataStore.set(resolved, for: manifest.appID)
                updateHomeApps()
                HUDService.shared.showSuccess(withStatus: "离线包已准备完成")
            } catch {
                // The installer only switches the current pointer after every
                // resource is verified. On failure resolve again so a stale or
                // partial package can never be presented as strong offline.
                HUDService.shared.showInfo(withStatus: "离线包暂不可用，已改为联网打开")
            }
        }
    }

    private func confirmOfflinePackageRemoval(for manifest: HTMLAppManifest) {
        let alert = UIAlertController(
            title: "删除离线包？",
            message: "这会移除 \(manifest.name) 已下载的网页资源，之后仍可联网打开并再次下载。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.removeOfflinePackage(for: manifest)
        })
        present(alert, animated: true)
    }

    private func removeOfflinePackage(for manifest: HTMLAppManifest) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let removed = try await self.offlinePackageInstaller.removeInstalledPackage(appID: manifest.appID)
                HUDService.shared.showSuccess(withStatus: removed ? "离线包已删除" : "没有可删除的离线包")
            } catch {
                self.showMessage(title: "无法删除离线包", message: error.localizedDescription)
            }
        }
    }

    private func launchResolved(_ manifest: HTMLAppManifest) {
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
                useManifestLoader: false,
                preferCachedContent: target.offlineMode == .partial
            )
            WebBrowserManager.shared.openBrowser(url: target.loaderURL, params: params, from: self)
        } catch {
            showMessage(title: "无法打开 PWA", message: error.localizedDescription)
        }
    }

    private func hasCurrentOfflinePackage(for manifest: HTMLAppManifest) -> Bool {
        guard let package = try? offlinePackageLocator.installedPackage(appID: manifest.appID) else {
            return false
        }
        let cache = manifest.effectiveOfflineCache
        return package.version == cache.version
            && package.resourceManifestSHA256 == cache.resourceManifestSHA256
            && (try? offlinePackageLocator.entrypointURL(for: package)) != nil
    }

    private func offlinePackageSummary(for manifest: HTMLAppManifest) -> String {
        let cache = manifest.effectiveOfflineCache
        guard cache.isStrongOfflineEligible else {
            return cache.restoresLastState ? "缓存优先（\(cache.version)）" : "在线"
        }

        guard let package = try? offlinePackageLocator.installedPackage(appID: manifest.appID) else {
            return "强离线包待准备（可下载后离线打开，\(cache.version)）"
        }
        guard hasCurrentOfflinePackage(for: manifest) else {
            return "强离线包待更新（当前 \(package.version) → \(cache.version)）"
        }
        let size = (try? offlinePackageLocator.packageSize(for: package)) ?? 0
        return "强离线包已安装（\(cache.version)，\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))）"
    }

    private func copyPushURL() {
        guard !pushURL.isEmpty else { return }
        UIPasteboard.general.string = pushURL
        let status = homeViewModel.isPushReady
            ? "推送地址已复制"
            : L10n.tr("official.push.address.copied_before_enable")
        HUDService.shared.showSuccess(withStatus: status)
    }

    private func showPushAddressManagement() {
        if DrelPushChannelStore.shared.isActiveSelfHosted(officialPushURL: officialPushURL) {
            navigationController?.pushViewController(SelfHostedPushConfigurationViewController(), animated: true)
            return
        }
        guard let officialPushIdentity, !officialPushIdentity.isEmpty else {
            // An absent identity previously failed silently here; a tap with
            // zero feedback reads as a dead button on fresh installs.
            HUDService.shared.showInfo(withStatus: "推送身份尚未生成，请先启用通知完成授权")
            return
        }
        let sheet = UIAlertController(
            title: "推送地址管理",
            message: "推送标识是公开地址的一部分，不是登录密码。",
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: "复制完整地址", style: .default) { [weak self] _ in
            self?.copyPushURL()
        })
        sheet.addAction(UIAlertAction(title: "复制推送标识", style: .default) { _ in
            UIPasteboard.general.string = officialPushIdentity
            HUDService.shared.showSuccess(withStatus: "推送标识已复制")
        })
        sheet.addAction(UIAlertAction(title: "重新生成推送地址", style: .destructive) { [weak self] _ in
            self?.confirmPushAddressRotation()
        })
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = sheet.popoverPresentationController,
           traitCollection.horizontalSizeClass == .regular {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        present(sheet, animated: true)
    }

    private func confirmPushAddressRotation() {
        let alert = UIAlertController(
            title: "重新生成推送地址？",
            message: "旧地址将停止向这台设备推送。请同步更新你的脚本、服务和网页。此操作无法撤销。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重新生成", style: .destructive) { [weak self] _ in
            self?.rotatePushAddress()
        })
        present(alert, animated: true)
    }

    private func rotatePushAddress() {
        guard let oldIdentity = officialPushIdentity else { return }
        homeViewModel.pushState = .registering

        let replaceLocalIdentity = { [weak self] in
            guard let self else { return }
            do {
                let successor = try OfficialPushIdentityStore.shared.reset()
                self.officialPushIdentity = successor
                UserDefaults.standard.set(false, forKey: self.pushRegistrationFlag)
                self.homeViewModel.pushURL = self.pushURL
                self.activateOfficialPush()
            } catch {
                self.homeViewModel.pushState = .recoverableError(error.localizedDescription)
            }
        }

        // Before notification permission/APNs registration there is no server
        // registration to revoke; rotating the local public identity is safe.
        guard UserDefaults.standard.bool(forKey: pushRegistrationFlag) else {
            replaceLocalIdentity()
            return
        }

        PushNotificationManager.shared.revokeOfficialPush(
            serverURL: pushServerURL,
            key: oldIdentity
        ) { [weak self] result in
            switch result {
            case .success:
                replaceLocalIdentity()
            case .failure(let error):
                self?.homeViewModel.pushState = .recoverableError(error.localizedDescription)
            }
        }
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
            onSend: { [weak self] example in
                self?.openPushExampleInSafari(example)
            },
            onCopy: { [weak self] example in
                self?.copyPushExampleURL(example)
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
        #if !DREL_RELEASE_MINIMAL_SETTINGS && !DREL_CONTAINER_ONLY
        alert.addAction(UIAlertAction(title: "推送加密", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(
                UIHostingController(rootView: PushEncryptionView()), animated: true
            )
        })
        #endif
        alert.addAction(UIAlertAction(title: "分组静音", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(
                UIHostingController(rootView: GroupMuteView()), animated: true
            )
        })
        #if !DREL_CONTAINER_ONLY
        alert.addAction(UIAlertAction(title: "管理自有服务", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(GatewayConfigurationViewController(), animated: true)
        })
        #endif
        #if !DREL_CONTAINER_ONLY
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

    #if !DREL_CONTAINER_ONLY
    private func handleTokenPushAction(_ action: TokenPushAction) {
        switch action {
        case .openTokenManager:
            showTokenManager()
        case .openAPIKeyManager:
            navigationController?.pushViewController(APIKeyManageViewController(viewModel: APIKeyManageViewModel()), animated: true)
        case .openNotificationDebug:
            #if !DREL_CONTAINER_ONLY
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

    /// The catalog's send icon opens the fully composed, Bark-compatible
    /// request in Safari. The compact copy icon keeps the exact URL available.
    private func openPushExampleInSafari(_ example: PushExample) {
        guard homeViewModel.isPushReady else {
            activateOfficialPush()
            return
        }

        guard let url = makeBarkURL(
            title: example.pushTitle,
            body: example.pushBody,
            queryItems: example.queryItems
        ) else {
            showMessage(title: "无法生成测试地址", message: "请检查推送服务地址是否有效。")
            return
        }

        UIApplication.shared.open(url, options: [:]) { [weak self] opened in
            guard !opened else { return }
            self?.showMessage(title: "无法打开 Safari", message: "请稍后重试，或先复制推送 URL。")
        }
    }

    private func copyPushExampleURL(_ example: PushExample) {
        copyPushURL(
            title: example.pushTitle,
            body: example.pushBody,
            queryItems: example.queryItems
        )
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
        #if DREL_CONTAINER_ONLY
        // A Store user pressing “send” is testing the push loop, not opening
        // an API response document. Issue one request in-process and surface
        // its result natively; do not retry because APNs may already have
        // accepted a timed-out alert request.
        sendDrelTestPush(to: url)
        return
        #endif
        #if !DREL_CONTAINER_ONLY
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

    private func sendDrelTestPush(to url: URL) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.showMessage(
                        title: L10n.tr("official.push.send.failure_title"),
                        message: error.localizedDescription
                    )
                    return
                }

                guard let response = response as? HTTPURLResponse,
                      (200...299).contains(response.statusCode) else {
                    self.showMessage(
                        title: L10n.tr("official.push.send.failure_title"),
                        message: L10n.tr("official.push.send.failure_message")
                    )
                    return
                }

                // Bark 兼容路由恒定返回 HTTP 200，投递结论只在 JSON body 里
                // （code≠200 或 accepted=0 都代表 APNs 没有接受该条通知）。
                // 只看 HTTP 状态码会把投递失败误报成「测试推送已发送」。
                if let data,
                   let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let code = body["code"] as? Int
                    let accepted = body["accepted"] as? Int
                    let deliveryFailed = (code.map { $0 != 200 } ?? false) || accepted == 0
                    if deliveryFailed {
                        let detail = (body["message"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                        self.showMessage(
                            title: L10n.tr("official.push.send.failure_title"),
                            message: detail ?? L10n.tr("official.push.send.failure_message")
                        )
                        return
                    }
                }

                HUDService.shared.showSuccess(withStatus: L10n.tr("official.push.send.success"))
            }
        }.resume()
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
        let rawSegments = title.isEmpty
            ? [officialPushIdentity, body]
            : [officialPushIdentity, title, body]
        let path = rawSegments.compactMap(Self.encodePathSegment).joined(separator: "/")
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

    #if !DREL_CONTAINER_ONLY
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
