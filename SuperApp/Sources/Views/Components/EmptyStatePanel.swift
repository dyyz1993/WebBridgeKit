import SwiftUI
import WebBridgeKit

struct EmptyStatePanel: View {
    let title: String
    let message: String
    let icon: LucideIcon
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: ThemeTokens.Spacing.md) {
            Image(uiImage: icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.empty) ?? UIImage())
                .renderingMode(.template)
                .foregroundColor(Color.appTextTertiary)
                .frame(width: 56, height: 56)

            Text(title)
                .font(Font.app(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appText)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(message)
                .font(Font.app(ThemeTokens.Typography.body))
                .foregroundColor(Color.appTextSecondary)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Font.app(ThemeTokens.Typography.button))
                        .foregroundColor(Color(ThemeTokens.Color.onPrimary))
                        .frame(minWidth: 120, minHeight: 44)
                        .padding(.horizontal, ThemeTokens.Spacing.lg)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                }
                .buttonStyle(PressScaleButtonStyle())
                .padding(.top, ThemeTokens.Spacing.sm)
                .accessibilityIdentifier("emptyState.actionButton")
            }
        }
        .padding(ThemeTokens.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card)
                .stroke(Color.appSeparator, lineWidth: 1)
        )
        .accessibilityIdentifier("emptyStatePanel")
    }
}
