import Foundation
import WebBridgeKit

enum AppShellAction {
    case openWebCatalog
    case openCacheDashboard
    case openCacheManagement
    case openBridgeShowcase
    case openTokenManager
    case openAPIKeyManager
    case openNotificationDebug
    case openMessageHistory
    case openDebugPanel
    case openDiagnostics
    case openDeepLinkExamples
    case openCommandExamples
}

struct AppShellStatusItem: Identifiable {
    enum Tone {
        case success
        case warning
        case neutral
    }

    let id = UUID()
    let title: String
    let value: String
    let tone: Tone
}

struct AppShellActionCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: LucideIcon
    let action: AppShellAction
    let accessibilityIdentifier: String
}

final class AppShellViewModel: ObservableObject {
    let tab: AppTab

    init(tab: AppTab) {
        self.tab = tab
    }

    var statusItems: [AppShellStatusItem] {
        switch tab {
        case .apps:
            return [
                AppShellStatusItem(title: "PWA", value: "verified", tone: .success),
                AppShellStatusItem(title: "Gateway", value: "managed", tone: .neutral),
                AppShellStatusItem(title: "Offline", value: "available", tone: .success)
            ]
        case .notifications:
            return [
                AppShellStatusItem(title: "Notifications", value: "history", tone: .success),
                AppShellStatusItem(title: "Groups", value: "enabled", tone: .success),
                AppShellStatusItem(title: "Unread", value: "badge", tone: .neutral)
            ]
        case .settings:
            return [
                AppShellStatusItem(title: "Tools", value: "moved", tone: .success),
                AppShellStatusItem(title: "Debug", value: "settings", tone: .neutral),
                AppShellStatusItem(title: "Links", value: "settings", tone: .neutral)
            ]
        }
    }

    var actionCards: [AppShellActionCard] {
        switch tab {
        case .apps:
            return [
                AppShellActionCard(
                    title: "应用中心",
                    subtitle: "查看已验证 PWA 并在沉浸式容器中打开",
                    icon: .globe,
                    action: .openWebCatalog,
                    accessibilityIdentifier: "apps.openCatalog"
                ),
                AppShellActionCard(
                    title: "缓存仪表盘",
                    subtitle: "查看缓存大小、条目、子系统状态",
                    icon: .hardDrive,
                    action: .openCacheDashboard,
                    accessibilityIdentifier: "web.cacheDashboard"
                ),
                AppShellActionCard(
                    title: "缓存清理",
                    subtitle: "进入收藏和缓存管理，执行清理动作",
                    icon: .trash,
                    action: .openCacheManagement,
                    accessibilityIdentifier: "web.cacheManagement"
                )
            ]
        case .notifications:
            return [
                AppShellActionCard(
                    title: "通知记录",
                    subtitle: "查看推送、待办与审批提醒，并进入目标页面",
                    icon: .bell,
                    action: .openMessageHistory,
                    accessibilityIdentifier: "notifications.history"
                )
            ]
        case .settings:
            return [
                AppShellActionCard(
                    title: "设置",
                    subtitle: "配置服务、安全、缓存、调试和协议工具",
                    icon: .settings,
                    action: .openDiagnostics,
                    accessibilityIdentifier: "settings.open"
                )
            ]
        }
    }
}
