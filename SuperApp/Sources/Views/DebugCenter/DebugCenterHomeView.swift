import SwiftUI
import WebBridgeKit

struct DebugCenterHomeView: View {
    let onAction: (DebugCenterAction) -> Void

    @StateObject private var viewModel = DebugCenterViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: ThemeTokens.Spacing.md),
        GridItem(.flexible(), spacing: ThemeTokens.Spacing.md)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xxl) {
                ModuleHeaderView(
                    title: "Debug",
                    subtitle: "日志、网络、缓存、崩溃与诊断导出",
                    icon: .bug,
                    accessibilityIdentifier: "moduleHeader.debug"
                )
                ServiceStatusStrip(items: viewModel.serviceItems)
                metricSection
                actionSection
                ResultPanel(
                    title: "诊断摘要",
                    state: viewModel.resultState,
                    detail: viewModel.resultDetail.isEmpty ? nil : viewModel.resultDetail,
                    copyAction: viewModel.copyDiagnosticSummary
                )
            }
            .padding(.horizontal, ThemeTokens.Spacing.screenHorizontal)
            .padding(.top, ThemeTokens.Spacing.screenTop)
            .padding(.bottom, ThemeTokens.Spacing.screenBottom + 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: viewModel.refresh)
        .accessibilityIdentifier("debugCenter.home")
    }

    private var metricSection: some View {
        LazyVGrid(columns: columns, spacing: ThemeTokens.Spacing.md) {
            MetricTile(
                title: "日志",
                value: viewModel.logCount,
                icon: .docText,
                tone: .neutral
            )
            MetricTile(
                title: "错误",
                value: viewModel.errorCount,
                icon: .error,
                tone: viewModel.errorCount == "0" ? .success : .error
            )
            MetricTile(
                title: "警告",
                value: viewModel.warningCount,
                icon: .warning,
                tone: viewModel.warningCount == "0" ? .success : .warning
            )
            MetricTile(
                title: "崩溃",
                value: viewModel.crashCount,
                icon: .bug,
                tone: viewModel.crashCount == "0" ? .success : .error
            )
        }
        .accessibilityIdentifier("debugCenter.metricGrid")
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            Text("调试工具")
                .font(Font.app(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appText)

            ActionRow(
                title: "全局调试面板",
                subtitle: "Handlers、通知、日志、环境、缓存、网络、Manifest 用例集合",
                icon: .terminal,
                accessibilityIdentifier: "debugCenter.openDebugPanel",
                badge: "DEBUG",
                badgeTone: .warning,
                action: { onAction(.openDebugPanel) }
            )

            ActionRow(
                title: "诊断导出",
                subtitle: "导出系统信息、崩溃日志、命令历史并自动脱敏",
                icon: .download,
                accessibilityIdentifier: "debugCenter.openDiagnostics",
                action: { onAction(.openDiagnostics) }
            )

            ActionRow(
                title: "网络请求",
                subtitle: "查看最近网络请求、状态码和耗时",
                icon: .network,
                accessibilityIdentifier: "debugCenter.openNetworkInspector",
                badge: viewModel.networkCount,
                badgeTone: .neutral,
                action: { onAction(.openNetworkInspector) }
            )

            ActionRow(
                title: "缓存仪表盘",
                subtitle: "进入缓存子系统统计、清理和明细页面",
                icon: .hardDrive,
                accessibilityIdentifier: "debugCenter.openCacheDashboard",
                action: { onAction(.openCacheDashboard) }
            )

            ActionRow(
                title: "Manifest 缓存用例",
                subtitle: "验证 persistent、lazy、离线 fallback 和更新路径",
                icon: .clipboard,
                accessibilityIdentifier: "debugCenter.openManifestCacheTests",
                badge: "Cases",
                badgeTone: .info,
                action: { onAction(.openManifestCacheTests) }
            )

            ActionRow(
                title: "网页缓存调试",
                subtitle: "手动打开 URL，验证缓存策略、离线模式和清理流程",
                icon: .globe,
                accessibilityIdentifier: "debugCenter.openWebCache",
                badge: "DEBUG",
                badgeTone: .warning,
                action: { onAction(.openWebCache) }
            )

            ActionRow(
                title: "Bridge 实验室",
                subtitle: "执行 JSBridge 命令，检查参数、回调和日志",
                icon: .terminal,
                accessibilityIdentifier: "debugCenter.openBridgeLab",
                badge: "DEBUG",
                badgeTone: .warning,
                action: { onAction(.openBridgeLab) }
            )

            ActionRow(
                title: "Push 与 Bark 调试",
                subtitle: "管理测试 Token、Bark payload 和通知模拟",
                icon: .bell,
                accessibilityIdentifier: "debugCenter.openPushTools",
                badge: "DEBUG",
                badgeTone: .warning,
                action: { onAction(.openPushTools) }
            )

            HStack(spacing: ThemeTokens.Spacing.md) {
                Button(
                    action: viewModel.showCrashScanGuide,
                    label: {
                        Text("崩溃扫描说明")
                            .font(Font.app(ThemeTokens.Typography.button))
                            .foregroundColor(Color.appText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color(ThemeTokens.Color.surface))
                            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                    }
                )
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("debugCenter.crashGuideButton")

                Button(
                    action: viewModel.copyCrashScanCommand,
                    label: {
                        Image(uiImage: LucideIcon.copy.templateImage(pointSize: ThemeTokens.Icons.Sizes.md) ?? UIImage())
                            .renderingMode(.template)
                            .foregroundColor(Color.appText)
                            .frame(width: 52, height: 44)
                            .background(Color(ThemeTokens.Color.surface))
                            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                    }
                )
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("debugCenter.copyCrashCommandButton")
            }
        }
    }
}
