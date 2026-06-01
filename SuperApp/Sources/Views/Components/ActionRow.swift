import SwiftUI
import WebBridgeKit

struct ActionRow: View {
    let title: String
    let subtitle: String
    let icon: LucideIcon
    let accessibilityIdentifier: String
    var badge: String?
    var badgeTone: StatusBadge.Tone = .neutral
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ThemeTokens.Spacing.md) {
                Image(uiImage: icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.md) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(Color.appPrimary)
                    .frame(
                        width: ThemeTokens.ComponentContract.SettingsRow.iconBox,
                        height: ThemeTokens.ComponentContract.SettingsRow.iconBox
                    )
                    .background(Color(ThemeTokens.Color.primarySoft))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.sm))

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    HStack(spacing: ThemeTokens.Spacing.sm) {
                        Text(title)
                            .font(Font.app(ThemeTokens.Typography.rowTitle))
                            .foregroundColor(Color.appText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        if let badge {
                            StatusBadge(title: badge, tone: badgeTone)
                        }
                    }

                    Text(subtitle)
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
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
