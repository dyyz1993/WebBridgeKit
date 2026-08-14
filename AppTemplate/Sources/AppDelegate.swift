import UIKit
import WebBridgeKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private let configuration = AppTemplateConfiguration.safeDefaults
    #if DEBUG
    private var diagnosticsServer: AIHTTPServer?
    #endif

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        WebBridgeKitManager.shared.initialize()

        startConfiguredServices()

        window = UIWindow(frame: UIScreen.main.bounds)

        let tabBarController = TabBarController(configuration: configuration)
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        Task { @MainActor in
            if let window {
                await ThemeManager.shared.applyToWindow(window)
            }
        }

        #if DEBUG
        DebugPanelBridge.shared.configure(with: configuration)
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
        DebugTrigger.shared.showDebugPanel(from: window?.rootViewController)
    }
    #endif

    private func startConfiguredServices() {
        if let barkDeviceKey = configuration.barkDeviceKey {
            Task {
                let channel = BarkChannel(
                    serverURL: configuration.barkServerURL,
                    key: barkDeviceKey
                )
                await MessageEngine.shared.registerChannel(channel)
                await MessageEngine.shared.startAll()
            }
        }

        if configuration.enablesSignedCommandValidation {
            Task {
                await CommandParser.shared.setConfiguration(.default)
            }
        }

        #if DEBUG
        if let port = configuration.localDiagnosticsPort {
            let server = AIHTTPServer(port: port)
            diagnosticsServer = server
            Task {
                await server.registerDefaultRoutes()
                try? await server.start()
            }
        }
        #endif
    }
}
