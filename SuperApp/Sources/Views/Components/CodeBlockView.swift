import SwiftUI
import WebBridgeKit

struct CodeBlockView: View {
    let title: String?
    let text: String
    var maxHeight: CGFloat = 220
    var accessibilityIdentifier: String = "codeBlock"

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
            if let title {
                Text(title)
                    .font(Font.app(ThemeTokens.Typography.sectionTitle))
                    .foregroundColor(Color.appText)
                    .lineLimit(1)
            }

            ScrollView {
                Text(text)
                    .font(Font.app(ThemeTokens.Typography.monospaceBody))
                    .foregroundColor(Color.appText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(ThemeTokens.Spacing.md)
                    .accessibilityIdentifier("\(accessibilityIdentifier).text")
            }
            .frame(maxHeight: maxHeight)
            .background(Color(ThemeTokens.Color.surface))
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md)
                    .stroke(Color.appSeparator, lineWidth: 1)
            )
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
