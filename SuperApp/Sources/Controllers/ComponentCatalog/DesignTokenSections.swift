//
//  DesignTokenSections.swift
//  SuperApp
//

import UIKit
import SnapKit
import WebBridgeKit

extension ComponentCatalogViewController {

    // MARK: - Section 2: Typography

    func buildTypographySection() {
        let header = makeSectionHeader(
            title: "Typography",
            tokenInfo: "ThemeTokens.Typography — 11 font tokens"
        )

        let fontSpecs: [(String, UIFont, String)] = [
            ("largeTitle", ThemeTokens.Typography.largeTitle, "28 bold"),
            ("title1", ThemeTokens.Typography.title1, "28 bold"),
            ("title2", ThemeTokens.Typography.title2, "22 bold"),
            ("title3", ThemeTokens.Typography.title3, "20 semibold"),
            ("headline", ThemeTokens.Typography.headline, "17 semibold"),
            ("body", ThemeTokens.Typography.body, "17 regular"),
            ("callout", ThemeTokens.Typography.callout, "16 regular"),
            ("subheadline", ThemeTokens.Typography.subheadline, "15 regular"),
            ("footnote", ThemeTokens.Typography.footnote, "13 regular"),
            ("caption1", ThemeTokens.Typography.caption1, "12 regular"),
            ("caption2", ThemeTokens.Typography.caption2, "11 regular")
        ]

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_Typography"

        var previousDivider: UIView?
        for (name, font, spec) in fontSpecs {
            let sampleLabel = UILabel()
            sampleLabel.font = font
            sampleLabel.textColor = ThemeTokens.Color.text
            sampleLabel.text = "Aa 大标题 \(name) \(spec)"
            container.addSubview(sampleLabel)
            sampleLabel.snp.makeConstraints { make in
                if let prev = previousDivider {
                    make.top.equalTo(prev.snp.bottom).offset(6)
                } else {
                    make.top.equalToSuperview()
                }
                make.leading.trailing.equalToSuperview()
            }

            let divider = UIView()
            divider.backgroundColor = ThemeTokens.Color.border
            container.addSubview(divider)
            divider.snp.makeConstraints { make in
                make.top.equalTo(sampleLabel.snp.bottom).offset(4)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(0.5)
            }
            previousDivider = divider
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(fontSpecs.count * 60)
        }
        addSection(header, container)
    }

    // MARK: - Section 3: Spacing

    func buildSpacingSection() {
        let header = makeSectionHeader(
            title: "Spacing",
            tokenInfo: "ThemeTokens.Spacing — xs(4), sm(8), md(16), lg(24), xl(32), xxl(48)"
        )

        let spacings: [(String, CGFloat)] = [
            ("xs", ThemeTokens.Spacing.xs),
            ("sm", ThemeTokens.Spacing.sm),
            ("md", ThemeTokens.Spacing.md),
            ("lg", ThemeTokens.Spacing.lg),
            ("xl", ThemeTokens.Spacing.xl),
            ("xxl", ThemeTokens.Spacing.xxl)
        ]

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.sm

        for (name, value) in spacings {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = ThemeSpacing.default.sm

            let nameLabel = UILabel()
            nameLabel.text = name
            nameLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)
            nameLabel.textColor = ThemeTokens.Color.text
            nameLabel.setContentHuggingPriority(.required, for: .horizontal)
            nameLabel.snp.makeConstraints { make in
                make.width.equalTo(36)
            }

            let bar = UIView()
            bar.backgroundColor = ThemeTokens.Color.primary
            bar.layer.cornerRadius = ThemeTokens.CornerRadius.xs
            bar.snp.makeConstraints { make in
                make.height.equalTo(value)
                make.width.equalTo(80)
            }

            let valueLabel = UILabel()
            valueLabel.text = "\(Int(value))pt"
            valueLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            valueLabel.textColor = ThemeTokens.Color.textSecondary
            valueLabel.setContentHuggingPriority(.required, for: .horizontal)

            row.addArrangedSubview(nameLabel)
            row.addArrangedSubview(bar)
            row.addArrangedSubview(valueLabel)
            stack.addArrangedSubview(row)
        }

