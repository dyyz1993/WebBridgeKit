import SwiftUI
import WebBridgeKit

/// A native rendition of an iOS notification banner for the example cards.
/// This is WebBridgeKit's counterpart to Bark's static preview screenshots —
/// theme-aware, brand-correct, and crisp in both appearances.
struct NotificationMockBanner: View {
    var title: String
    var bodyText: String
    var iconURL: URL?
    var alertStyle = false
    var timeText = "现在"

    @State private var remoteIcon: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
            HStack(spacing: ThemeTokens.Spacing.xs) {
                iconView
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text("WebBridgeKit")
                    .font(Font.app(ThemeTokens.Typography.metadata))
                    .foregroundColor(Color.appTextSecondary)
                Spacer()
                Text(timeText)
                    .font(Font.app(ThemeTokens.Typography.metadata))
                    .foregroundColor(Color.appTextTertiary)
            }

            Text(title)
                .font(.system(size: ThemeTokens.Typography.rowTitle.pointSize, weight: .semibold))
                .foregroundColor(alertStyle ? Color(ThemeTokens.Color.error) : Color.appText)

            Text(bodyText)
                .font(Font.app(ThemeTokens.Typography.footnote))
                .foregroundColor(Color.appText)
        }
        .padding(ThemeTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(ThemeTokens.Color.surfaceElevated))
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.lg)
                .strokeBorder(
                    alertStyle
                        ? Color(ThemeTokens.Color.error).opacity(0.5)
                        : Color(ThemeTokens.Color.border),
                    lineWidth: 1
                )
        )
        .onAppear(perform: loadRemoteIconIfNeeded)
    }

    @ViewBuilder
    private var iconView: some View {
        if let remoteIcon {
            Image(uiImage: remoteIcon)
                .resizable()
                .scaledToFill()
        } else {
            Image(uiImage: LucideIcon.appFill.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm) ?? UIImage())
                .renderingMode(.template)
                .foregroundColor(alertStyle ? Color(ThemeTokens.Color.error) : Color.appPrimary)
                .padding(2)
                .background(Color(ThemeTokens.Color.primarySoft))
        }
    }

    private func loadRemoteIconIfNeeded() {
        guard remoteIcon == nil, let iconURL else { return }
        DispatchQueue.global().async {
            guard let data = try? Data(contentsOf: iconURL), let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                remoteIcon = image
            }
        }
    }
}

/// Renders the preview treatment a card asks for — Bark ships static
/// screenshots for its icon/group/critical/copy cards; these are the native
/// equivalents.
struct NotificationExamplePreview: View {
    let preview: PushExample.Preview

    var body: some View {
        switch preview {
        case let .banner(title, bodyText, iconURL, alertStyle):
            NotificationMockBanner(
                title: title,
                bodyText: bodyText,
                iconURL: iconURL,
                alertStyle: alertStyle
            )

        case let .grouped(groupName, count, title, bodyText):
            VStack(spacing: ThemeTokens.Spacing.sm) {
                NotificationMockBanner(title: title, bodyText: bodyText)
                HStack(spacing: ThemeTokens.Spacing.xs) {
                    Image(uiImage: LucideIcon.folder.templateImage(pointSize: ThemeTokens.Icons.Sizes.xs) ?? UIImage())
                        .renderingMode(.template)
                        .foregroundColor(Color.appTextSecondary)
                    Text("\(groupName) · 还有 \(count - 1) 条通知已折叠")
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ThemeTokens.Spacing.xs)
                .background(Color(ThemeTokens.Color.surfaceElevated))
                .clipShape(Capsule())
            }

        case let .autoCopy(title, bodyText, value):
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
                NotificationMockBanner(title: title, bodyText: bodyText)
                HStack(spacing: ThemeTokens.Spacing.xs) {
                    Image(uiImage: LucideIcon.copy.templateImage(pointSize: ThemeTokens.Icons.Sizes.xs) ?? UIImage())
                        .renderingMode(.template)
                        .foregroundColor(Color.appPrimary)
                    Text("\(value) 已自动复制到剪贴板")
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appTextSecondary)
                }
            }
        }
    }
}
