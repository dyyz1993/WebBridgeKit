//
//  AppDelegate.swift
//  SuperApp
//
//  Created on 2026-01-16.
//

import UIKit
import UserNotifications
import SwiftUI
import WebBridgeKit
#if DEBUG
import Network
#endif

extension ProcessInfo {
    var isWebBridgeKitUITesting: Bool {
        let supportedArguments = ["-UITesting", "--UITesting", "--ui-testing"]
        return supportedArguments.contains { arguments.contains($0) }
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private static let copyNotificationCategoryIdentifier = "DREL_COPY"
    private static let copyNotificationActionIdentifier = "DREL_COPY_ACTION"

    var window: UIWindow?

    /// A `drel://` URL that launched the app cold; processed once the window
    /// exists (see application(_:didFinishLaunchingWithOptions:)).
    private var pendingExternalLaunchURL: URL?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if DREL_CONTAINER_ONLY
        WebBrowserManager.shared.webGrantsPresenter = nil
        #else
        WebBrowserManager.shared.webGrantsPresenter = { hostVC in
            // 沉浸式浏览器隐藏了导航栏，推入的授权页需要显式恢复，
            // 否则网页授权管理页没有返回入口。
            hostVC.navigationController?.setNavigationBarHidden(false, animated: false)
            let vc = UIHostingController(rootView: WebOriginGrantsView())
            vc.title = "网页授权管理"
            vc.hidesBottomBarWhenPushed = true
            hostVC.navigationController?.pushViewController(vc, animated: true)
        }
        #endif

        let start = Date()

        CrashLogManager.shared.initialize()
        NetworkMonitor.shared.startMonitoring()
        HTMLAppHostUI.settingsViewControllerProvider = SuperAppHTMLAppSettingsProvider.shared
        Self.cleanupDeadSeedFavorites()

        if let serverURL = ServerConfigManager.shared.getActiveBaseURL() {
            CrashLogManager.shared.serverBaseURL = serverURL
            CrashLogManager.shared.uploadPendingCrashReports()
        }

        let isUITesting = ProcessInfo.processInfo.isWebBridgeKitUITesting
        #if DEBUG
        DrelSelfHostedUITestFixture.startIfRequested()
        #endif
        #if !DREL_CONTAINER_ONLY
        if isUITesting {
            TestDataSeeder.populateIfNeeded()
            Self.cleanupInvalidHistoryURLs()
            // UI 测试要求全新账本：授权持久化（正常功能）会让重装的测试
            // 设备带着旧授权跑——首调静默命中账本而不是弹面板
            // （2026-08-24 定位：测试设备与 `booted` 不是同一台导致卸载无效）。
            if ProcessInfo.processInfo.arguments.contains("--reset-permission-grants") {
                HTMLAppPermissionLedger.shared.revokeAll()
            }
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                TestDataSeeder.populateIfNeeded()
                Self.cleanupInvalidHistoryURLs()
            }
        }
        #else
        Self.cleanupInvalidHistoryURLs()
        #endif

        // APNs sandbox tokens rotate across reinstalls; refresh silently on
        // every launch so the server always holds the current one.
        if !isUITesting {
            // Mirror bundled ringtones into Library/Sounds so named push
            // sounds resolve even if bundle-root lookup misbehaves on device.
            DispatchQueue.global(qos: .utility).async {
                PushSoundInstaller.install()
            }
            DispatchQueue.main.async {
                Self.refreshPushRegistration()
            }
        }

        // Removed startup clearAll() — it was deleting PersistentCache files that should survive app restarts.
        // Cache cleanup is now handled by WebCacheManager.scheduleAutoCleanup() which respects persistence.

        // 初始化 WebBridgeKit（异步执行，避免偶尔阻塞主线程导致卡 loading）
        // UI 测试时禁用 WebBridgeKit 预热，减少主线程压力和 WebKit 进程消耗
        if !isUITesting {
            DispatchQueue.global(qos: .userInitiated).async {
                WebBridgeKitManager.shared.initialize()
            }
        } else {
            WebBridgeLogger.shared.info("WebBridgeKit initialized (warmup skipped for UI testing)")
        }

