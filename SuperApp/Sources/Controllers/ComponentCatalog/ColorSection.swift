//
//  ColorSection.swift
//  SuperApp
//

import UIKit
import SnapKit
import WebBridgeKit

extension ComponentCatalogViewController {

    // MARK: - Section 1: Colors

    func buildColorSection() {
        let header = makeSectionHeader(
            title: "Colors",
            tokenInfo: "ThemeTokens.Color — dynamic color tokens"
        )

        let modeControl = UISegmentedControl(items: ["Light", "Dark", "System"])
        modeControl.selectedSegmentIndex = 0
        modeControl.addTarget(self, action: #selector(colorModeChanged(_:)), for: .valueChanged)

        let gridContainer = UIView()
        gridContainer.accessibilityIdentifier = "CatalogSection_Colors"
        gridContainer.backgroundColor = ThemeColors.current.surface
        gridContainer.layer.cornerRadius = ThemeCornerRadius.default.lg

        let colors: [(String, UIColor)] = [
            ("background", ThemeTokens.Color.background),
            ("primary", ThemeTokens.Color.primary),
            ("secondary", ThemeTokens.Color.secondary),
            ("text", ThemeTokens.Color.text),
            ("textSecondary", ThemeTokens.Color.textSecondary),
            ("textTertiary", ThemeTokens.Color.textTertiary),
            ("border", ThemeTokens.Color.border),
            ("separator", ThemeTokens.Color.separator),
            ("cardBackground", ThemeTokens.Color.cardBackground),
            ("surface", ThemeTokens.Color.surface),
            ("error", ThemeTokens.Color.error),
            ("warning", ThemeTokens.Color.warning),
            ("success", ThemeTokens.Color.success),
            ("info", ThemeTokens.Color.info),
            ("fabBackground", ThemeTokens.Color.fabBackground),
            ("gradientStart", ThemeTokens.Color.gradientStart),
            ("gradientEnd", ThemeTokens.Color.gradientEnd),
            ("badgeBackground", ThemeTokens.Color.badgeBackground),
            ("badgeText", ThemeTokens.Color.badgeText),
            ("unreadDot", ThemeTokens.Color.unreadDot),
            ("overlay", ThemeTokens.Color.overlay),
            ("navBarBg", ThemeTokens.Color.navigationBarBackground),
            ("tabBarBg", ThemeTokens.Color.tabBarBackground)
        ]

        let cols = 4
        let circleSize: CGFloat = 48
        let itemSpacing: CGFloat = 8
        let rows = Int(ceil(Double(colors.count) / Double(cols)))

        for (index, (name, color)) in colors.enumerated() {
            let row = index / cols
            let col = index % cols

            let circle = UIView()
            circle.backgroundColor = color
            circle.layer.cornerRadius = circleSize / 2
            circle.layer.borderWidth = 1
            circle.layer.borderColor = ThemeTokens.Color.border.cgColor
            circle.accessibilityIdentifier = "ColorSwatch_\(name)"
            gridContainer.addSubview(circle)

            let colWidth = (UIScreen.main.bounds.width - ThemeSpacing.default.md * 2 - ThemeSpacing.default.md * 2 - itemSpacing * CGFloat(cols - 1)) / CGFloat(cols)
            circle.snp.makeConstraints { make in
                make.width.height.equalTo(circleSize)
                make.top.equalToSuperview().offset(CGFloat(row) * (circleSize + itemSpacing + 28) + itemSpacing)
                make.left.equalToSuperview().offset(CGFloat(col) * (colWidth + itemSpacing) + itemSpacing)
            }

            let nameLabel = UILabel()
            nameLabel.text = name
            nameLabel.font = ThemeTypography.current.caption2
            nameLabel.textColor = ThemeColors.current.text
            nameLabel.textAlignment = .center
            gridContainer.addSubview(nameLabel)
            nameLabel.snp.makeConstraints { make in
                make.top.equalTo(circle.snp.bottom).offset(2)
                make.centerX.equalTo(circle)
            }

            let hexLabel = UILabel()
            hexLabel.text = hexString(from: color)
            hexLabel.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)
            hexLabel.textColor = ThemeTokens.Color.textTertiary
            hexLabel.textAlignment = .center
            gridContainer.addSubview(hexLabel)
            hexLabel.snp.makeConstraints { make in
                make.top.equalTo(nameLabel.snp.bottom).offset(1)
                make.centerX.equalTo(nameLabel)
            }
        }

        let totalHeight = CGFloat(rows) * (circleSize + itemSpacing + 28) + itemSpacing + 40
        let sectionContent = UIStackView(arrangedSubviews: [modeControl, gridContainer])
        sectionContent.axis = .vertical
        sectionContent.spacing = ThemeSpacing.default.sm
        gridContainer.snp.makeConstraints { make in
            make.height.equalTo(totalHeight)
        }
        addSection(header, sectionContent)
    }

    @objc func colorModeChanged(_ sender: UISegmentedControl) {
        let mode: ThemeMode
        switch sender.selectedSegmentIndex {
        case 0: mode = .light
        case 1: mode = .dark
        default: mode = .system
        }
        Task { @MainActor in
            await ThemeManager.shared.apply(mode)
            if let window = view.window {
                await ThemeManager.shared.applyToWindow(window)
            }
        }
    }

    // MARK: - Helpers

    func hexString(from color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
