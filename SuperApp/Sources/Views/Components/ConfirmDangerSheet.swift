import SwiftUI
import WebBridgeKit

struct ConfirmDangerSheet: View {
    let title: String
    let message: String
    let confirmTitle: String
    let onConfirm: () -> Void

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xxl) {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
                StatusBadge(title: "Danger", tone: .error)

                Text(title)
                    .font(Font.app(ThemeTokens.Typography.compactTitle))
                    .foregroundColor(Color.appText)
                    .lineLimit(2)

                Text(message)
                    .font(Font.app(ThemeTokens.Typography.body))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: ThemeTokens.Spacing.md) {
                Button(
                    action: { presentationMode.wrappedValue.dismiss() },
                    label: {
                        Text("取消")
                            .font(Font.app(ThemeTokens.Typography.button))
                            .foregroundColor(Color.appText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color(ThemeTokens.Color.surface))
                            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                    }
                )
                .accessibilityIdentifier("dangerSheet.cancelButton")

                Button(
                    action: {
                        onConfirm()
                        presentationMode.wrappedValue.dismiss()
                    },
                    label: {
                        Text(confirmTitle)
                            .font(Font.app(ThemeTokens.Typography.button))
                            .foregroundColor(Color(ThemeTokens.Color.textOnColor))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color(ThemeTokens.Color.error))
                            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                    }
                )
                .accessibilityIdentifier("dangerSheet.confirmButton")
            }
        }
        .padding(ThemeTokens.Spacing.xxl)
        .background(Color.appBackground.ignoresSafeArea())
        .accessibilityIdentifier("confirmDangerSheet")
    }
}
