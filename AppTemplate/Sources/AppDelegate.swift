import UIKit
import WebBridgeKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        WebBridgeKit.shared.initialize()

        Task {
            await MessageEngine.shared.registerChannel(BarkChannel(key: "test_key"))
            await MessageEngine.shared.registerChannel(WebhookChannel(port: 8765))
            await MessageEngine.shared.startAll()
        }

        Task {
            let config = CommandParserConfiguration(
                maxPayloadSize: 4096,
                maxAge: 300,
                allowedSchemes: ["http", "https"],
                commandPrefix: "【WebBridgeKit】",
                urlSchemePrefix: "wbsk://command",
                enableSignatureVerification: false,
                enableTimestampValidation: false
            )
            await CommandParser.shared.setConfiguration(config)
        }

        Task {
            let server = AIHTTPServer(port: 8765)
            await server.registerDefaultRoutes()
            try? await server.start()
        }

        window = UIWindow(frame: UIScreen.main.bounds)

        let tabBarController = TabBarController()
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        Task { @MainActor in
            await ThemeManager.shared.applyToWindow(window!)
        }

        #if DEBUG
        setupDebugPanel()
        #endif

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        #if DEBUG
        if url.scheme == "app" && url.host == "debug" {
            showDebugPanelViaTabSwitch()
            return true
        }
        if url.scheme == "webbridgekit" && url.host == "debug" {
            showDebugPanelViaTabSwitch()
            return true
        }
        #endif
        return false
    }

    #if DEBUG
    private func setupDebugPanel() {
        DebugTrigger.shared.setup(window: window)
    }

    private func showDebugPanelViaTabSwitch() {
        guard let tabBarController = window?.rootViewController as? TabBarController else { return }
        tabBarController.selectedIndex = 5
    }
    #endif
}