        let messageStore = UserDefaultsMessageStore(key: "SuperCache_Messages")
        Task {
            await MessageEngine.shared.setStore(messageStore)
        }

        // 创建窗口（支持摇一摇触发调试面板）
        window = DebugWindow(frame: UIScreen.main.bounds)

        // 创建根视图控制器（使用 TabBar）
        let tabBarController = TabBarController()

        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        // Initialize all new engines
        Task {
            await EngineBootstrap.shared.initialize(in: self.window)
        }

        // 会话恢复：iOS 在系统设置修改隐私权限（TCC）会终止 App——
        // 「前往系统设置」引导流程回来必然是冷启动。5 分钟内的上次
        // 浏览页自动重开，用户改完权限回来直接续上原页面重试。
        // UI 测试默认关闭（UserDefaults 跨用例残留会让后续用例误恢复），
        // 由本行为专门的测试用 --enable-session-restore 显式打开。
        let defaultStartupAppID = UserDefaults.standard
            .string(forKey: SettingsPreferenceKeys.defaultStartupAppID) ?? ""
        // drel://app cold launch is an explicit destination: capture it before
        // the restore decision (it suppresses session restore) and run once
        // the window exists. A notification cold launch outranks it.
        if let coldURL = launchOptions?[.url] as? URL,
           coldURL.scheme?.lowercased() == "drel",
           launchOptions?[.remoteNotification] == nil {
            pendingExternalLaunchURL = coldURL
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, let url = self.pendingExternalLaunchURL else { return }
                self.pendingExternalLaunchURL = nil
                _ = self.handleDrelExternalURL(url)
            }
        }
        let restoreEnabled = DrelStartupNavigationPolicy.shouldRestoreRecentSession(
            isUITesting: isUITesting,
            explicitlyEnablesUITestRestore: ProcessInfo.processInfo.arguments
                .contains("--enable-session-restore"),
            // A notification response supplies the user's explicit destination.
            launchedFromRemoteNotification: launchOptions?[.remoteNotification] != nil,
            // A trusted default app is opened by TabBarController. Letting the
            // delayed recent-session restore run as well creates a second
            // normal browser and strips the immersive presentation.
            hasDefaultStartupApp: !defaultStartupAppID.isEmpty
        )
        // The external link (pending above) already claims this launch.
        if restoreEnabled, pendingExternalLaunchURL == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self, self.window?.rootViewController != nil,
                      let url = WebBrowserManager.restorableLastURL() else { return }
                WebBrowserManager.shared.openBrowser(
                    url: url,
                    params: WebBrowserParams(useManifestLoader: false)
                )
            }
        }

        // 注册推送通知
        UNUserNotificationCenter.current().delegate = self
        Self.registerNotificationActions()

        // The component catalog is a development-only visual test surface. It
        // must not be reachable from the Store binary through launch args.
        #if !DREL_CONTAINER_ONLY
        if ProcessInfo.processInfo.arguments.contains("--show-component-catalog") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                let catalogVC = ComponentCatalogViewController()
                let nav = UINavigationController(rootViewController: catalogVC)
                nav.modalPresentationStyle = .fullScreen
                self.window?.rootViewController?.present(nav, animated: false)
            }
        }
        #endif

        //  Support automated testing via launch arguments
        #if !DREL_CONTAINER_ONLY
        if ProcessInfo.processInfo.arguments.contains("-RunAllTests") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let tabBarController = self.window?.rootViewController as? UITabBarController {
                    tabBarController.selectedIndex = 1
                    if let nav = tabBarController.viewControllers?[1] as? UINavigationController,
                       let testVC = nav.viewControllers.first as? ManifestTestCasesViewController {
                        testVC.runAllTests()
                    }
                }
            }
        }
        #endif

        if !isUITesting {
            DispatchQueue.global(qos: .utility).async {
                PushRelayManager.shared.connect()
            }
        }

        let duration = Date().timeIntervalSince(start)
        Log.info("App launch took \(String(format: "%.3f", duration))s", category: .performance)

        #if !DREL_CONTAINER_ONLY
        registerNotificationFixtureIfRequested()
        registerBridgePermissionFixtureIfRequested()
        showPWAAppCenterIfRequested()
        if ProcessInfo.processInfo.arguments.contains("--reset-default-startup-app") {
            UserDefaults.standard.removeObject(forKey: SettingsPreferenceKeys.defaultStartupAppID)
        }
        #endif

        return true
    }

    #if !DREL_CONTAINER_ONLY
    private func registerNotificationFixtureIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--register-pwa-notification-fixture") else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        let fixture = notificationFixture()
        let manifest = HTMLAppManifest(
            appID: fixture.appID,
            name: fixture.name,
            startURL: "\(fixture.origin)\(fixture.route)",
            allowedOrigins: [fixture.origin],
            capabilities: [.notification],
            routes: fixture.routes,
            cache: HTMLAppCachePolicy(
                strategy: .manifest,
                version: "2026.08.10",
                persistent: true,
                restoresLastState: true
            )
        )
        do {
            try HTMLAppRuntimeCenter.shared.trustRegistry.register(manifest)
            StructuredLogger.shared.info("Registered APNs route fixture", category: .navigation)
            openNotificationFixtureIfRequested()
        } catch {
            StructuredLogger.shared.error(
                "Unable to register APNs route fixture: \(error.localizedDescription)",
                category: .navigation
            )
        }
    }

    private func registerBridgePermissionFixtureIfRequested() {
        let fixtureAppID = "com.webbridgekit.fixture.permissions"
        guard ProcessInfo.processInfo.arguments.contains("--register-pwa-permission-fixture") else {
            // UI 测试注册的 fixture 会持久写进信任清单；正常启动时清掉，
            // 否则测试宿主（模拟器）的「我的应用」宫格会残留演示应用。
            try? HTMLAppRuntimeCenter.shared.trustRegistry.unregister(appID: fixtureAppID)
            return
        }
        let runtime = HTMLAppRuntimeCenter.shared
        // Register the fixture under the ACTIVE gateway identity when one is
        // configured: the permission center syncs runtime.gatewayIdentity to
        // the active gateway on open, and that sync wipes grants recorded
        // under any other identity (removeGrants on change). Seeding under
        // "test-gateway" made the grant vanish the moment the center opened
        // on a device with a configured gateway. Fall back to the test
        // identity only when no gateway is active.
        let activeGateway = HTMLAppGatewayRegistry().activeGateway()
        let fixtureIdentity = activeGateway
            .map { "\($0.id)#\($0.publicKeyID ?? "unsigned")" }
            ?? "test-gateway"
        runtime.gatewayIdentity = fixtureIdentity
        runtime.permissionLedger.revokeAll(appID: "com.webbridgekit.fixture.permissions")
        let origin = ProcessInfo.processInfo.environment["WBK_PWA_PERMISSION_ORIGIN"] ?? "http://localhost:8081"
        let route = "/test_resources/pwa-permission/index.html"
        let manifest = HTMLAppManifest(
            appID: "com.webbridgekit.fixture.permissions",
            name: "原生能力演示",
            startURL: "\(origin)\(route)",
            allowedOrigins: [origin],
            capabilities: [.bluetooth, .clipboard, .camera, .location, .fileImport, .share],
            routes: [route],
            cache: HTMLAppCachePolicy(
                strategy: .networkOnly,
                version: "2026.08.13",
                persistent: false,
                restoresLastState: true
            )
        )
        try? runtime.register(manifest)
        if ProcessInfo.processInfo.arguments.contains("--seed-pwa-permission-grant") {
            runtime.permissionLedger.grant(
                subject: HTMLAppPermissionSubject(
                    gatewayIdentity: runtime.gatewayIdentity,
                    appID: manifest.appID,
                    origin: origin
                ),
                capability: .clipboard,
                scope: .always
            )
        }
    }

    private func openNotificationFixtureIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--open-pwa-notification-fixture") else { return }
        let fixture = notificationFixture()
        let userInfo: [AnyHashable: Any] = [
            "version": "1",
            "appId": fixture.appID,
            "route": fixture.route,
            "title": fixture.notificationTitle,
            "body": fixture.notificationBody,
            "params": fixture.parameters
        ]
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            PushNotificationManager.shared.handleNotificationTap(
                userInfo: userInfo,
                rootViewController: self?.window?.rootViewController
            )
        }
    }

    private func notificationFixture() -> NotificationFixture {
        NotificationFixture(processInfo: ProcessInfo.processInfo)
    }

    private struct NotificationFixture {
        let origin: String
        let appID: String
        let name: String
        let route: String
        let routes: [String]
        let parameters: [String: String]
        let notificationTitle: String
        let notificationBody: String

        init(processInfo: ProcessInfo) {
            origin = processInfo.environment["WBK_PWA_FIXTURE_ORIGIN"] ?? "http://localhost:8081"
            let requestedCase = processInfo.environment["WBK_PWA_FIXTURE_CASE"]

            switch requestedCase {
            case "task":
                appID = "com.webbridgekit.fixture.agent-console"
                name = "Agent Console Fixture"
                route = "/test_resources/pwa-agent-console/index.html"
                routes = [route, "/test_resources/pwa-agent-console/approval.html"]
                parameters = ["taskId": "run-20260810", "status": "completed"]
                notificationTitle = "运行任务已完成"
                notificationBody = "点击查看任务输出并继续处理"
            case "approval":
                appID = "com.webbridgekit.fixture.agent-console"
                name = "Agent Console Fixture"
                route = "/test_resources/pwa-agent-console/approval.html"
                routes = ["/test_resources/pwa-agent-console/index.html", route]
                parameters = ["requestId": "approval-42", "source": "remote-task"]
                notificationTitle = "需要你的确认"
                notificationBody = "打开审批页面后仍需手动确认"
            default:
                appID = "com.webbridgekit.fixture.chat"
                name = "Chat Fixture"
                route = processInfo.environment["WBK_PWA_FIXTURE_ROUTE"] ?? "/test_resources/pwa-notification/index.html"
                routes = Array(Set([
                    route,
                    "/test_resources/pwa-notification/index.html",
                    "/test_resources/pwa-notification/approval.html"
                ])).sorted()
                parameters = ["conversationId": "user-42", "messageId": "message-7"]
                notificationTitle = "收到一条新消息"
                notificationBody = "点击回到与 User 42 的对话"
            }
        }
    }

    private func showPWAAppCenterIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--show-pwa-app-center") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let tabBarController = self?.window?.rootViewController as? TabBarController else { return }
            tabBarController.selectedIndex = 0
            guard let navigationController = tabBarController.selectedViewController as? UINavigationController else { return }
            navigationController.pushViewController(PWAAppCenterViewController(), animated: false)
        }
    }
    #endif

    func applicationWillEnterForeground(_ application: UIApplication) {
        Log.info("App entering foreground", category: .general)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Log.info("App entering background", category: .general)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Import push payloads recorded by the Notification Service Extension
        // while the app was backgrounded or killed (Bark-style recovery).
        Task {
            await PendingMessageImporter.importPending()
        }
        #if !DREL_CONTAINER_ONLY
        if !ProcessInfo.processInfo.isWebBridgeKitUITesting {
            // Clipboard reads must stay off the activation transition: reading
            // UIPasteboard.string can trigger a slow HTML→text coercion in the
            // pasteboard daemon (synchronous XPC). On the main thread during
            // didBecomeActive that froze the app permanently (watchdog kill,
            // see SuperApp-2026-08-20 hang reports). Defer past the scene
            // transition and read on a background queue instead.
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self else { return }
                TokenManager.shared.parseTokenFromClipboard()
                CommandHandler.shared.checkClipboardOnForeground()
            }
        }
        #endif
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // `drel://` is Drel's single intentional external surface: launching a
        // REGISTERED HTML app (DrelExternalAppLink — never a raw web URL) and
        // routing deployment QR codes into the self-hosted import flow.
        if url.scheme?.lowercased() == "drel" {
            return handleDrelExternalURL(url)
        }

        // Drel 1.0 intentionally has no other external command/deep-link surface.
        // Its only web entry is the validated route received from an APNs
        // notification or a trusted gateway manifest. Keeping the legacy
        // WebBridgeKit scheme out of this Store build prevents arbitrary URLs
        // or command payloads from turning it into a generic browser.
        #if DREL_CONTAINER_ONLY
        return false
        #else
        if url.scheme == "webbridgekit" {
            // 解析真实的 URL
            // 假设格式为 webbridgekit://open?url=https%3A%2F%2Fgoogle.com
            if url.host == "open" {
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let queryItems = components.queryItems,
                   let targetURLString = queryItems.first(where: { $0.name == "url" })?.value,
                   let targetURL = URL(string: targetURLString) {

                    WebBrowserManager.shared.openBrowser(url: targetURL)
                    return true
                }
            } else if url.host == "tab" {
                // 切换 Tab
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let queryItems = components.queryItems,
                   let indexString = queryItems.first(where: { $0.name == "index" })?.value,
                   let index = Int(indexString),
                   let tabBarController = window?.rootViewController as? UITabBarController {

                    tabBarController.selectedIndex = index
                    return true
                }
            } else if url.host == "command" {
                // Handle webbridgekit://command/<token> — resolve token from server
                let tokenString = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard !tokenString.isEmpty else { return false }
                UIPasteboard.general.string = "webbridgekit://command/\(tokenString)"
                Task { @MainActor in
                    CommandHandler.shared.checkClipboardOnForeground()
                }
                return true
            } else if url.host == "runalltests" {
                #if !DREL_CONTAINER_ONLY
                if let tabBarController = window?.rootViewController as? UITabBarController,
                   let nav = tabBarController.viewControllers?[1] as? UINavigationController,
                   let testVC = nav.viewControllers.first as? ManifestTestCasesViewController {
                    tabBarController.selectedIndex = 1
                    // Use performSelector to avoid direct dependency if needed, but here it's fine
                    testVC.runAllTests()
                    return true
                }
                #endif
            }
        }

        return false
        #endif
    }

    // MARK: - drel:// external app link

    /// `drel://app?app_id=…&route=…&param_<name>=…` opens a gateway-signed
    /// registered HTML app — the app equivalent of a push launch. Anything
    /// else under the scheme routes QR import payloads or is refused.
    private func handleDrelExternalURL(_ url: URL) -> Bool {
        if DrelExternalAppLink.parse(url) != nil {
            openExternalAppLinkFromHandoff(url)
            return true
        }

        switch url.host?.lowercased() {
        case "self-hosted-push", "managed-encrypted-push":
            // A deployment QR opened outside the in-app scanner. Keep the
            // payload on the clipboard and guide to the import UI instead of
            // silently auto-pairing from an opaque system handoff.
            UIPasteboard.general.string = url.absoluteString
            HUDService.shared.showSuccess(withStatus: "自托管配置码已复制，请在 设置 → 推送通道 粘贴导入")
            return true
        default:
            return false
        }
    }

    private func openExternalAppLinkFromHandoff(_ url: URL) {
        guard let link = DrelExternalAppLink.parse(url) else { return }
        DrelExternalAppLinkOpener.open(link, from: window?.rootViewController)
    }

    // MARK: - Push Notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        _ = tokenParts.joined()
        PushNotificationManager.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)

        // 将 Token 发送给服务器
        // APIKeyManager.shared.updateDeviceToken(token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let request = notification.request
        // Consumer-side decryption: do not trust the NSE's modified
        // userInfo to survive delivery — decrypt here if the wire envelope
        // is still present.
        let wireUserInfo = PushCipher.decryptingUserInfoIfEncrypted(request.content.userInfo)
        Task {
            DrelPushAppCatalogCoordinator.shared.activateIfTrusted(userInfo: wireUserInfo)
            let payload = makeMessagePayload(
                identifier: request.identifier,
                userInfo: wireUserInfo,
                content: request.content
            )
            try? await MessageEngine.shared.receive(payload)
        }

        let mode = notification.request.content.userInfo["mode"] as? String
        // passive 静默语义对齐：apns interruption-level=passive 的推送在前台
        // 同样不弹横幅（catalog 被动通知卡发的是 level 而非 mode）。
        if mode == "silent" || mode == "passive"
            || notification.request.content.interruptionLevel == .passive {
            completionHandler([])
            return
        }

        // Bark parity: foreground notifications present silently. The iOS
        // foreground pipeline mangles named sounds every way we tried
        // (SystemSound rejects AAC, AVAudioPlayer plays silently, .sound
        // falls back to the default tone), and Bark itself returns plain
        // .alert here. Named sounds play via the system path when the app
        // is backgrounded or locked — the normal push usage.
        completionHandler([.banner, .list, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = PushCipher.decryptingUserInfoIfEncrypted(
            response.notification.request.content.userInfo
        )
        let content = response.notification.request.content
        var routingInfo = userInfo
        routingInfo["title"] = userInfo["title"] as? String ?? content.title
        routingInfo["body"] = userInfo["body"] as? String ?? content.body

        let isCopyAction = response.actionIdentifier == Self.copyNotificationActionIdentifier

        // Record the message into the inbox FIRST, then copy or route. If routing
        // fires before the message is stored, focusMessage finds nothing and
        // the user lands on the inbox list instead of the detail page.
        Task { [weak self] in
            DrelPushAppCatalogCoordinator.shared.activateIfTrusted(userInfo: userInfo)
            let payload = self?.makeMessagePayload(
                identifier: response.notification.request.identifier,
                userInfo: userInfo,
                content: content
            )
            if let payload {
                try? await MessageEngine.shared.receive(payload)
            }

            // Message is now in the inbox; safe to perform the chosen action.
            await MainActor.run { [weak self] in
                if isCopyAction {
                    let copyValue = (userInfo["copy"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    UIPasteboard.general.string = copyValue?.isEmpty == false ? copyValue : content.body
                    HUDService.shared.showSuccess(withStatus: "内容已复制")
                } else {
                    PushNotificationManager.shared.handleNotificationTap(
                        userInfo: routingInfo,
                        rootViewController: self?.window?.rootViewController
                    )
                }
            }
        }

        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let isDelete = (userInfo["delete"] as? Bool) == true
            || (userInfo["delete"] as? String) == "1"
            || (userInfo["delete"] as? NSNumber)?.boolValue == true
        guard isDelete,
              let replacementID = userInfo["id"] as? String,
              !replacementID.isEmpty else {
            completionHandler(.noData)
            return
        }

        // APNs request identifiers are not guaranteed to equal collapse IDs.
        // Match the explicit Bark-compatible `id` carried in userInfo instead.
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let identifiers = notifications.compactMap { notification -> String? in
                let value = notification.request.content.userInfo["id"] as? String
                return value == replacementID ? notification.request.identifier : nil
            }
            if !identifiers.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
            }
        }

        let payload = NotificationPayloadMapper.makePayload(
            identifier: replacementID,
            userInfo: userInfo,
            fallbacks: .init(
                title: userInfo["title"] as? String ?? "",
                body: userInfo["body"] as? String ?? "",
                subtitle: userInfo["subtitle"] as? String,
                badge: nil
            )
        )
        Task {
            try? await MessageEngine.shared.receive(payload)
            completionHandler(.newData)
        }
    }

    private static func registerNotificationActions() {
        let copy = UNNotificationAction(
            identifier: copyNotificationActionIdentifier,
            title: "复制",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: copyNotificationCategoryIdentifier,
            actions: [copy],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func makeMessagePayload(
        identifier: String,
        userInfo: [AnyHashable: Any],
        content: UNNotificationContent
    ) -> MessagePayload {
        NotificationPayloadMapper.makePayload(
            identifier: identifier,
            userInfo: userInfo,
            fallbacks: NotificationPayloadMapper.ContentFallbacks(
                title: content.title,
                body: content.body,
                subtitle: content.subtitle,
                badge: content.badge?.intValue
            )
        )
    }

    // MARK: - DEBUG Helpers

    /// 注入测试URL到历史记录（仅DEBUG模式）
    private func injectTestURLsForDebugging() {
    }

    /// Re-registers an already-authorized installation on launch. iOS rotates
    /// APNs tokens across reinstalls, but a cold launch must never cause the
    /// notification permission sheet to appear before the developer has seen
    /// their local push address and chosen “启用通知”.
    private static func refreshPushRegistration() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
                    || settings.authorizationStatus == .ephemeral else {
                return
            }

            DispatchQueue.main.async {
                if let selfHosted = SelfHostedPushConfiguration.load() {
                    // A self-hosted choice must never silently register this
                    // APNs token with api.drel.app on launch or token refresh.
                    PushNotificationManager.shared.activateSelfHostedPush(
                        importPayload: selfHosted.reconnectImportPayload()
                    ) { _ in }
                    return
                }
                guard let identity = try? OfficialPushIdentityStore.shared.currentOrMigrateToShortIdentity() else { return }
                let serverURL = ServerConfigManager.shared.getActiveBaseURL()
                    ?? UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server")
                    ?? "https://api.drel.app"
                PushNotificationManager.shared.activateOfficialPush(serverURL: serverURL, key: identity) { _ in }
            }
        }
    }

    /// 一次性清理：legacy 测试种子收藏指向已下线的 ae8fcb.shanbox 静态站
    /// （9-15 容器重建后恒 502），用户设备残留的这批条目永远打不开。
    /// 按 host 精确匹配删除，其余收藏一概不动（用户手动收藏的不受影响）。
    private static func cleanupDeadSeedFavorites() {
        let key = "AppDelegate_DidCleanupDeadSeedHost_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        Task { @MainActor in
            let favoriteManager = URLFavoriteManager.shared
            let allFavorites = (try? await favoriteManager.getAllFavorites()) ?? []
            var removed = 0
            for fav in allFavorites {
                guard let url = URL(string: fav.url),
                      url.host?.lowercased() == "ae8fcb.shanbox.19930810.xyz" else { continue }
                try? await favoriteManager.deleteFavorite(url: url)
                removed += 1
            }
            WebBridgeLogger.shared.info("Dead seed favorites cleanup: removed \(removed) entries")
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    private static func cleanupInvalidHistoryURLs() {
        let key = "AppDelegate_DidCleanupAllData_v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        Task { @MainActor in
            let favoriteManager = URLFavoriteManager.shared
            let allFavorites = (try? await favoriteManager.getAllFavorites()) ?? []
            for fav in allFavorites {
                if let url = URL(string: fav.url) {
                    try? await favoriteManager.deleteFavorite(url: url)
                }
            }

            let historyManager = WebPageHistoryManager.shared
            try? await historyManager.clearAllHistory()

            // 预置推荐只在测试环境（Debug）出现；发布构建新装用户的收藏夹
            // 必须从空开始，不得自动塞入任何预置条目。
            #if DEBUG
            let recommended = PresetURLCatalog.recommendedItems
            var seeded = 0
            for item in recommended {
                guard let url = URL(string: item.url) else { continue }
                if (try? await favoriteManager.findFavorite(url: url)) == nil {
                    _ = try? await favoriteManager.addFavorite(url: url, title: item.title)
                    seeded += 1
                }
            }
            WebBridgeLogger.shared.info("Data reset: cleared \(allFavorites.count) favs, seeded \(seeded) recommended")
            #endif

            UserDefaults.standard.set(true, forKey: key)
        }
    }
}

