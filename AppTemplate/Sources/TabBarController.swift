import UIKit
import WebBridgeKit

class TabBarController: UITabBarController {

    private let configuration: AppTemplateConfiguration

    init(configuration: AppTemplateConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        configuration = .safeDefaults
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
        selectedIndex = 0
    }

    private func setupTabs() {
        let webVC = RootViewController(configuration: configuration)
        let webIcon = LucideIcon.globe.image(pointSize: 20)
        webVC.tabBarItem = UITabBarItem(title: "网页", image: webIcon, selectedImage: webIcon)
        viewControllers = [
            UINavigationController(rootViewController: webVC)
        ]
    }

    private func setupAppearance() {
        tabBar.backgroundColor = ThemeTokens.Color.tabBarBackground

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = ThemeTokens.Color.tabBarBackground
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
        navigationBar.backgroundColor = ThemeTokens.Color.navigationBarBackground

        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = ThemeTokens.Color.navigationBarBackground
            appearance.largeTitleTextAttributes = [.foregroundColor: ThemeTokens.Color.navigationBarTitle]
            appearance.titleTextAttributes = [.foregroundColor: ThemeTokens.Color.navigationBarTitle]
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
        }
    }
}
