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
        
        return true
    }
}
