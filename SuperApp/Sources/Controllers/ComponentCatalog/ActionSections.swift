//
//  ActionSections.swift
//  SuperApp
//

import UIKit
import SnapKit
import WebBridgeKit

extension ComponentCatalogViewController {

    // MARK: - Section 14: Quick Actions

    func buildQuickActionsSection() {
        let header = makeSectionHeader(
            title: "Quick Actions",
            tokenInfo: "Home page quick actions — Scan, Paste, Token, Debug"
        )

        let actions: [(icon: String, title: String, color: UIColor)] = [
            ("qrcode.viewfinder", "Scan", ThemeColors.current.primary),
            ("doc.on.clipboard", "Paste", ThemeColors.current.warning),
            ("text.badge.star", "Token", ThemeTokens.Color.gradientEnd),
            ("ladybug", "Debug", ThemeColors.current.success)
        ]

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_QuickActions"
        container.backgroundColor = ThemeColors.current.surface
        container.layer.cornerRadius = ThemeCornerRadius.default.lg

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = ThemeTokens.Spacing.sm

        for action in actions {
            let btn = UIButton(type: .system)
            btn.backgroundColor = ThemeColors.current.surface
            btn.layer.cornerRadius = ThemeTokens.CornerRadius.lg

            let iconView = UIImageView()
            iconView.image = UIImage(systemName: action.icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium))
            iconView.tintColor = action.color
            iconView.contentMode = .scaleAspectFit

            let titleLabel = UILabel()
            titleLabel.text = action.title
            titleLabel.font = ThemeTokens.Typography.caption2
            titleLabel.textColor = action.color
            titleLabel.textAlignment = .center

            let innerStack = UIStackView(arrangedSubviews: [iconView, titleLabel])
            innerStack.axis = .vertical
            innerStack.alignment = .center
            innerStack.spacing = ThemeTokens.Spacing.xs
            innerStack.isUserInteractionEnabled = false

            btn.addSubview(innerStack)
            innerStack.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
            stack.addArrangedSubview(btn)
        }

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(ThemeSpacing.default.sm)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(80)
        }
        addSection(header, container)
    }

    // MARK: - Section 15: Filter Pills

    func buildFilterPillsSection() {
        let header = makeSectionHeader(
            title: "Filter Pills",
            tokenInfo: "Inbox filter pills — selected (primary) / unselected (gray)"
        )

        let filters = [("全部", true), ("未读", false), ("今天", false)]

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_FilterPills"
        container.backgroundColor = ThemeColors.current.surface
        container.layer.cornerRadius = ThemeCornerRadius.default.lg

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = ThemeTokens.Spacing.sm
        stack.alignment = .center

        for (title, isSelected) in filters {
            let button: UIButton
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.filled()
                config.baseBackgroundColor = isSelected ? ThemeColors.current.primary : ThemeTokens.Color.surface
                config.baseForegroundColor = isSelected ? ThemeTokens.Color.background : ThemeTokens.Color.textSecondary
                config.cornerStyle = .capsule
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var outgoing = incoming
                    outgoing.font = ThemeTokens.Typography.footnote
                    return outgoing
                }
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                button = UIButton(configuration: config)
            } else {
                button = UIButton(type: .system)
                button.titleLabel?.font = ThemeTokens.Typography.footnote
                button.backgroundColor = isSelected ? ThemeColors.current.primary : ThemeTokens.Color.surface
                button.setTitleColor(isSelected ? ThemeTokens.Color.background : ThemeTokens.Color.textSecondary, for: .normal)
                button.layer.cornerRadius = ThemeTokens.CornerRadius.xl
                button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            }
            button.setTitle(title, for: .normal)
            stack.addArrangedSubview(button)
        }

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.edges.equalToSuperview().inset(ThemeSpacing.default.md)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(52)
        }
        addSection(header, container)
    }

    // MARK: - Section 16: FAB

    func buildFABSection() {
        let header = makeSectionHeader(
            title: "Floating Action Button (FAB)",
            tokenInfo: "FAB — fabBackground, cornerRadius: 28, shadow: Fab preset"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_FAB"

        let fab = UIButton(type: .system)
        fab.setImage(LucideIcon.bell.image(pointSize: 22, weight: .semibold), for: .normal)
        fab.backgroundColor = ThemeColors.current.fabBackground
        fab.tintColor = ThemeTokens.Color.background
        fab.layer.cornerRadius = ThemeTokens.CornerRadius.full
        fab.layer.shadowColor = UIColor.black.cgColor
        fab.layer.shadowOffset = CGSize(width: 0, height: ThemeTokens.Shadows.Fab.offsetY)
        fab.layer.shadowRadius = ThemeTokens.Shadows.Fab.radius
        fab.layer.shadowOpacity = Float(ThemeTokens.Shadows.Fab.opacity)
        fab.snp.makeConstraints { make in
            make.width.height.equalTo(56)
        }

        container.addSubview(fab)
        fab.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(100)
        }
        addSection(header, container)
    }

    // MARK: - Section 17: Menu Items

    func buildMenuItemsSection() {
        let header = makeSectionHeader(
            title: "Menu Items (Settings Row)",
            tokenInfo: "MenuCell / SwitchCell — icon, title, value, chevron, toggle, badge"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_MenuItems"
        container.backgroundColor = ThemeColors.current.surface
        container.layer.cornerRadius = ThemeCornerRadius.default.lg
        container.clipsToBounds = true

        func makeRow(icon: String?, title: String, value: String?, showChevron: Bool, showSwitch: Bool = false, showBadge: Bool = false) -> UIView {
            let row = UIView()
            row.backgroundColor = ThemeColors.current.cardBackground

            let iconIV = UIImageView()
            if let icon = icon {
                iconIV.image = UIImage(systemName: icon)
                iconIV.tintColor = ThemeColors.current.primary
                iconIV.contentMode = .scaleAspectFit
            }
            row.addSubview(iconIV)

            let titleLbl = UILabel()
            titleLbl.text = title
            titleLbl.font = ThemeTokens.Typography.callout
            titleLbl.textColor = ThemeColors.current.text
            row.addSubview(titleLbl)

            let valueLbl = UILabel()
            valueLbl.text = value
            valueLbl.font = ThemeTokens.Typography.subheadline
            valueLbl.textColor = ThemeColors.current.textSecondary
            valueLbl.textAlignment = .right
            valueLbl.isHidden = value == nil
            row.addSubview(valueLbl)

            let chevronIV = UIImageView()
            chevronIV.image = LucideIcon.chevronRight.templateImage()
            chevronIV.tintColor = ThemeTokens.Color.textTertiary
            chevronIV.contentMode = .scaleAspectFit
            chevronIV.isHidden = !showChevron
            row.addSubview(chevronIV)

            let toggle = UISwitch()
            toggle.isOn = showSwitch
            toggle.onTintColor = ThemeColors.current.primary
            toggle.isHidden = !showSwitch
            row.addSubview(toggle)

            let badge = ThemeBadge()
            badge.configure(text: "NEW", style: .info)
            badge.isHidden = !showBadge
            row.addSubview(badge)

            let hasIcon = icon != nil
            iconIV.snp.makeConstraints { make in
                make.left.equalToSuperview().offset(16)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(hasIcon ? 24 : 0)
            }
            iconIV.isHidden = !hasIcon

            titleLbl.snp.makeConstraints { make in
                make.left.equalTo(hasIcon ? iconIV.snp.right : row.snp.left).offset(hasIcon ? 12 : 16)
                make.centerY.equalToSuperview()
            }

            valueLbl.snp.makeConstraints { make in
                make.left.equalTo(titleLbl.snp.right).offset(12)
                make.right.equalTo(showChevron ? chevronIV.snp.left : row.snp.right).offset(showChevron ? -8 : -16)
                make.centerY.equalToSuperview()
            }

            chevronIV.snp.makeConstraints { make in
                make.right.equalToSuperview().offset(-16)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(16)
            }

            toggle.snp.makeConstraints { make in
                make.right.equalToSuperview().offset(-16)
                make.centerY.equalToSuperview()
            }

            badge.snp.makeConstraints { make in
                make.right.equalToSuperview().offset(-16)
                make.centerY.equalToSuperview()
            }

            let separator = UIView()
            separator.backgroundColor = ThemeTokens.Color.separator
            row.addSubview(separator)
            separator.snp.makeConstraints { make in
                make.bottom.equalToSuperview()
                make.left.equalToSuperview().offset(16)
                make.right.equalToSuperview()
                make.height.equalTo(0.5)
            }

            return row
        }

        let standardRow = makeRow(icon: "person.circle", title: "Account Settings", value: "user@example.com", showChevron: true)
        standardRow.snp.makeConstraints { make in make.height.equalTo(52) }

        let toggleRow = makeRow(icon: "bell", title: "Notifications", value: nil, showChevron: false, showSwitch: true)
        toggleRow.snp.makeConstraints { make in make.height.equalTo(52) }

        let badgeRow = makeRow(icon: "star", title: "Favorites", value: nil, showChevron: true, showBadge: true)
        badgeRow.snp.makeConstraints { make in make.height.equalTo(52) }

        let stack = UIStackView(arrangedSubviews: [standardRow, toggleRow, badgeRow])
        stack.axis = .vertical

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(156)
        }
        addSection(header, container)
    }
}
