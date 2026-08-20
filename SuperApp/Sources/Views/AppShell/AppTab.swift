import UIKit
import WebBridgeKit

enum AppTab: String, CaseIterable, Identifiable {
    case apps
    case notifications
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apps:
            return L10n.tr("tab.apps")
        case .notifications:
            return L10n.tr("tab.notifications")
        case .settings:
            return L10n.tr("tab.settings")
        }
    }

    var subtitle: String {
        switch self {
        case .apps:
            return "已验证 PWA、离线状态与网关接入"
        case .notifications:
            return "跨应用通知、未读、分组与精确路由"
        case .settings:
            return "配置、调试工具、协议模板与关于"
        }
    }

    var icon: LucideIcon {
        switch self {
        case .apps:
            return .globe
        case .notifications:
            return .bell
        case .settings:
            return .settings
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .apps:
            return "tab.apps"
        case .notifications:
            return "tab.notifications"
        case .settings:
            return "tab.settings"
        }
    }

    func makeTabBarItem() -> UITabBarItem {
        let item = UITabBarItem(
            title: title,
            image: icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.tab),
            selectedImage: icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.tab)
        )
        item.accessibilityIdentifier = accessibilityIdentifier
        return item
    }
}
