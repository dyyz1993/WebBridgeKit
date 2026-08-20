#if DEBUG
import SwiftUI
import WebBridgeKit

struct WebCacheModePicker: View {
    @Binding var selection: WebCacheMode

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
            Text("缓存模式")
                .font(Font.app(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appText)

            Picker("缓存模式", selection: $selection) {
                ForEach(WebCacheMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .accessibilityIdentifier("webCache.modePicker")

            Text(selection.subtitle)
                .font(Font.app(ThemeTokens.Typography.metadata))
                .foregroundColor(Color.appTextSecondary)
                .lineLimit(2)
        }
    }
}

#endif
