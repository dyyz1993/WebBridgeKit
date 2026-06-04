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
        case .web:
            return [
                AppShellStatusItem(title: "Backend", value: ":8080", tone: .neutral),
                AppShellStatusItem(title: "Cache", value: "ready", tone: .success),
                AppShellStatusItem(title: "Offline", value: "testable", tone: .success)
            ]
        case .inbox:
            return [
                AppShellStatusItem(title: "Messages", value: "history", tone: .success),
                AppShellStatusItem(title: "Groups", value: "enabled", tone: .success),
                AppShellStatusItem(title: "Unread", value: "badge", tone: .neutral)
            ]
        case .bridge:
            return [
                AppShellStatusItem(title: "Bridge", value: "native", tone: .success),
                AppShellStatusItem(title: "Handlers", value: "grouped", tone: .neutral),
                AppShellStatusItem(title: "Logs", value: "linked", tone: .neutral)
            ]
        case .tokenPush:
            return [
                AppShellStatusItem(title: "Secrets", value: "redacted", tone: .success),
                AppShellStatusItem(title: "Push", value: "device", tone: .warning),
                AppShellStatusItem(title: "Payload", value: "json", tone: .neutral)
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
        case .web:
            return [
                AppShellActionCard(
                    title: "打开网页目录",
                    subtitle: "从预置 URL 开始验证在线打开和缓存入口",
                    icon: .globe,
                    action: .openWebCatalog,
                    accessibilityIdentifier: "web.openCatalog"
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
        case .inbox:
            return [
                AppShellActionCard(
                    title: "消息历史",
                    subtitle: "查看推送消息、按分组折叠、筛选未读并进入消息详情",
                    icon: .inbox,
                    action: .openMessageHistory,
                    accessibilityIdentifier: "inbox.history"
                )
            ]
        case .bridge:
            return [
                AppShellActionCard(
                    title: "Bridge Showcase",
                    subtitle: "暂时复用旧桥接展示页，后续替换为 Bridge Lab",
                    icon: .terminal,
                    action: .openBridgeShowcase,
                    accessibilityIdentifier: "bridge.openShowcase"
                ),
                AppShellActionCard(
                    title: "命令结果规范",
                    subtitle: "Bridge Lab 将在这里展示 JSON、耗时、错误和日志关联",
                    icon: .docText,
                    action: .openCommandExamples,
                    accessibilityIdentifier: "bridge.commandExamples"
                )
            ]
        case .tokenPush:
            return [
                AppShellActionCard(
                    title: "Token 管理",
                    subtitle: "生成、查看、复制和撤销口令",
                    icon: .key,
                    action: .openTokenManager,
                    accessibilityIdentifier: "tokenPush.tokenManager"
                ),
                AppShellActionCard(
                    title: "API Key 管理",
                    subtitle: "管理服务调用密钥和脱敏展示",
                    icon: .shield,
                    action: .openAPIKeyManager,
                    accessibilityIdentifier: "tokenPush.apiKeyManager"
                ),
                AppShellActionCard(
                    title: "推送调试",
                    subtitle: "编辑 payload 并验证本地/服务端推送路径",
                    icon: .bell,
                    action: .openNotificationDebug,
                    accessibilityIdentifier: "tokenPush.notificationDebug"
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
