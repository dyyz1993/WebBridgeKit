import UIKit
import WebBridgeKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize WebBridgeKit framework
        WebBridgeKit.shared.initialize()
        
        // Setup window
        window = UIWindow(frame: UIScreen.main.bounds)

        let tabBarController = TabBarController()
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        #if DEBUG
        // Setup Debug Panel trigger
        setupDebugPanel()
        #endif

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        #if DEBUG
        // Handle debug panel URL schemes
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

    // MARK: - Debug Panel

    #if DEBUG
    private func setupDebugPanel() {
        // Register shake gesture to show debug panel
        DebugTrigger.shared.setup(window: window)

        // Add debug panel button to navigation bar if DEBUG build
        addDebugButtonIfNeeded()
    }

    private func addDebugButtonIfNeeded() {
        // Debug Panel is now available as a tab, no need for separate button
    }

    private func showDebugPanelViaTabSwitch() {
        guard let tabBarController = window?.rootViewController as? TabBarController else {
            return
        }

        // Switch to Handlers tab (index 1)
        tabBarController.selectedIndex = 1
    }

    @objc private func showDebugPanel() {
        DebugPanel.shared.show(from: window?.rootViewController)
    }
    #endif
}
