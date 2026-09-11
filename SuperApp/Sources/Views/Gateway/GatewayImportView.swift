import SwiftUI
import WebBridgeKit

struct GatewayImportView: View {
    @ObservedObject var viewModel: GatewayManagementViewModel
    let scan: () -> Void
    let paste: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.lg) {
                selfHostedIntro
                currentGateway
                importActions
                input
                feedback
                savedGateways
            }
            .padding(ThemeTokens.Spacing.screenHorizontal)
        }
        .background(Color(ThemeTokens.Color.background).ignoresSafeArea())
        .alert(isPresented: Binding(
                get: { viewModel.gatewayPendingRemoval != nil },
                set: { if !$0 { viewModel.gatewayPendingRemoval = nil } }
            )) {
            Alert(
                title: Text(text("gateway.remove.title", "移除网关？")),
                message: Text(text("gateway.remove.message", "此网关的应用信任和能力授权也会被清除。")),
                primaryButton: .destructive(Text(text("gateway.remove", "移除"))) { viewModel.confirmRemoval() },
                secondaryButton: .cancel(Text(text("gateway.cancel", "取消")))
            )
        }
    }

    private var selfHostedIntro: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
            Text("连接自有服务")
                .font(Font.app(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appText)
            Text("Drel 官方服务已默认可用。仅在你部署兼容服务时，才需要导入此配置。")
                .font(Font.app(ThemeTokens.Typography.metadata))
                .foregroundColor(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("gateway.selfHostedIntro")
    }

    private var currentGateway: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
            Text(text("gateway.current.title", "当前网关"))
                .font(Font.app(ThemeTokens.Typography.metadata))
                .foregroundColor(Color.appTextSecondary)
            if let active = viewModel.gateways.first(where: { $0.id == viewModel.activeGatewayID }) {
                Text(active.name)
                    .font(Font.app(ThemeTokens.Typography.rowTitle))
                    .foregroundColor(Color.appText)
                Text(active.baseURL)
                    .font(Font.app(ThemeTokens.Typography.monospaceMeta))
                    .foregroundColor(Color.appTextSecondary)
            } else {
                Text(text("gateway.current.none", "未启用自有服务"))
                    .font(Font.app(ThemeTokens.Typography.metadata))
                    .foregroundColor(Color.appTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ThemeTokens.Spacing.md)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card)
                .stroke(Color.appSeparator, lineWidth: 1)
        )
        .accessibilityIdentifier("gateway.current")
    }

    private var importActions: some View {
        HStack(spacing: ThemeTokens.Spacing.sm) {
            actionButton(text("gateway.scan", "扫描二维码"), icon: .scan, id: "gateway.scan", action: scan)
            actionButton(text("gateway.paste", "粘贴配置"), icon: .clipboard, id: "gateway.paste", action: paste)
        }
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
            Text(text("gateway.input.title", "JSON 或 webbridgekit://gateway"))
                .font(Font.app(ThemeTokens.Typography.rowTitle))
                .foregroundColor(Color.appText)
            TextEditor(text: $viewModel.payload)
                .font(.system(size: ThemeTokens.Typography.monospaceMeta.pointSize, design: .monospaced))
                .foregroundColor(Color.appText)
                .frame(minHeight: ThemeTokens.ComponentContract.ResourceCard.maxHeight)
                .padding(ThemeTokens.Spacing.sm)
                .background(Color.appBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                .accessibilityIdentifier("gateway.input")
            let isPayloadEmpty = viewModel.payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button(text("gateway.validate", "验证配置")) { viewModel.validatePayload() }
                .font(Font.app(ThemeTokens.Typography.button))
                // A plain .disabled left the button painted in full primary
                // colors, reading as tappable on an empty form.
                .foregroundColor(isPayloadEmpty
                    ? Color(ThemeTokens.Color.textTertiary)
                    : Color(ThemeTokens.Color.onPrimary))
                .frame(maxWidth: .infinity, minHeight: ThemeTokens.ComponentContract.Button.height)
                .background(isPayloadEmpty ? Color.appPrimary.opacity(0.35) : Color.appPrimary)
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                .buttonStyle(PlainButtonStyle())
                .disabled(isPayloadEmpty)
                .accessibilityIdentifier("gateway.validate")
        }
        .padding(ThemeTokens.Spacing.md)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card)
                .stroke(Color.appSeparator, lineWidth: 1)
        )
    }

    @ViewBuilder private var feedback: some View {
        switch viewModel.phase {
        case .idle: EmptyView()
        case .validating:
            HStack(spacing: ThemeTokens.Spacing.sm) {
                ProgressView()
                Text(text("gateway.validating", "正在验证健康状态、来源和签名…"))
            }
            .font(Font.app(ThemeTokens.Typography.metadata))
            .foregroundColor(Color.appTextSecondary)
        case .report:
            if let report = viewModel.report {
                GatewayValidationReportView(report: report, activate: viewModel.activateReport)
            }
        case .activated(let name):
            statusCard(.success, Color(ThemeTokens.Color.success), String(format: text("gateway.activated", "%@ 已启用"), name))
        case .error(let message):
            statusCard(.warning, Color(ThemeTokens.Color.error), message)
                .accessibilityIdentifier("gateway.error")
        }
    }

    private var savedGateways: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
            Text(text("gateway.saved", "已保存网关"))
                .font(Font.app(ThemeTokens.Typography.rowTitle))
                .foregroundColor(Color.appText)
            ForEach(viewModel.gateways) { gateway in
                HStack(spacing: ThemeTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                        Text(gateway.name)
                            .font(Font.app(ThemeTokens.Typography.rowTitle))
                            .foregroundColor(Color.appText)
                        Text(gateway.baseURL)
                            .font(Font.app(ThemeTokens.Typography.monospaceMeta))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    Spacer()
                    if gateway.id != viewModel.activeGatewayID {
                        Button(text("gateway.switch", "验证并切换")) { viewModel.validate(gateway) }
                            .font(Font.app(ThemeTokens.Typography.metadata))
                            .foregroundColor(Color.appPrimary)
                    }
                    Button(
                        action: { viewModel.requestRemoval(gateway) },
                        label: {
                            Image(uiImage: LucideIcon.trash.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm) ?? UIImage())
                                .renderingMode(.template)
                                .foregroundColor(Color.appError)
                                .frame(width: ThemeTokens.ComponentContract.TapTarget.minimumWidth, height: ThemeTokens.ComponentContract.TapTarget.minimumHeight)
                        }
                    )
                        .accessibilityIdentifier("gateway.remove")
                }
                .padding(.vertical, ThemeTokens.Spacing.sm)
            }
        }
    }

    private func actionButton(_ title: String, icon: LucideIcon, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ThemeTokens.Spacing.sm) {
                Image(uiImage: icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm) ?? UIImage())
                    .renderingMode(.template)
                Text(title)
            }
            .font(Font.app(ThemeTokens.Typography.button))
            .foregroundColor(Color.appPrimary)
            .frame(maxWidth: .infinity, minHeight: ThemeTokens.ComponentContract.Button.height)
            .background(Color(ThemeTokens.Color.primarySoft))
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(id)
    }

    private func statusCard(_ icon: LucideIcon, _ color: Color, _ message: String) -> some View {
        HStack(alignment: .top, spacing: ThemeTokens.Spacing.sm) {
            Image(uiImage: icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm) ?? UIImage())
                .renderingMode(.template)
                .foregroundColor(color)
            Text(message)
                .font(Font.app(ThemeTokens.Typography.metadata))
                .foregroundColor(Color.appText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ThemeTokens.Spacing.md)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
    }

    private func text(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }
}
