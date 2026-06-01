import SwiftUI
import WebBridgeKit

struct ServiceStatusStrip: View {
    let items: [AppShellStatusItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ThemeTokens.Spacing.sm) {
                ForEach(items) { item in
                    HStack(spacing: ThemeTokens.Spacing.xs) {
                        Circle()
                            .fill(color(for: item.tone))
                            .frame(width: 7, height: 7)

                        Text(item.title)
                            .font(Font.app(ThemeTokens.Typography.caption))
                            .foregroundColor(Color.appTextSecondary)
                            .lineLimit(1)

                        Text(item.value)
                            .font(Font.app(ThemeTokens.Typography.caption))
                            .foregroundColor(Color.appText)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, ThemeTokens.Spacing.md)
                    .frame(height: 32)
                    .background(Color(ThemeTokens.Color.surface))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.appSeparator, lineWidth: 1)
                    )
                }
            }
            .padding(.vertical, ThemeTokens.Spacing.xxs)
        }
        .accessibilityIdentifier("serviceStatusStrip")
    }

    private func color(for tone: AppShellStatusItem.Tone) -> Color {
        switch tone {
        case .success:
            return Color(ThemeTokens.Color.success)
        case .warning:
            return Color(ThemeTokens.Color.warning)
        case .neutral:
            return Color.appTextTertiary
        }
    }
}
