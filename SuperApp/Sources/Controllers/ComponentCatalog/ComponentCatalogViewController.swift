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

    let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.accessibilityIdentifier = "ComponentCatalogScrollView"
        return sv
    }()

    let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.alignment = .fill
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UI Component Catalog"
        view.backgroundColor = ThemeTokens.Color.background
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
            make.leading.trailing.equalToSuperview().inset(ThemeTokens.Spacing.md)
            make.width.equalTo(scrollView).offset(-ThemeTokens.Spacing.md * 2)
        }
    }

    // MARK: - Section Builder

    func buildSections() {
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

    func makeSectionHeader(title: String, tokenInfo: String) -> UIView {
        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_\(title)"

        let titleLabel: UILabel = {
            let label = UILabel()
            label.text = title
            label.font = ThemeTokens.Typography.title3
            label.textColor = ThemeTokens.Color.text
            return label
        }()

        let subtitleLabel: UILabel = {
            let label = UILabel()
            label.text = tokenInfo
            label.font = ThemeTokens.Typography.caption1
            label.textColor = ThemeTokens.Color.textSecondary
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
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: ThemeTokens.Spacing.md, left: 0, bottom: ThemeTokens.Spacing.sm, right: 0))
        }
        return wrapper
    }

    func addSection(_ headerView: UIView, _ contentView: UIView) {
        contentStackView.addArrangedSubview(headerView)
        contentStackView.addArrangedSubview(contentView)
        addSpacer(height: ThemeTokens.Spacing.lg)
    }

    func addSpacer(height: CGFloat) {
        let spacer = UIView()
        spacer.snp.makeConstraints { make in
            make.height.equalTo(height)
        }
        contentStackView.addArrangedSubview(spacer)
    }
}
