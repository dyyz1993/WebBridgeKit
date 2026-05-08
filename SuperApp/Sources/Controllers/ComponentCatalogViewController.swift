//
//  ComponentCatalogViewController.swift
//  SuperApp
//
//  Storybook-style UI Component Catalog for Fidelity Testing
//

import UIKit
import SnapKit
import WebBridgeKit

class ComponentCatalogViewController: UIViewController {

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.accessibilityIdentifier = "ComponentCatalogScrollView"
        return sv
    }()

    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.alignment = .fill
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UI Component Catalog"
        view.backgroundColor = ThemeColors.current.background
        setupUI()
        buildSections()
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentStackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(ThemeSpacing.default.md)
            make.width.equalTo(scrollView).offset(-ThemeSpacing.default.md * 2)
        }
    }

    // MARK: - Section Builder

    private func buildSections() {
        buildColorSection()
        buildTypographySection()
        buildSpacingSection()
        buildCornerRadiusSection()
        buildShadowsSection()
        buildButtonsSection()
        buildBadgesSection()
        buildCardsSection()
        buildEmptyStatesSection()
        buildGradientViewsSection()
        buildSectionHeadersSection()
        buildMessageCellsSection()
        buildTokenCardSection()
        buildQuickActionsSection()
        buildFilterPillsSection()
        buildFABSection()
        buildMenuItemsSection()
    }

    private func makeSectionHeader(title: String, tokenInfo: String) -> UIView {
        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_\(title)"

        let titleLabel: UILabel = {
            let label = UILabel()
            label.text = title
            label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
            label.textColor = ThemeColors.current.text
            return label
        }()

        let subtitleLabel: UILabel = {
            let label = UILabel()
            label.text = tokenInfo
            label.font = ThemeTypography.current.caption1
            label.textColor = ThemeColors.current.textSecondary
            return label
        }()

        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.leading.bottom.equalToSuperview()
        }

        let wrapper = UIView()
        wrapper.addSubview(container)
        container.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: ThemeSpacing.default.md, left: 0, bottom: ThemeSpacing.default.sm, right: 0))
        }
        return wrapper
    }

    private func addSection(_ headerView: UIView, _ contentView: UIView) {
        contentStackView.addArrangedSubview(headerView)
        contentStackView.addArrangedSubview(contentView)
        addSpacer(height: ThemeSpacing.default.lg)
    }

    private func addSpacer(height: CGFloat) {
        let spacer = UIView()
        spacer.snp.makeConstraints { make in
            make.height.equalTo(height)
        }
        contentStackView.addArrangedSubview(spacer)
    }

    // MARK: - Section 1: Colors

    private func buildColorSection() {
        let header = makeSectionHeader(
            title: "Colors",
            tokenInfo: "ThemeTokens.Colors.Light / Dark — 22 color tokens"
        )

        let modeControl = UISegmentedControl(items: ["Light", "Dark", "System"])
        modeControl.selectedSegmentIndex = 0
        modeControl.addTarget(self, action: #selector(colorModeChanged(_:)), for: .valueChanged)

        let gridContainer = UIView()
        gridContainer.accessibilityIdentifier = "CatalogSection_Colors"
        gridContainer.backgroundColor = ThemeColors.current.surface
        gridContainer.layer.cornerRadius = ThemeCornerRadius.default.lg

        let colors: [(String, UIColor)] = [
            ("background", ThemeTokens.Colors.Light.background),
            ("primary", ThemeTokens.Colors.Light.primary),
            ("secondary", ThemeTokens.Colors.Light.secondary),
            ("text", ThemeTokens.Colors.Light.text),
            ("textSecondary", ThemeTokens.Colors.Light.textSecondary),
            ("textTertiary", ThemeTokens.Colors.Light.textTertiary),
            ("border", ThemeTokens.Colors.Light.border),
            ("separator", ThemeTokens.Colors.Light.separator),
            ("cardBackground", ThemeTokens.Colors.Light.cardBackground),
            ("surface", ThemeTokens.Colors.Light.surface),
            ("error", ThemeTokens.Colors.Light.error),
            ("warning", ThemeTokens.Colors.Light.warning),
            ("success", ThemeTokens.Colors.Light.success),
            ("info", ThemeTokens.Colors.Light.info),
            ("fabBackground", ThemeTokens.Colors.Light.fabBackground),
            ("gradientStart", ThemeTokens.Colors.Light.gradientStart),
            ("gradientEnd", ThemeTokens.Colors.Light.gradientEnd),
            ("badgeBackground", ThemeTokens.Colors.Light.badgeBackground),
            ("badgeText", ThemeTokens.Colors.Light.badgeText),
            ("unreadDot", ThemeTokens.Colors.Light.unreadDot),
            ("overlay", ThemeTokens.Colors.Light.overlay),
            ("navBarBg", ThemeTokens.Colors.Light.navigationBarBackground),
            ("tabBarBg", ThemeTokens.Colors.Light.tabBarBackground)
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
            circle.layer.borderColor = ThemeTokens.Colors.Light.border.cgColor
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
            hexLabel.textColor = ThemeTokens.Colors.Light.textTertiary
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

    @objc private func colorModeChanged(_ sender: UISegmentedControl) {
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

    // MARK: - Section 2: Typography

    private func buildTypographySection() {
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

        for (index, (name, font, spec)) in fontSpecs.enumerated() {
            let sampleLabel = UILabel()
            sampleLabel.font = font
            sampleLabel.textColor = ThemeColors.current.text
            sampleLabel.text = "Aa 大标题 \(name) \(spec)"
            container.addSubview(sampleLabel)
            sampleLabel.snp.makeConstraints { make in
                if index == 0 {
                    make.top.equalToSuperview()
                } else {
                    make.top.equalTo(container.subviews[index * 3].snp.bottom).offset(6)
                }
                make.leading.trailing.equalToSuperview()
            }

            let divider = UIView()
            divider.backgroundColor = ThemeColors.current.border
            container.addSubview(divider)
            divider.snp.makeConstraints { make in
                make.top.equalTo(sampleLabel.snp.bottom).offset(4)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(0.5)
            }
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(fontSpecs.count * 60)
        }
        addSection(header, container)
    }

    // MARK: - Section 3: Spacing

    private func buildSpacingSection() {
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
        stack.spacing = 8

        for (name, value) in spacings {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = ThemeSpacing.default.sm

            let nameLabel = UILabel()
            nameLabel.text = name
            nameLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)
            nameLabel.textColor = ThemeColors.current.text
            nameLabel.setContentHuggingPriority(.required, for: .horizontal)
            nameLabel.snp.makeConstraints { make in
                make.width.equalTo(36)
            }

            let bar = UIView()
            bar.backgroundColor = ThemeColors.current.primary
            bar.layer.cornerRadius = 2
            bar.snp.makeConstraints { make in
                make.height.equalTo(value)
                make.width.equalTo(80)
            }

            let valueLabel = UILabel()
            valueLabel.text = "\(Int(value))pt"
            valueLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            valueLabel.textColor = ThemeColors.current.textSecondary
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

    private func buildCornerRadiusSection() {
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
        container.backgroundColor = ThemeColors.current.surface
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
            itemStack.spacing = 6

            let box = UIView()
            box.backgroundColor = ThemeColors.current.primary
            box.layer.cornerRadius = radius
            box.snp.makeConstraints { make in
                make.width.height.equalTo(size)
            }

            let nameLabel = UILabel()
            nameLabel.text = name
            nameLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .medium)
            nameLabel.textColor = ThemeColors.current.textSecondary

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

    private func buildShadowsSection() {
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
        row.spacing = 12

        for (name, shadow) in shadows {
            let itemStack = UIStackView()
            itemStack.axis = .vertical
            itemStack.alignment = .center
            itemStack.spacing = 8

            let card = UIView()
            card.backgroundColor = ThemeColors.current.cardBackground
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
            nameLabel.textColor = ThemeColors.current.textSecondary

            let detailLabel = UILabel()
            detailLabel.text = "o:\(shadow.opacity) r:\(shadow.radius)"
            detailLabel.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)
            detailLabel.textColor = ThemeTokens.Colors.Light.textTertiary

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

    // MARK: - Section 6: Buttons

    private func buildButtonsSection() {
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
        normalLabel.textColor = ThemeTokens.Colors.Light.textTertiary
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
        disabledLabel.textColor = ThemeTokens.Colors.Light.textTertiary
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

    private func buildBadgesSection() {
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

    private func buildCardsSection() {
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
        shadowCard.innerContentView.layer.shadowOpacity = 0.15
        shadowCard.innerContentView.layer.shadowOffset = CGSize(width: 0, height: 4)
        shadowCard.innerContentView.layer.shadowRadius = 12
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

    private func buildEmptyStatesSection() {
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

    // MARK: - Section 10: Gradient Views

    private func buildGradientViewsSection() {
        let header = makeSectionHeader(
            title: "Gradient Views (ThemeGradientView)",
            tokenInfo: "ThemeGradientView — gradientStart → gradientEnd, diagonal direction"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_GradientViews"

        let smallGradient = ThemeGradientView()
        smallGradient.snp.makeConstraints { make in
            make.height.equalTo(60)
        }

        let largeGradient = ThemeGradientView()
        largeGradient.snp.makeConstraints { make in
            make.height.equalTo(120)
        }

        let stack = UIStackView(arrangedSubviews: [smallGradient, largeGradient])
        stack.axis = .vertical
        stack.spacing = ThemeSpacing.default.md

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(200)
        }
        addSection(header, container)
    }

    // MARK: - Section 11: Section Headers

    private func buildSectionHeadersSection() {
        let header = makeSectionHeader(
            title: "Section Headers (ThemeSectionHeader)",
            tokenInfo: "ThemeSectionHeader — title + optional action button"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_SectionHeaders"
        container.backgroundColor = ThemeColors.current.surface
        container.layer.cornerRadius = ThemeCornerRadius.default.lg

        let withAction = ThemeSectionHeader()
        withAction.configure(title: "Recent Activity", actionTitle: "See All")

        let withoutAction = ThemeSectionHeader()
        withoutAction.configure(title: "Settings")

        let stack = UIStackView(arrangedSubviews: [withAction, withoutAction])
        stack.axis = .vertical
        stack.spacing = ThemeSpacing.default.md

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(ThemeSpacing.default.md)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(100)
        }
        addSection(header, container)
    }

    // MARK: - Section 12: Message Cells

    private func buildMessageCellsSection() {
        let header = makeSectionHeader(
            title: "Message Cells (InboxMessageCell)",
            tokenInfo: "InboxMessageCell — unread dot, title, source, time, body preview"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_MessageCells"

        func createMessageCell(isUnread: Bool) -> UIView {
            let cell = UIView()
            cell.backgroundColor = ThemeColors.current.cardBackground
            cell.layer.cornerRadius = ThemeCornerRadius.default.lg

            let unreadDot = UIView()
            unreadDot.backgroundColor = ThemeTokens.Colors.Light.unreadDot
            unreadDot.layer.cornerRadius = 5
            unreadDot.isHidden = !isUnread
            cell.addSubview(unreadDot)

            let titleLabel = UILabel()
            titleLabel.text = isUnread ? "New Feature Released" : "Weekly Digest"
            titleLabel.font = isUnread ? UIFont.systemFont(ofSize: 16, weight: .bold) : UIFont.systemFont(ofSize: 16, weight: .regular)
            titleLabel.textColor = ThemeColors.current.text
            cell.addSubview(titleLabel)

            let sourceLabel = UILabel()
            sourceLabel.text = "APNS"
            sourceLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            sourceLabel.textColor = ThemeColors.current.info
            cell.addSubview(sourceLabel)

            let timeLabel = UILabel()
            timeLabel.text = "05-08 14:30"
            timeLabel.font = UIFont.systemFont(ofSize: 11)
            timeLabel.textColor = ThemeTokens.Colors.Light.textTertiary
            timeLabel.textAlignment = .right
            cell.addSubview(timeLabel)

            let bodyLabel = UILabel()
            bodyLabel.text = "Check out the latest updates and improvements to your app experience..."
            bodyLabel.font = UIFont.systemFont(ofSize: 14)
            bodyLabel.textColor = ThemeColors.current.textSecondary
            bodyLabel.numberOfLines = 2
            cell.addSubview(bodyLabel)

            unreadDot.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(16)
                make.leading.equalToSuperview().offset(12)
                make.width.height.equalTo(10)
            }
            titleLabel.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(12)
                make.leading.equalTo(unreadDot.snp.trailing).offset(8)
                make.trailing.equalToSuperview().offset(-12)
            }
            sourceLabel.snp.makeConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(4)
                make.leading.equalTo(titleLabel)
            }
            timeLabel.snp.makeConstraints { make in
                make.centerY.equalTo(sourceLabel)
                make.trailing.equalToSuperview().offset(-12)
            }
            bodyLabel.snp.makeConstraints { make in
                make.top.equalTo(sourceLabel.snp.bottom).offset(6)
                make.leading.equalTo(titleLabel)
                make.trailing.equalToSuperview().offset(-12)
                make.bottom.equalToSuperview().offset(-12)
            }

            return cell
        }

        let unreadCell = createMessageCell(isUnread: true)
        unreadCell.snp.makeConstraints { make in
            make.height.equalTo(90)
        }

        let readCell = createMessageCell(isUnread: false)
        readCell.snp.makeConstraints { make in
            make.height.equalTo(90)
        }

        let stack = UIStackView(arrangedSubviews: [unreadCell, readCell])
        stack.axis = .vertical
        stack.spacing = ThemeSpacing.default.sm

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(200)
        }
        addSection(header, container)
    }

    // MARK: - Section 13: Token Card

    private func buildTokenCardSection() {
        let header = makeSectionHeader(
            title: "Token Card (PushTokenCardCell)",
            tokenInfo: "PushTokenCardCell — gradient background, URL, device token, copy button"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_TokenCard"

        let cardView = TokenCardDemoView()
        container.addSubview(cardView)
        cardView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(4)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(110)
        }
        addSection(header, container)
    }

    // MARK: - Section 14: Quick Actions

    private func buildQuickActionsSection() {
        let header = makeSectionHeader(
            title: "Quick Actions",
            tokenInfo: "Home page quick actions — Scan, Paste, Token, Debug"
        )

        let actions: [(icon: String, title: String, color: UIColor)] = [
            ("qrcode.viewfinder", "Scan", .systemBlue),
            ("doc.on.clipboard", "Paste", .systemOrange),
            ("text.badge.star", "Token", .systemPurple),
            ("ladybug", "Debug", .systemGreen)
        ]

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_QuickActions"
        container.backgroundColor = ThemeColors.current.surface
        container.layer.cornerRadius = ThemeCornerRadius.default.lg

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8

        for action in actions {
            let btn = UIButton(type: .system)
            btn.backgroundColor = .secondarySystemGroupedBackground
            btn.layer.cornerRadius = 12

            let iconView = UIImageView()
            iconView.image = UIImage(systemName: action.icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium))
            iconView.tintColor = action.color
            iconView.contentMode = .scaleAspectFit

            let titleLabel = UILabel()
            titleLabel.text = action.title
            titleLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            titleLabel.textColor = action.color
            titleLabel.textAlignment = .center

            let innerStack = UIStackView(arrangedSubviews: [iconView, titleLabel])
            innerStack.axis = .vertical
            innerStack.alignment = .center
            innerStack.spacing = 4
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

    private func buildFilterPillsSection() {
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
        stack.spacing = 8
        stack.alignment = .center

        for (title, isSelected) in filters {
            let button: UIButton
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.filled()
                config.baseBackgroundColor = isSelected ? ThemeColors.current.primary : .secondarySystemFill
                config.baseForegroundColor = isSelected ? .white : .secondaryLabel
                config.cornerStyle = .capsule
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var outgoing = incoming
                    outgoing.font = .systemFont(ofSize: 13, weight: .medium)
                    return outgoing
                }
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                button = UIButton(configuration: config)
            } else {
                button = UIButton(type: .system)
                button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
                button.backgroundColor = isSelected ? ThemeColors.current.primary : .secondarySystemFill
                button.setTitleColor(isSelected ? .white : .secondaryLabel, for: .normal)
                button.layer.cornerRadius = 16
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

    private func buildFABSection() {
        let header = makeSectionHeader(
            title: "Floating Action Button (FAB)",
            tokenInfo: "FAB — fabBackground, cornerRadius: 28, shadow: Fab preset"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_FAB"

        let fab = UIButton(type: .system)
        fab.setImage(LucideIcon.bell.image(pointSize: 22, weight: .semibold), for: .normal)
        fab.backgroundColor = ThemeColors.current.fabBackground
        fab.tintColor = .white
        fab.layer.cornerRadius = 28
        fab.layer.shadowColor = UIColor.black.cgColor
        fab.layer.shadowOffset = CGSize(width: 0, height: 4)
        fab.layer.shadowRadius = 8
        fab.layer.shadowOpacity = 0.3
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

    private func buildMenuItemsSection() {
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
            titleLbl.font = UIFont.systemFont(ofSize: 16, weight: .regular)
            titleLbl.textColor = ThemeColors.current.text
            row.addSubview(titleLbl)

            let valueLbl = UILabel()
            valueLbl.text = value
            valueLbl.font = UIFont.systemFont(ofSize: 15, weight: .regular)
            valueLbl.textColor = ThemeColors.current.textSecondary
            valueLbl.textAlignment = .right
            valueLbl.isHidden = value == nil
            row.addSubview(valueLbl)

            let chevronIV = UIImageView()
            chevronIV.image = UIImage(systemName: "chevron.right")
            chevronIV.tintColor = ThemeTokens.Colors.Light.textTertiary
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
            separator.backgroundColor = ThemeTokens.Colors.Light.separator
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

    // MARK: - Helpers

    private func hexString(from color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Token Card Demo View

private class TokenCardDemoView: UIView {

    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 16
        clipsToBounds = true
        gradientLayer.colors = [
            ThemeColors.current.gradientStart.cgColor,
            ThemeColors.current.gradientEnd.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 16
        layer.insertSublayer(gradientLayer, at: 0)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            gradientLayer.colors = [
                ThemeColors.current.gradientStart.cgColor,
                ThemeColors.current.gradientEnd.cgColor
            ]
        }
    }

    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = "Push Token"
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white.withAlphaComponent(0.9)

        let urlLabel = UILabel()
        urlLabel.text = "https://api.day.app"
        urlLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        urlLabel.textColor = .white.withAlphaComponent(0.85)
        urlLabel.numberOfLines = 1

        let tokenLabel = UILabel()
        tokenLabel.text = "Device: a1b2c3d4e5f6..."
        tokenLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        tokenLabel.textColor = .white.withAlphaComponent(0.7)

        let copyButton = UIButton(type: .system)
        copyButton.setImage(UIImage(systemName: "doc.on.doc", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)), for: .normal)
        copyButton.tintColor = .white
        copyButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        copyButton.layer.cornerRadius = 16

        addSubview(titleLabel)
        addSubview(urlLabel)
        addSubview(tokenLabel)
        addSubview(copyButton)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalToSuperview().offset(16)
        }
        urlLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(copyButton.snp.left).offset(-12)
        }
        tokenLabel.snp.makeConstraints { make in
            make.top.equalTo(urlLabel.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(copyButton.snp.left).offset(-12)
            make.bottom.equalToSuperview().offset(-16)
        }
        copyButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }
    }
}
