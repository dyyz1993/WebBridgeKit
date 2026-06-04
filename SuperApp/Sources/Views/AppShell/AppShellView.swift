import SwiftUI
import WebBridgeKit

struct AppShellView: View {
    let onAction: (AppShellAction) -> Void

    @StateObject private var viewModel: AppShellViewModel

    init(tab: AppTab, onAction: @escaping (AppShellAction) -> Void) {
        self.onAction = onAction
        _viewModel = StateObject(wrappedValue: AppShellViewModel(tab: tab))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xxl) {
                ModuleHeaderView(tab: viewModel.tab)
                ServiceStatusStrip(items: viewModel.statusItems)

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
                    Text("核心操作")
                        .font(Font.app(ThemeTokens.Typography.sectionTitle))
                        .foregroundColor(Color.appText)
                        .lineLimit(1)

                    ForEach(viewModel.actionCards) { card in
                        AppShellActionCardView(card: card) {
                            onAction(card.action)
                        }
                    }
                }

                AppShellMigrationNotice(tab: viewModel.tab)
            }
            .padding(.horizontal, ThemeTokens.Spacing.screenHorizontal)
            .padding(.top, ThemeTokens.Spacing.screenTop)
            .padding(.bottom, ThemeTokens.Spacing.screenBottom + 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(viewModel.tab.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("appShell.\(viewModel.tab.rawValue)")
    }
}

private struct AppShellActionCardView: View {
    let card: AppShellActionCard
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ThemeTokens.Spacing.md) {
                Image(uiImage: card.icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.md) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(Color.appPrimary)
                    .frame(
                        width: ThemeTokens.ComponentContract.SettingsRow.iconBox,
                        height: ThemeTokens.ComponentContract.SettingsRow.iconBox
                    )
                    .background(Color(ThemeTokens.Color.primarySoft))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.sm))

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text(card.title)
                        .font(Font.app(ThemeTokens.Typography.rowTitle))
                        .foregroundColor(Color.appText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(card.subtitle)
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: ThemeTokens.Spacing.sm)

                Image(uiImage: LucideIcon.chevronRight.templateImage(pointSize: ThemeTokens.Icons.Sizes.chevron) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(Color.appTextTertiary)
                    .frame(width: 24, height: 24)
            }
            .padding(ThemeTokens.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card)
                    .stroke(Color.appSeparator, lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityIdentifier(card.accessibilityIdentifier)
    }
}

private struct AppShellMigrationNotice: View {
    let tab: AppTab

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
            Text("UI v4 迁移状态")
                .font(Font.app(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appText)
                .lineLimit(1)

            Text(statusText)
                .font(Font.app(ThemeTokens.Typography.body))
                .foregroundColor(Color.appTextSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ThemeTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(ThemeTokens.Color.infoSoft))
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card))
        .accessibilityIdentifier("appShell.migrationNotice.\(tab.rawValue)")
    }

    private var statusText: String {
        switch tab {
        case .web:
            return "当前先接入旧缓存页，下一步替换为完整 Web Cache Home。"
        case .inbox:
            return "消息历史已作为主导航能力，承载推送历史、分组、未读和路由。"
        case .bridge:
            return "当前先接入旧 Bridge Showcase，下一步替换为可执行 Bridge Lab。"
        case .tokenPush:
            return "当前集中 Token 和推送入口，下一步补 payload composer。"
        case .settings:
            return "Debug 和协议工具已收纳到设置页，底部主导航只保留核心能力。"
        }
    }
}
