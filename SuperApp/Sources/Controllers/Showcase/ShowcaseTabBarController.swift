import UIKit
import WebBridgeKit
import SnapKit

class ShowcaseTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "框架展示"
        view.backgroundColor = ThemeColors.current.background

        setupControllers()
        setupTabBarAppearance()
    }

    private func setupControllers() {
        let controllers: [(UIViewController, String, String)] = [
            (CacheShowcaseViewController(), "缓存", "archivebox"),
            (MessageShowcaseViewController(), "消息", "message"),
            (CommandShowcaseViewController(), "口令", "text.command"),
            (ThemeShowcaseViewController(), "主题", "paintbrush"),
            (AIShowcaseViewController(), "AI", "brain"),
            (BridgeShowcaseViewController(), "桥接", "arrow.left.arrow.right"),
            (BaseShowcaseViewController(), "基础", "square"),
            (ControllersShowcaseViewController(), "控制器", "square.stack"),
            (CoreShowcaseViewController(), "核心", "circuitboard"),
            (ExtensionsShowcaseViewController(), "扩展", "extension"),
            (HandlersShowcaseViewController(), "处理器", "lightbulb"),
            (InfrastructureShowcaseViewController(), "基础设施", "server"),
            (ManagersShowcaseViewController(), "管理器", "gear"),
            (ModelsShowcaseViewController(), "模型", "cube"),
            (ServicesShowcaseViewController(), "服务", "globe"),
            (SkillsShowcaseViewController(), "技能", "sparkles"),
            (UtilsShowcaseViewController(), "工具", "wrench"),
            (ViewModelsShowcaseViewController(), "视图模型", "doc.text"),
            (ViewsShowcaseViewController(), "视图", "rectangle.on.rectangle")
        ]

        viewControllers = controllers.map { vc, title, iconName in
            let nav = UINavigationController(rootViewController: vc)
            let tabItem = UITabBarItem(title: title, image: UIImage(systemName: iconName), selectedImage: nil)
            nav.tabBarItem = tabItem
            return nav
        }
    }

    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = ThemeColors.current.navigationBarBackground

        appearance.stackedLayoutAppearance.normal.iconColor = ThemeColors.current.textSecondary
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: ThemeColors.current.textSecondary,
            .font: ThemeTypography.current.caption1
        ]
        appearance.stackedLayoutAppearance.selected.iconColor = ThemeColors.current.primary
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: ThemeColors.current.primary,
            .font: ThemeTypography.current.caption1
        ]

        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }
}
