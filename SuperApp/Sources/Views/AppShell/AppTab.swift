import UIKit
import WebBridgeKit

enum AppTab: String, CaseIterable, Identifiable {
    case web
    case bridge
    case tokenPush
    case debug
    case links

    var id: String { rawValue }

    var title: String {
        switch self {
        case .web:
            return "Web"
        case .bridge:
            return "Bridge"
        case .tokenPush:
            return "Token/Push"
        case .debug:
            return "Debug"
        case .links:
            return "Links"
        }
    }

    var subtitle: String {
        switch self {
        case .web:
            return "网页打开、缓存、离线包与清理"
        case .bridge:
            return "JSBridge 命令、参数、回调与错误"
        case .tokenPush:
            return "口令、Token、设备 Token 与推送测试"
        case .debug:
            return "日志、网络、缓存、崩溃与诊断导出"
        case .links:
            return "协议跳转、URL 参数与命令路由"
        }
    }

    var icon: LucideIcon {
        switch self {
        case .web:
            return .globe
        case .bridge:
            return .terminal
        case .tokenPush:
            return .key
        case .debug:
            return .bug
        case .links:
            return .link
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .web:
            return "tab.web"
        case .bridge:
            return "tab.bridge"
        case .tokenPush:
            return "tab.tokenPush"
        case .debug:
            return "tab.debug"
        case .links:
            return "tab.links"
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
