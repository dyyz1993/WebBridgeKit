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
        
        let rootVC = RootViewController()
        window?.rootViewController = UINavigationController(rootViewController: rootVC)
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
        guard let navController = window?.rootViewController as? UINavigationController,
              let rootVC = navController.viewControllers.first else {
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            let debugButton = UIBarButtonItem(
                image: UIImage(systemName: "wrench.and.screwdriver"),
                style: .plain,
                target: self,
                action: #selector(self.showDebugPanel)
            )
            rootVC.navigationItem.rightBarButtonItem = debugButton
        }
    }
    
    @objc private func showDebugPanel() {
        DebugPanel.shared.show(from: window?.rootViewController)
    }
}
