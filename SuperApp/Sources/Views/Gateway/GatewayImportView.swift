import SwiftUI
import WebBridgeKit

struct GatewayImportView: View {
    @ObservedObject var viewModel: GatewayManagementViewModel
    let scan: () -> Void
    let paste: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                currentGateway
                importActions
                input
                feedback
                savedGateways
            }
            .padding(16)
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

    private var currentGateway: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text("gateway.current.title", "当前网关")).font(.caption).foregroundColor(Color(ThemeTokens.Color.textSecondary))
            if let active = viewModel.gateways.first(where: { $0.id == viewModel.activeGatewayID }) {
                Text(active.name).font(.headline).foregroundColor(Color(ThemeTokens.Color.text))
                Text(active.baseURL).font(.caption).foregroundColor(Color(ThemeTokens.Color.textSecondary))
            } else {
                Text(text("gateway.current.none", "未启用自有服务"))
                    .foregroundColor(Color(ThemeTokens.Color.textSecondary))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(ThemeTokens.Color.cardBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("gateway.current")
    }

    private var importActions: some View {
        HStack(spacing: 12) {
            actionButton(text("gateway.scan", "扫描二维码"), icon: "qrcode.viewfinder", id: "gateway.scan", action: scan)
            actionButton(text("gateway.paste", "粘贴配置"), icon: "doc.on.clipboard", id: "gateway.paste", action: paste)
        }
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text("gateway.input.title", "JSON 或 webbridgekit://gateway"))
                .font(.subheadline).foregroundColor(Color(ThemeTokens.Color.text))
            TextEditor(text: $viewModel.payload)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Color(ThemeTokens.Color.text))
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(ThemeTokens.Color.backgroundSecondary))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("gateway.input")
            Button(text("gateway.validate", "验证配置")) { viewModel.validatePayload() }
                .font(.headline)
                .foregroundColor(Color(ThemeTokens.Color.textOnColor))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(ThemeTokens.Color.primary))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("gateway.validate")
        }
        .padding(18)
        .background(Color(ThemeTokens.Color.cardBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private var feedback: some View {
        switch viewModel.phase {
        case .idle: EmptyView()
        case .validating:
            HStack { ProgressView(); Text(text("gateway.validating", "正在验证健康状态、来源和签名…")) }
                .foregroundColor(Color(ThemeTokens.Color.textSecondary))
        case .report:
            if let report = viewModel.report {
                GatewayValidationReportView(report: report, activate: viewModel.activateReport)
            }
        case .activated(let name):
            statusCard("checkmark.circle.fill", Color(ThemeTokens.Color.success), String(format: text("gateway.activated", "%@ 已启用"), name))
        case .error(let message):
            statusCard("exclamationmark.triangle.fill", Color(ThemeTokens.Color.error), message)
                .accessibilityIdentifier("gateway.error")
        }
    }

    private var savedGateways: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text("gateway.saved", "已保存网关")).font(.headline).foregroundColor(Color(ThemeTokens.Color.text))
            ForEach(viewModel.gateways) { gateway in
                HStack {
                    VStack(alignment: .leading) {
                        Text(gateway.name).foregroundColor(Color(ThemeTokens.Color.text))
                        Text(gateway.baseURL).font(.caption).foregroundColor(Color(ThemeTokens.Color.textSecondary))
                    }
                    Spacer()
                    if gateway.id != viewModel.activeGatewayID {
                        Button(text("gateway.switch", "验证并切换")) { viewModel.validate(gateway) }
                    }
                    Button(
                        action: { viewModel.requestRemoval(gateway) },
                        label: { Image(systemName: "trash").foregroundColor(Color(ThemeTokens.Color.error)) }
                    )
                        .accessibilityIdentifier("gateway.remove")
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func actionButton(_ title: String, icon: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .foregroundColor(Color(ThemeTokens.Color.primary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(ThemeTokens.Color.primarySoft))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(id)
    }

    private func statusCard(_ icon: String, _ color: Color, _ message: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon).foregroundColor(color)
            Text(message).foregroundColor(Color(ThemeTokens.Color.text)).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(ThemeTokens.Color.cardBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func text(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }
}
