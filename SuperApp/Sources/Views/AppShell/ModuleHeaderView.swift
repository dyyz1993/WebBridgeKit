import SwiftUI
import WebBridgeKit

struct ModuleHeaderView: View {
    let tab: AppTab

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            HStack(spacing: ThemeTokens.Spacing.md) {
                Image(uiImage: tab.icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.xl) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(Color.appPrimary)
                    .frame(width: ThemeTokens.Icons.Sizes.xxl, height: ThemeTokens.Icons.Sizes.xxl)
                    .background(Color(ThemeTokens.Color.primarySoft))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text(tab.title)
                        .font(Font.app(ThemeTokens.Typography.screenTitle))
                        .foregroundColor(Color.appText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(tab.subtitle)
                        .font(Font.app(ThemeTokens.Typography.body))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("moduleHeader.\(tab.rawValue)")
    }
}
