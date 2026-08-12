import UIKit
import WebBridgeKit

extension MessageDetailViewController {

    enum ActionPlacement {
        case contextual
        case destination
        case secondary
    }

    enum ActionStyle {
        case primary
        case accent
        case standard
        case destructive
    }

    func addAction(
        title: String,
        icon: LucideIcon,
        placement: ActionPlacement,
        style: ActionStyle = .standard,
        accessibilityIdentifier: String? = nil,
        handler: @escaping () -> Void
    ) {
        let button: UIButton
        if #available(iOS 15.0, *) {
            var configuration = makeConfiguration(for: style)
            configuration.title = "  \(title)"
            configuration.image = icon.templateImage(pointSize: 16)
            configuration.imagePadding = 8
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            button = UIButton(configuration: configuration)
        } else {
            button = makeLegacyButton(title: title, icon: icon, style: style)
        }

        button.contentHorizontalAlignment = .leading
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = title
        button.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        button.clipsToBounds = true
        button.addAction(UIAction { _ in handler() }, for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let stack = actionStack(for: placement)
        stack.isHidden = false
        stack.addArrangedSubview(button)
    }

    @available(iOS 15.0, *)
    private func makeConfiguration(for style: ActionStyle) -> UIButton.Configuration {
        var configuration: UIButton.Configuration
        switch style {
        case .primary:
            configuration = .filled()
            configuration.baseBackgroundColor = ThemeTokens.Color.primary
            configuration.baseForegroundColor = ThemeTokens.Color.onPrimary
        case .accent:
            configuration = .tinted()
            configuration.baseBackgroundColor = ThemeTokens.Color.primarySoft
            configuration.baseForegroundColor = ThemeTokens.Color.primary
        case .standard:
            configuration = .plain()
            configuration.baseBackgroundColor = ThemeTokens.Color.cardBackground
            configuration.baseForegroundColor = ThemeTokens.Color.primary
        case .destructive:
            configuration = .plain()
            configuration.baseBackgroundColor = ThemeTokens.Color.cardBackground
            configuration.baseForegroundColor = ThemeTokens.Color.error
        }
        return configuration
    }

    private func makeLegacyButton(title: String, icon: LucideIcon, style: ActionStyle) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("  \(title)", for: .normal)
        button.setImage(icon.templateImage(pointSize: 16), for: .normal)

        let foregroundColor: UIColor
        switch style {
        case .primary:
            button.backgroundColor = ThemeTokens.Color.primary
            foregroundColor = ThemeTokens.Color.onPrimary
        case .accent:
            button.backgroundColor = ThemeTokens.Color.primarySoft
            foregroundColor = ThemeTokens.Color.primary
        case .standard:
            button.backgroundColor = ThemeTokens.Color.cardBackground
            foregroundColor = ThemeTokens.Color.primary
        case .destructive:
            button.backgroundColor = ThemeTokens.Color.cardBackground
            foregroundColor = ThemeTokens.Color.error
        }
        button.tintColor = foregroundColor
        button.setTitleColor(foregroundColor, for: .normal)
        return button
    }

    private func actionStack(for placement: ActionPlacement) -> UIStackView {
        switch placement {
        case .contextual:
            return contextualActionStackView
        case .destination:
            return destinationActionStackView
        case .secondary:
            return secondaryActionStackView
        }
    }
}
