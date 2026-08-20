import SwiftUI
import WebBridgeKit

struct ModuleHeaderView: View {
    let title: String
    let subtitle: String
    let icon: LucideIcon
    let accessibilityIdentifier: String

    init(tab: AppTab) {
        self.title = tab.title
        self.subtitle = tab.subtitle
        self.icon = tab.icon
        self.accessibilityIdentifier = "moduleHeader.\(tab.rawValue)"
    }

    init(title: String, subtitle: String, icon: LucideIcon, accessibilityIdentifier: String) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            HStack(spacing: ThemeTokens.Spacing.md) {
                Image(uiImage: icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.xl) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(Color.appPrimary)
                    .frame(width: ThemeTokens.Icons.Sizes.xxl, height: ThemeTokens.Icons.Sizes.xxl)
                    .background(Color(ThemeTokens.Color.primarySoft))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text(title)
                        .font(Font.app(ThemeTokens.Typography.screenTitle))
                        .foregroundColor(Color.appText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(subtitle)
                        .font(Font.app(ThemeTokens.Typography.body))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