// MARK: - DebugWindow

#if !DREL_CONTAINER_ONLY
private class DebugWindow: UIWindow {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }

        let debugPanel = DebugPanelViewController()
        let nav = UINavigationController(rootViewController: debugPanel)
        nav.modalPresentationStyle = .fullScreen

        topViewController()?.present(nav, animated: true)
    }

    private func topViewController() -> UIViewController? {
        let root = rootViewController
        return getTopViewController(from: root)
    }

    private func getTopViewController(from vc: UIViewController?) -> UIViewController? {
        guard let vc = vc else { return nil }
        if let presented = vc.presentedViewController {
            return getTopViewController(from: presented)
        }
        if let nav = vc as? UINavigationController {
            return getTopViewController(from: nav.visibleViewController)
        }
        if let tab = vc as? UITabBarController {
            return getTopViewController(from: tab.selectedViewController)
        }
        return vc
    }
}
#else
private typealias DebugWindow = UIWindow
#endif

// MARK: - Self-hosted push UI-test loopback fixture

// This lives in AppDelegate.swift so the existing Xcode project compiles it
// without regenerating project files. It is absent from Drel's Store build.
#if DEBUG
private enum DrelSelfHostedUITestFixture {
    private static let port: NWEndpoint.Port = 18080
    private static var listener: NWListener?
    private static let queue = DispatchQueue(label: "app.drel.ui-test-fixture")

