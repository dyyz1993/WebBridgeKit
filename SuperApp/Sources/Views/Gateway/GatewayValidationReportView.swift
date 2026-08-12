import SwiftUI
import WebBridgeKit

struct GatewayValidationReportView: View {
    let report: HTMLAppGatewayValidationReport
    let activate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(text("gateway.report.title", "验证通过"), systemImage: "checkmark.shield.fill")
                .font(.headline)
                .foregroundColor(Color(ThemeTokens.Color.success))
            reportRow(text("gateway.report.host", "主机"), report.host)
            reportRow(text("gateway.report.health", "健康检查"), report.healthEndpoint)
            reportRow(text("gateway.report.manifest", "应用清单"), report.manifestEndpoint)
            reportRow(text("gateway.report.key", "公钥 ID"), report.publicKeyID ?? text("gateway.report.debug", "开发模式（无签名）"))
            reportRow(text("gateway.report.apps", "发现应用"), "\(report.applicationCount)")

            ForEach(Array(report.checks.enumerated()), id: \.offset) { _, check in
                HStack {
                    Image(systemName: check.status == .passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(check.status == .passed ? Color(ThemeTokens.Color.success) : Color(ThemeTokens.Color.error))
                    Text(check.detail).font(.caption).foregroundColor(Color(ThemeTokens.Color.textSecondary))
                }
            }

            Button(action: activate) {
                Text(text("gateway.activate", "启用此网关"))
                    .font(.headline)
                    .foregroundColor(Color(ThemeTokens.Color.textOnColor))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(ThemeTokens.Color.primary))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("gateway.activate")
        }
        .padding(18)
        .background(Color(ThemeTokens.Color.cardBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("gateway.report")
    }

    private func reportRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundColor(Color(ThemeTokens.Color.textTertiary))
            Text(value).font(.subheadline).foregroundColor(Color(ThemeTokens.Color.text))
        }
    }

    private func text(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }
}
