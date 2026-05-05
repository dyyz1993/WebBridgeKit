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
        
        // Setup Debug Panel trigger
        setupDebugPanel()
        
        return true
    }
    
    // MARK: - Debug Panel
    
    private func setupDebugPanel() {
        // Register shake gesture to show debug panel
        DebugTrigger.shared.setup(window: window)
        
        // Add debug panel button to navigation bar if DEBUG build
        #if DEBUG
        addDebugButtonIfNeeded()
        #endif
    }
    
    private func addDebugButtonIfNeeded() {
        // Debug Panel is now available as a tab, no need for separate button
    }
    
    @objc private func showDebugPanel() {
        DebugPanel.shared.show(from: window?.rootViewController)
    }
}
