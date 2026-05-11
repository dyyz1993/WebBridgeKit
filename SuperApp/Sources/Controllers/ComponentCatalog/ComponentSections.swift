//
//  ComponentSections.swift
//  SuperApp
//

import UIKit
import SnapKit
import WebBridgeKit

extension ComponentCatalogViewController {

    // MARK: - Section 6: Buttons

    func buildButtonsSection() {
        let header = makeSectionHeader(
            title: "Buttons (ThemeButton)",
            tokenInfo: "ThemeButton — styles: primary, secondary, ghost"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_Buttons"
        container.backgroundColor = ThemeColors.current.surface
        container.layer.cornerRadius = ThemeCornerRadius.default.lg

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ThemeSpacing.default.sm
        stack.alignment = .fill

        let normalLabel = UILabel()
        normalLabel.text = "Normal State"
        normalLabel.font = ThemeTypography.current.caption2
        normalLabel.textColor = ThemeTokens.Color.textTertiary
        stack.addArrangedSubview(normalLabel)

        for style in [ThemeButtonStyle.primary, ThemeButtonStyle.secondary, ThemeButtonStyle.ghost] {
            let btn = ThemeButton()
            btn.configure(title: "\(style) Button", style: style)
            btn.snp.makeConstraints { make in
                make.height.equalTo(44)
            }
            stack.addArrangedSubview(btn)
        }

        let disabledLabel = UILabel()
        disabledLabel.text = "Disabled State (alpha 0.3)"
        disabledLabel.font = ThemeTypography.current.caption2
        disabledLabel.textColor = ThemeTokens.Color.textTertiary
        stack.addArrangedSubview(disabledLabel)

        for style in [ThemeButtonStyle.primary, ThemeButtonStyle.secondary, ThemeButtonStyle.ghost] {
            let btn = ThemeButton()
            btn.configure(title: "\(style) Disabled", style: style)
            btn.alpha = ThemeTokens.Opacity.disabled
            btn.isEnabled = false
            btn.snp.makeConstraints { make in
                make.height.equalTo(44)
            }
            stack.addArrangedSubview(btn)
        }

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(ThemeSpacing.default.md)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(300)
        }
        addSection(header, container)
    }

    // MARK: - Section 7: Badges

    func buildBadgesSection() {
        let header = makeSectionHeader(
            title: "Badges (ThemeBadge)",
            tokenInfo: "ThemeBadge — success, warning, error, info, default"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_Badges"
        container.backgroundColor = ThemeColors.current.surface
        container.layer.cornerRadius = ThemeCornerRadius.default.lg

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = ThemeSpacing.default.sm
        stack.alignment = .center
        stack.distribution = .equalSpacing

        let badges: [(String, ThemeBadgeStyle)] = [
            ("Success", .success),
            ("Warning", .warning),
            ("Error", .error),
            ("Info", .info),
            ("Default", .default)
        ]

        for (text, style) in badges {
            let badge = ThemeBadge()
            badge.configure(text: text, style: style)
            stack.addArrangedSubview(badge)
        }

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.edges.equalToSuperview().inset(ThemeSpacing.default.md)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(50)
        }
        addSection(header, container)
    }

    // MARK: - Section 8: Cards

    func buildCardsSection() {
        let header = makeSectionHeader(
            title: "Cards (ThemeCard)",
            tokenInfo: "ThemeCard — cornerRadius: lg(12), shadow: Card preset"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_Cards"

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ThemeSpacing.default.md

        let emptyCard = ThemeCard()
        emptyCard.snp.makeConstraints { make in
            make.height.equalTo(80)
        }
        stack.addArrangedSubview(emptyCard)

        let contentCard = ThemeCard()
        let cardLabel = UILabel()
        cardLabel.text = "Card with content inside\nSecond line of text"
        cardLabel.numberOfLines = 0
        cardLabel.font = ThemeTypography.current.body
        cardLabel.textColor = ThemeColors.current.text
        contentCard.addContent(cardLabel)
        cardLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(ThemeSpacing.default.md)
        }
        contentCard.snp.makeConstraints { make in
            make.height.equalTo(80)
        }
        stack.addArrangedSubview(contentCard)

        let shadowCard = ThemeCard()
        let shadow = ThemeTokens.Shadows.Card
        shadowCard.innerContentView.layer.shadowColor = UIColor.black.cgColor
        shadowCard.innerContentView.layer.shadowOpacity = Float(shadow.opacity)
        shadowCard.innerContentView.layer.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
        shadowCard.innerContentView.layer.shadowRadius = shadow.radius
        let shadowLabel = UILabel()
        shadowLabel.text = "Card with enhanced shadow"
        shadowLabel.font = ThemeTypography.current.body
        shadowLabel.textColor = ThemeColors.current.text
        shadowCard.addContent(shadowLabel)
        shadowLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(ThemeSpacing.default.md)
        }
        shadowCard.snp.makeConstraints { make in
            make.height.equalTo(80)
        }
        stack.addArrangedSubview(shadowCard)

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(280)
        }
        addSection(header, container)
    }

    // MARK: - Section 9: Empty States

    func buildEmptyStatesSection() {
        let header = makeSectionHeader(
            title: "Empty States (ThemeEmptyState)",
            tokenInfo: "ThemeEmptyState — icon + title + description"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_EmptyStates"
        container.backgroundColor = ThemeColors.current.surface
        container.layer.cornerRadius = ThemeCornerRadius.default.lg

        let defaultEmpty = ThemeEmptyState()
        defaultEmpty.configure(icon: .inbox, title: "No Messages", description: "Your inbox is empty. Messages will appear here.")
        defaultEmpty.snp.makeConstraints { make in
            make.height.equalTo(160)
        }

        let customEmpty = ThemeEmptyState()
        customEmpty.configure(icon: "tray.full", title: "No Items Found", description: "We couldn't find any items matching your search.")
        customEmpty.snp.makeConstraints { make in
            make.height.equalTo(160)
        }

        let stack = UIStackView(arrangedSubviews: [defaultEmpty, customEmpty])
        stack.axis = .vertical
        stack.spacing = ThemeSpacing.default.md

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(ThemeSpacing.default.md)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(340)
        }
        addSection(header, container)
    }
}
