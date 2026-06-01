import SwiftUI
import WebBridgeKit

struct TokenPushHomeView: View {
    let onAction: (TokenPushAction) -> Void

    @StateObject private var viewModel = TokenPushHomeViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: ThemeTokens.Spacing.md),
        GridItem(.flexible(), spacing: ThemeTokens.Spacing.md)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xxl) {
                ModuleHeaderView(tab: .tokenPush)
                ServiceStatusStrip(items: viewModel.serviceItems)
                metricSection
                actionSection
                payloadSection
                ResultPanel(
                    title: "校验结果",
                    state: viewModel.resultState,
                    detail: viewModel.resultDetail.isEmpty ? nil : viewModel.resultDetail,
                    copyAction: viewModel.copyPayloadResult
                )
            }
            .padding(.horizontal, ThemeTokens.Spacing.screenHorizontal)
            .padding(.top, ThemeTokens.Spacing.screenTop)
            .padding(.bottom, ThemeTokens.Spacing.screenBottom + 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Token/Push")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: viewModel.refreshSnapshot)
        .accessibilityIdentifier("tokenPush.home")
    }

    private var metricSection: some View {
        LazyVGrid(columns: columns, spacing: ThemeTokens.Spacing.md) {
            MetricTile(
                title: "通知权限",
                value: viewModel.pushAuthorization,
                icon: .bell,
                tone: viewModel.pushAuthorization == "已授权" ? .success : .warning
            )
            MetricTile(
                title: "API Key",
                value: viewModel.apiKeyCount,
                icon: .key,
                tone: .neutral
            )
            MetricTile(
                title: "访问口令",
                value: viewModel.accessTokenCount,
                icon: .lock,
                tone: .neutral
            )
            MetricTile(
                title: "推送地址",
                value: viewModel.barkKeyState,
                icon: .server,
                tone: viewModel.barkKeyState == "已配置" ? .success : .warning
            )
        }
        .accessibilityIdentifier("tokenPush.metricGrid")
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            Text("能力入口")
                .font(Font.app(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appText)

            ActionRow(
                title: "访问口令",
                subtitle: "查看、分享、清理 URL 访问口令",
                icon: .lock,
                accessibilityIdentifier: "tokenPush.openTokenManager",
                badge: viewModel.accessTokenCount,
                badgeTone: .neutral,
                action: { onAction(.openTokenManager) }
            )

            ActionRow(
                title: "Bark API / API Key",
                subtitle: "兼容 Bark 推送 API，管理永久密钥、临时密钥和测试消息",
                icon: .key,
                accessibilityIdentifier: "tokenPush.openAPIKeyManager",
                badge: viewModel.apiKeyCount,
                badgeTone: .neutral,
                action: { onAction(.openAPIKeyManager) }
            )

            ActionRow(
                title: "Bark 推送调试",
                subtitle: "打开通知调试台，验证 Bark payload、权限和本地通知",
                icon: .bell,
                accessibilityIdentifier: "tokenPush.openNotificationDebug",
                badge: "DEBUG",
                badgeTone: .warning,
                action: { onAction(.openNotificationDebug) }
            )

            HStack(spacing: ThemeTokens.Spacing.md) {
                Button(
                    action: viewModel.requestPushRegistration,
                    label: {
                        Text("注册推送")
                            .font(Font.app(ThemeTokens.Typography.button))
                            .foregroundColor(Color(ThemeTokens.Color.onPrimary))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.appPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                    }
                )
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("tokenPush.registerButton")

                Button(
                    action: viewModel.copyPushURL,
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
                .accessibilityIdentifier("tokenPush.copyPushURLButton")
            }

            CodeBlockView(title: "推送地址", text: viewModel.redactedPushURL, maxHeight: 96)
                .accessibilityIdentifier("tokenPush.pushURL")
        }
    }

    private var payloadSection: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            HStack {
                Text("Bark Payload 校验")
                    .font(Font.app(ThemeTokens.Typography.sectionTitle))
                    .foregroundColor(Color.appText)
                Spacer()
                StatusBadge(title: "Route", tone: .info)
            }

            TextEditor(text: $viewModel.payloadText)
                .font(Font.app(ThemeTokens.Typography.monospaceBody))
                .foregroundColor(Color.appText)
                .frame(minHeight: 180)
                .padding(ThemeTokens.Spacing.sm)
                .background(Color(ThemeTokens.Color.surface))
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md)
                        .stroke(Color.appSeparator, lineWidth: 1)
                )
                .accessibilityIdentifier("tokenPush.payloadEditor")

            Button(
                action: viewModel.validatePayload,
                label: {
                    Text("校验 Bark Payload")
                        .font(Font.app(ThemeTokens.Typography.button))
                        .foregroundColor(Color(ThemeTokens.Color.onPrimary))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                }
            )
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityIdentifier("tokenPush.validatePayloadButton")
        }
    }
}
