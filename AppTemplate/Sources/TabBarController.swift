import UIKit
import WebBridgeKit

class TabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
        selectedIndex = 0
    }

    private func setupTabs() {
        let webVC = RootViewController()

        #if DEBUG
        let cacheVC = CacheShowcaseViewController()
        let messageVC = MessageShowcaseViewController()
        let commandVC = CommandShowcaseViewController()
        let themeVC = ThemeShowcaseViewController()
        let debugVC = DebugPanelViewController()

        webVC.tabBarItem = UITabBarItem(title: "网页", image: UIImage(systemName: "globe"), selectedImage: UIImage(systemName: "globe.fill"))
        cacheVC.tabBarItem = UITabBarItem(title: "缓存", image: UIImage(systemName: "internaldrive"), selectedImage: UIImage(systemName: "internaldrive.fill"))
        messageVC.tabBarItem = UITabBarItem(title: "消息", image: UIImage(systemName: "bell"), selectedImage: UIImage(systemName: "bell.fill"))
        commandVC.tabBarItem = UITabBarItem(title: "口令", image: UIImage(systemName: "key"), selectedImage: UIImage(systemName: "key.fill"))
        themeVC.tabBarItem = UITabBarItem(title: "主题", image: UIImage(systemName: "paintbrush"), selectedImage: UIImage(systemName: "paintbrush.fill"))
        debugVC.tabBarItem = UITabBarItem(title: "调试", image: UIImage(systemName: "exclamationmark.bubble.fill"), selectedImage: UIImage(systemName: "exclamationmark.bubble"))

        viewControllers = [
            UINavigationController(rootViewController: webVC),
            UINavigationController(rootViewController: cacheVC),
            UINavigationController(rootViewController: messageVC),
            UINavigationController(rootViewController: commandVC),
            UINavigationController(rootViewController: themeVC),
            UINavigationController(rootViewController: debugVC)
        ]
        #else
        webVC.tabBarItem = UITabBarItem(title: "网页", image: UIImage(systemName: "globe"), selectedImage: UIImage(systemName: "globe.fill"))
        viewControllers = [
            UINavigationController(rootViewController: webVC)
        ]
        #endif
    }

    private func setupAppearance() {
        tabBar.backgroundColor = ThemeColors.current.tabBarBackground

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = ThemeColors.current.tabBarBackground
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }

        for nav in viewControllers ?? [] {
            if let navigationController = nav as? UINavigationController {
                configureNavigationBar(navigationController.navigationBar)
            }
        }
    }

    private func configureNavigationBar(_ navigationBar: UINavigationBar) {
        navigationBar.prefersLargeTitles = true
        navigationBar.backgroundColor = ThemeColors.current.navigationBarBackground

        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = ThemeColors.current.navigationBarBackground
            appearance.largeTitleTextAttributes = [.foregroundColor: ThemeColors.current.navigationBarTitle]
            appearance.titleTextAttributes = [.foregroundColor: ThemeColors.current.navigationBarTitle]
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
        }
    }
}
