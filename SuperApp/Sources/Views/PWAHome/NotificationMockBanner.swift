import SwiftUI
import WebBridgeKit

/// A native rendition of an iOS notification banner for the example cards.
/// This is Drel's counterpart to Bark's static preview screenshots —
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
                Text("Drel")
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
            Image(uiImage: DrelBrand.image ?? UIImage())
                .resizable()
                .scaledToFill()
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

        case let .customIcon(title, bodyText, iconURL):
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
                // This accurately represents iOS: a system notification keeps
                // the installed Drel App Icon and cannot be replaced by a
                // remote `icon` value from one push.
                NotificationMockBanner(title: title, bodyText: bodyText)

                CustomIconInboxPreview(title: title, bodyText: bodyText, iconURL: iconURL)

                Label("系统通知显示 Drel 图标；下方是收件箱中的自定义消息头像", systemImage: "info.circle")
                    .font(Font.app(ThemeTokens.Typography.metadata))
                    .foregroundColor(Color.appTextSecondary)
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

/// A compact, concrete preview of the surface where a custom `icon` takes
/// effect. Keeping it next to the system-banner mock prevents developers from
/// expecting APNs to replace the installed app icon on the lock screen.
private struct CustomIconInboxPreview: View {
    let title: String
    let bodyText: String
    let iconURL: URL

    @State private var remoteIcon: UIImage?

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.md) {
            avatar
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Drel 收件箱")
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appTextSecondary)
                    Spacer()
                    Text("现在")
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appTextTertiary)
                }
                Text(title)
                    .font(.system(size: ThemeTokens.Typography.rowTitle.pointSize, weight: .semibold))
                    .foregroundColor(Color.appText)
                    .lineLimit(1)
                Text(bodyText)
                    .font(Font.app(ThemeTokens.Typography.footnote))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(1)
            }
        }
        .padding(ThemeTokens.Spacing.md)
        .background(Color(ThemeTokens.Color.surface))
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md)
                .strokeBorder(Color(ThemeTokens.Color.border), lineWidth: 1)
        )
        .onAppear(perform: loadIcon)
    }

    @ViewBuilder
    private var avatar: some View {
        if let remoteIcon {
            Image(uiImage: remoteIcon)
                .resizable()
                .scaledToFill()
        } else {
            Image(uiImage: DrelBrand.image ?? UIImage())
                .resizable()
                .scaledToFill()
        }
    }

    private func loadIcon() {
        guard remoteIcon == nil else { return }
        DispatchQueue.global().async {
            guard let data = try? Data(contentsOf: iconURL), let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                remoteIcon = image
            }
        }
    }
}
