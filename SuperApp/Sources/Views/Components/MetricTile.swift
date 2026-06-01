import SwiftUI
import WebBridgeKit

struct MetricTile: View {
    let title: String
    let value: String
    let icon: LucideIcon
    var tone: StatusBadge.Tone = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
            HStack {
                Image(uiImage: icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)

                Spacer()
            }

            Text(value)
                .font(Font.app(ThemeTokens.Typography.compactTitle))
                .foregroundColor(Color.appText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(Font.app(ThemeTokens.Typography.caption))
                .foregroundColor(Color.appTextSecondary)
                .lineLimit(1)
        }
        .padding(ThemeTokens.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card)
                .stroke(Color.appSeparator, lineWidth: 1)
        )
        .accessibilityIdentifier("metricTile.\(title)")
    }

    private var iconColor: Color {
        switch tone {
        case .success:
            return Color(ThemeTokens.Color.success)
        case .warning:
            return Color(ThemeTokens.Color.warning)
        case .error:
            return Color(ThemeTokens.Color.error)
        case .info:
            return Color(ThemeTokens.Color.info)
        case .offline:
            return Color(ThemeTokens.Color.offline)
        case .neutral:
            return Color.appPrimary
        }
    }
}