    static func startIfRequested() {
        guard ProcessInfo.processInfo.isWebBridgeKitUITesting,
              ProcessInfo.processInfo.environment["WBK_SELF_HOSTED_UI_TEST_FIXTURE"] == "1",
              listener == nil
        else { return }

        do {
            let listener = try NWListener(using: .tcp, on: port)
            listener.newConnectionHandler = { connection in
                accept(connection)
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            // The UI test will surface a failed connection. Never expose this
            // internal fixture or its error details in a production UI.
            self.listener = nil
        }
    }

    private static func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, data: Data())
    }

    private static func receiveRequest(on connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { chunk, _, complete, _ in
            var collected = data
            if let chunk { collected.append(chunk) }
            if let end = collected.range(of: Data("\r\n\r\n".utf8)) {
                respond(to: connection, requestHead: collected[..<end.lowerBound])
            } else if complete || collected.count >= 16_384 {
                connection.cancel()
            } else {
                receiveRequest(on: connection, data: collected)
            }
        }
    }

    private static func respond(to connection: NWConnection, requestHead: Data.SubSequence) {
        let firstLine = String(decoding: requestHead, as: UTF8.self)
            .split(separator: "\n", maxSplits: 1).first ?? ""
        let parts = firstLine.split(separator: " ", maxSplits: 2)
        let method = parts.first.map(String.init) ?? ""
        let path = parts.dropFirst().first.map(String.init) ?? ""

        let body: String
        let status: String
        switch (method, path) {
        case ("GET", "/.well-known/drel-push.json"):
            status = "200 OK"
            body = """
            {"schema":"drel.self-hosted-push.v1","name":"Simulator Self-hosted","publicBaseURL":"http://127.0.0.1:18080","registrationPath":"/self-hosted/register","pairingPath":"/self-hosted/pairings","healthPath":"/health","unregisterPath":"/unregister"}
            """
        case ("GET", "/health"):
            status = "200 OK"
            body = "{\"status\":\"ok\",\"apnsReady\":true}"
        case ("POST", "/self-hosted/pairings"):
            status = "200 OK"
            body = "{\"pairingToken\":\"ui-test-ticket\"}"
        case ("POST", "/self-hosted/register"):
            status = "201 Created"
            body = "{\"ok\":true}"
        default:
            status = "404 Not Found"
            body = "{\"code\":404}"
        }

        let response = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
#endif
