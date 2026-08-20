import SwiftUI
import WebBridgeKit

struct StatusBadge: View {
    enum Tone {
        case success
        case warning
        case error
        case info
        case offline
        case neutral
    }

    let title: String
    let tone: Tone

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.xs) {
            Circle()
                .fill(foregroundColor)
                .frame(width: 6, height: 6)

            Text(title)
                .font(Font.app(ThemeTokens.Typography.caption))
                .foregroundColor(foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, ThemeTokens.Spacing.md)
        .frame(height: 28)
        .background(backgroundColor)
        .clipShape(Capsule())
        .accessibilityIdentifier("statusBadge.\(title)")
    }

    private var foregroundColor: Color {
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
            return Color.appTextSecondary
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .success:
            return Color(ThemeTokens.Color.successSoft)
        case .warning:
            return Color(ThemeTokens.Color.warningSoft)
        case .error:
            return Color(ThemeTokens.Color.errorSoft)
        case .info:
            return Color(ThemeTokens.Color.infoSoft)
        case .offline:
            return Color(ThemeTokens.Color.offlineSoft)
        case .neutral:
            return Color(ThemeTokens.Color.surface)
        }
    }
}
