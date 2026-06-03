import SwiftUI
import WebBridgeKit

struct BridgeLabHomeView: View {
    let onAction: (BridgeLabAction) -> Void

    @StateObject private var viewModel = BridgeLabViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xxl) {
                ModuleHeaderView(tab: .bridge)
                ServiceStatusStrip(items: serviceItems)
                groupSection
                commandSection
                parameterSection
                actionSection
                ResultPanel(
                    title: "执行结果",
                    state: viewModel.resultState,
                    accessibilityIdentifier: "bridge.resultPanel",
                    detail: viewModel.resultDetail.isEmpty ? nil : viewModel.resultDetail,
                    copyAction: viewModel.copyResult
                )
            }
            .padding(.horizontal, ThemeTokens.Spacing.screenHorizontal)
            .padding(.top, ThemeTokens.Spacing.screenTop)
            .padding(.bottom, ThemeTokens.Spacing.screenBottom + 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Bridge")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("bridgeLab.home")
    }

    private var serviceItems: [AppShellStatusItem] {
        [
            AppShellStatusItem(title: "Bridge", value: "JS", tone: .success),
            AppShellStatusItem(title: "Handlers", value: "\(viewModel.groups.count)", tone: .neutral),
            AppShellStatusItem(title: "Result", value: "JSON", tone: .neutral)
        ]
    }

    private var groupSection: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            Text("Handler 分组")
                .font(Font.app(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ThemeTokens.Spacing.sm) {
                    ForEach(viewModel.groups) { group in
                        Button(
                            action: { viewModel.selectGroup(group) },
                            label: {
                                HStack(spacing: ThemeTokens.Spacing.xs) {
                                    Image(uiImage: group.icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm) ?? UIImage())
                                        .renderingMode(.template)
                                    Text(group.title)
                                        .font(Font.app(ThemeTokens.Typography.buttonMedium))
                                }
                                .foregroundColor(group.id == viewModel.selectedGroupID ? Color(ThemeTokens.Color.onPrimary) : Color.appText)
                                .padding(.horizontal, ThemeTokens.Spacing.md)
                                .frame(height: 36)
                                .background(group.id == viewModel.selectedGroupID ? Color.appPrimary : Color(ThemeTokens.Color.surface))
                                .clipShape(Capsule())
                            }
                        )
                        .buttonStyle(PressScaleButtonStyle())
                        .accessibilityIdentifier("bridge.group.\(group.id)")
                    }
                }
            }
            .accessibilityIdentifier("bridge.groupList")
        }
    }

    private var commandSection: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            Text("命令")
                .font(Font.app(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appText)

            ForEach(viewModel.selectedGroup?.commands ?? []) { command in
                ActionRow(
                    title: command.title,
                    subtitle: "\(command.handler) · \(command.summary)",
                    icon: viewModel.selectedGroup?.icon ?? .terminal,
                    accessibilityIdentifier: "bridge.command.\(command.id)",
                    badge: command.id == viewModel.selectedCommandID ? "Selected" : nil,
                    badgeTone: .success,
                    action: { viewModel.selectCommand(command) }
                )
            }
        }
        .accessibilityIdentifier("bridge.commandList")
    }

    private var parameterSection: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            Text("参数 JSON")
                .font(Font.app(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appText)

            TextEditor(text: $viewModel.parameterText)
                .font(Font.app(ThemeTokens.Typography.monospaceBody))
                .foregroundColor(Color.appText)
                .frame(minHeight: 140)
                .padding(ThemeTokens.Spacing.sm)
                .background(Color(ThemeTokens.Color.surface))
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md)
                        .stroke(Color.appSeparator, lineWidth: 1)
                )
                .accessibilityIdentifier("bridge.parameterEditor")
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            HStack(spacing: ThemeTokens.Spacing.md) {
                Button(action: viewModel.executeSelectedCommand) {
                    Text("执行校验")
                        .font(Font.app(ThemeTokens.Typography.button))
                        .foregroundColor(Color(ThemeTokens.Color.onPrimary))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("bridge.executeButton")

                Button(
                    action: { onAction(.openDebugLogs) },
                    label: {
                        Text("日志")
                            .font(Font.app(ThemeTokens.Typography.button))
                            .foregroundColor(Color.appText)
                            .frame(width: 76, height: 44)
                            .background(Color(ThemeTokens.Color.surface))
                            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                    }
                )
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("bridge.openLogsButton")
            }

            ActionRow(
                title: "旧 Bridge Showcase",
                subtitle: "过渡期入口，真实 Bridge Lab 完成后可移除",
                icon: .terminal,
                accessibilityIdentifier: "bridge.openLegacyShowcase",
                badge: "Legacy",
                badgeTone: .warning,
                action: { onAction(.openLegacyShowcase) }
            )
        }
    }
}
