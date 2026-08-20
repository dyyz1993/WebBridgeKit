import SwiftUI
import WebBridgeKit

struct SettingsRow: View {
    let icon: UIImage?
    let iconBackgroundColor: UIColor
    let iconTintColor: UIColor
    let title: String
    var trailingText: String?
    var showChevron: Bool = true
    var isToggle: Bool = false
    @Binding var isToggleOn: Bool
    var isDestructive: Bool = false
    var badge: String?
    var toggleAccessibilityIdentifier: String?
    var onTap: (() -> Void)?

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if isToggle {
                Button(
                    action: { isToggleOn.toggle() },
                    label: { rowContent.allowsHitTesting(false) }
                )
                .buttonStyle(PlainButtonStyle())
                .accessibilityAddTraits(.isButton)
            } else {
                Button(
                    action: { onTap?() },
                    label: { rowContent }
                )
                .buttonStyle(PlainButtonStyle())
                .accessibilityAddTraits(.isButton)
            }
        }
        .scaleEffect(reduceMotion ? 1.0 : (isPressed ? 0.97 : 1.0))
        .animation(reduceMotion ? .none : .easeOut(duration: ThemeTokens.Animation.fast.duration), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    private var rowContent: some View {
        HStack(spacing: ThemeTokens.Spacing.md) {
            SettingsIconBox(
                image: icon,
                backgroundColor: iconBackgroundColor,
                tintColor: iconTintColor
            )

            Text(title)
                .font(Font.app(ThemeTokens.Typography.rowTitle))
                .foregroundColor(isDestructive ? Color.appError : Color.appText)
                .lineLimit(Int(ThemeTokens.ComponentContract.SettingsRow.titleMaxLines))

            Spacer()

            if let text = trailingText {
                Text(text)
                    .font(Font.app(ThemeTokens.Typography.metadata))
                    .foregroundColor(Color.appTextTertiary)
            }

            if let badge = badge {
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.appPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(ThemeTokens.Color.primarySoft))
                    .cornerRadius(ThemeTokens.CornerRadius.xs)
            }

            if isToggle {
                Toggle("", isOn: $isToggleOn)
                    .labelsHidden()
                    .accessibilityIdentifier(toggleAccessibilityIdentifier ?? "settings.toggle")
            } else if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: ThemeTokens.Icons.Sizes.chevron, weight: .semibold))
                    .foregroundColor(Color.appTextTertiary)
            }
        }
        .padding(.vertical, ThemeTokens.Spacing.sm)
        .contentShape(Rectangle())
    }
}

struct SettingsIconBox: View {
    let image: UIImage?
    let backgroundColor: UIColor
    let tintColor: UIColor

    var body: some View {
        ZStack {
            if backgroundColor != .clear {
                RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.xs)
                    .fill(Color(backgroundColor))
                    .frame(
                        width: ThemeTokens.ComponentContract.SettingsRow.iconBox,
                        height: ThemeTokens.ComponentContract.SettingsRow.iconBox
                    )
            }

            if let image = image {
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: ThemeTokens.ComponentContract.SettingsRow.iconSize,
                        height: ThemeTokens.ComponentContract.SettingsRow.iconSize
                    )
                    .foregroundColor(Color(tintColor))
            }
        }
    }
}
