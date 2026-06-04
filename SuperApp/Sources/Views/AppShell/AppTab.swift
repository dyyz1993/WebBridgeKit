import UIKit
import WebBridgeKit

enum AppTab: String, CaseIterable, Identifiable {
    case web
    case tokenPush
    case bridge
    case inbox
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .web:
            return "Web"
        case .inbox:
            return L10n.tr("tab.inbox")
        case .bridge:
            return "Bridge"
        case .tokenPush:
            return "Push"
        case .settings:
            return L10n.tr("tab.settings")
        }
    }

    var subtitle: String {
        switch self {
        case .web:
            return "网页打开、缓存、离线包与清理"
        case .inbox:
            return "推送消息历史、未读、分组与路由"
        case .bridge:
            return "JSBridge 命令、参数、回调与错误"
        case .tokenPush:
            return "Bark 推送、API 兼容、设备 Token 与消息路由"
        case .settings:
            return "配置、调试工具、协议模板与关于"
        }
    }

    var icon: LucideIcon {
        switch self {
        case .web:
            return .globe
        case .inbox:
            return .inbox
        case .bridge:
            return .terminal
        case .tokenPush:
            return .bell
        case .settings:
            return .settings
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .web:
            return "tab.web"
        case .inbox:
            return "tab.inbox"
        case .bridge:
            return "tab.bridge"
        case .tokenPush:
            return "tab.push"
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
