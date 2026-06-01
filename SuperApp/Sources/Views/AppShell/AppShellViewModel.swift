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
        case .debug:
            return [
                AppShellStatusItem(title: "Crash", value: "scan", tone: .neutral),
                AppShellStatusItem(title: "Network", value: "inspect", tone: .neutral),
                AppShellStatusItem(title: "Export", value: "redact", tone: .success)
            ]
        case .links:
            return [
                AppShellStatusItem(title: "Scheme", value: "webbridgekit", tone: .success),
                AppShellStatusItem(title: "Params", value: "visible", tone: .neutral),
                AppShellStatusItem(title: "History", value: "planned", tone: .warning)
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
        case .debug:
            return [
                AppShellActionCard(
                    title: "Debug Panel",
                    subtitle: "打开旧调试面板，后续迁移为 Debug Center",
                    icon: .bug,
                    action: .openDebugPanel,
                    accessibilityIdentifier: "debug.openPanel"
                ),
                AppShellActionCard(
                    title: "诊断导出",
                    subtitle: "查看环境、日志和诊断包导出入口",
                    icon: .download,
                    action: .openDiagnostics,
                    accessibilityIdentifier: "debug.openDiagnostics"
                )
            ]
        case .links:
            return [
                AppShellActionCard(
                    title: "协议跳转模板",
                    subtitle: "查看 webbridgekit://open 与 command URL 示例",
                    icon: .link,
                    action: .openDeepLinkExamples,
                    accessibilityIdentifier: "links.examples"
                ),
                AppShellActionCard(
                    title: "命令路由说明",
                    subtitle: "后续在此编辑参数、执行并保留历史",
                    icon: .clipboard,
                    action: .openCommandExamples,
                    accessibilityIdentifier: "links.commandExamples"
                )
            ]
        }
    }
}