        stack.snp.makeConstraints { make in
            make.height.equalTo(spacings.count * 44)
        }
        addSection(header, stack)
    }

    // MARK: - Section 4: Corner Radius

    func buildCornerRadiusSection() {
        let header = makeSectionHeader(
            title: "Corner Radius",
            tokenInfo: "ThemeTokens.CornerRadius — xs(2), sm(4), md(8), lg(12), xl(16), xxl(20), full(999)"
        )

        let radii: [(String, CGFloat)] = [
            ("xs(2)", ThemeTokens.CornerRadius.xs),
            ("sm(4)", ThemeTokens.CornerRadius.sm),
            ("md(8)", ThemeTokens.CornerRadius.md),
            ("lg(12)", ThemeTokens.CornerRadius.lg),
            ("xl(16)", ThemeTokens.CornerRadius.xl),
            ("xxl(20)", ThemeTokens.CornerRadius.xxl),
            ("full(pill)", ThemeTokens.CornerRadius.full)
        ]

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_CornerRadius"
        container.backgroundColor = ThemeTokens.Color.surface
        container.layer.cornerRadius = ThemeCornerRadius.default.lg

        let size: CGFloat = 56
        let innerSpacing: CGFloat = 16

        let rowStack = UIStackView()
        rowStack.axis = .horizontal
        rowStack.distribution = .fillEqually
        rowStack.spacing = innerSpacing

        for (name, radius) in radii {
            let itemStack = UIStackView()
            itemStack.axis = .vertical
            itemStack.alignment = .center
            itemStack.spacing = ThemeTokens.Spacing.sm

            let box = UIView()
            box.backgroundColor = ThemeTokens.Color.primary
            box.layer.cornerRadius = radius
            box.snp.makeConstraints { make in
                make.width.height.equalTo(size)
            }

            let nameLabel = UILabel()
            nameLabel.text = name
            nameLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .medium)
            nameLabel.textColor = ThemeTokens.Color.textSecondary

            itemStack.addArrangedSubview(box)
            itemStack.addArrangedSubview(nameLabel)
            rowStack.addArrangedSubview(itemStack)
        }

        container.addSubview(rowStack)
        rowStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(innerSpacing)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(size + 30)
        }
        addSection(header, container)
    }

    // MARK: - Section 5: Shadows

    func buildShadowsSection() {
        let header = makeSectionHeader(
            title: "Shadows",
            tokenInfo: "ThemeTokens.Shadows — Card, Fab, NavBar, Modal, Tooltip"
        )

        let shadows: [(String, ShadowValues)] = [
            ("card", ThemeTokens.Shadows.Card),
            ("fab", ThemeTokens.Shadows.Fab),
            ("navBar", ThemeTokens.Shadows.NavBar),
            ("modal", ThemeTokens.Shadows.Modal),
            ("tooltip", ThemeTokens.Shadows.Tooltip)
        ]

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_Shadows"

        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = ThemeTokens.Spacing.md

        for (name, shadow) in shadows {
            let itemStack = UIStackView()
            itemStack.axis = .vertical
            itemStack.alignment = .center
            itemStack.spacing = ThemeTokens.Spacing.sm

            let card = UIView()
            card.backgroundColor = ThemeTokens.Color.cardBackground
            card.layer.shadowColor = UIColor.black.cgColor
            card.layer.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
            card.layer.shadowRadius = shadow.radius
            card.layer.shadowOpacity = Float(shadow.opacity)
            card.layer.cornerRadius = ThemeCornerRadius.default.md
            card.snp.makeConstraints { make in
                make.width.equalTo(60)
                make.height.equalTo(80)
            }

            let nameLabel = UILabel()
            nameLabel.text = name
            nameLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
            nameLabel.textColor = ThemeTokens.Color.textSecondary

            let detailLabel = UILabel()
            detailLabel.text = "o:\(shadow.opacity) r:\(shadow.radius)"
            detailLabel.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)
            detailLabel.textColor = ThemeTokens.Color.textTertiary

            itemStack.addArrangedSubview(card)
            itemStack.addArrangedSubview(nameLabel)
            itemStack.addArrangedSubview(detailLabel)
            row.addArrangedSubview(itemStack)
        }

        container.addSubview(row)
        row.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(ThemeSpacing.default.sm)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(130)
        }
        addSection(header, container)
    }
}
