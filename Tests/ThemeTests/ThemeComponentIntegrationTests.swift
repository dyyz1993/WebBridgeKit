import XCTest
@testable import WebBridgeKit

final class ThemeComponentIntegrationTests: XCTestCase {

    // MARK: - Card with Button Inside

    func testCardWithButtonInside() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 150))
        card.layoutIfNeeded()

        let button = ThemeButton(frame: CGRect(x: 20, y: 20, width: 260, height: 44))
        button.configure(title: "Action Button", style: .primary)

        card.addContent(button)
        card.layoutIfNeeded()

        XCTAssertTrue(card.innerContentView.subviews.contains(button))
        XCTAssertEqual(button.superview, card.innerContentView)
        XCTAssertEqual(button.style, .primary)
    }

    func testCardWithMultipleButtons() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        card.layoutIfNeeded()

        let primaryButton = ThemeButton(frame: CGRect(x: 20, y: 20, width: 120, height: 44))
        primaryButton.configure(title: "Primary", style: .primary)

        let secondaryButton = ThemeButton(frame: CGRect(x: 160, y: 20, width: 120, height: 44))
        secondaryButton.configure(title: "Secondary", style: .secondary)

        card.addContent(primaryButton)
        card.addContent(secondaryButton)
        card.layoutIfNeeded()

        XCTAssertEqual(card.innerContentView.subviews.count, 2)
        XCTAssertEqual(primaryButton.style, .primary)
        XCTAssertEqual(secondaryButton.style, .secondary)
    }

    // MARK: - Card with Badge and Button

    func testCardWithBadgeAndButton() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 150))
        card.layoutIfNeeded()

        let badge = ThemeBadge(frame: CGRect(x: 20, y: 20, width: 60, height: 24))
        badge.configure(text: "New", style: .success)

        let button = ThemeButton(frame: CGRect(x: 20, y: 60, width: 260, height: 44))
        button.configure(title: "View Details", style: .primary)

        card.addContent(badge)
        card.addContent(button)
        card.layoutIfNeeded()

        XCTAssertTrue(card.innerContentView.subviews.contains(badge))
        XCTAssertTrue(card.innerContentView.subviews.contains(button))
        XCTAssertEqual(badge.backgroundColor, ThemeColors.current.success.withAlphaComponent(0.12))
    }

    func testCardWithMultipleBadges() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        card.layoutIfNeeded()

        let styles: [ThemeBadgeStyle] = [.success, .warning, .error, .info]
        var badges: [ThemeBadge] = []

        for (index, style) in styles.enumerated() {
            let badge = ThemeBadge(frame: CGRect(x: 20, y: CGFloat(20 + index * 30), width: 80, height: 24))
            badge.configure(text: "Badge \(index)", style: style)
            card.addContent(badge)
            badges.append(badge)
        }

        card.layoutIfNeeded()

        XCTAssertEqual(card.innerContentView.subviews.count, 4)
        for badge in badges {
            XCTAssertTrue(card.innerContentView.subviews.contains(badge))
        }
    }

    // MARK: - Card with Gradient Background

    func testCardWithGradientBackground() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))

        let gradientView = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        container.addSubview(gradientView)

        let card = ThemeCard(frame: CGRect(x: 10, y: 10, width: 280, height: 180))
        gradientView.addSubview(card)
        gradientView.layoutIfNeeded()

        XCTAssertEqual(container.subviews.count, 1)
        XCTAssertEqual(gradientView.subviews.count, 1)
        XCTAssertTrue(gradientView.subviews.contains(card))
    }

    func testGradientViewAsCardBackground() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        card.layoutIfNeeded()

        let gradientView = ThemeGradientView(frame: card.innerContentView.bounds)
        card.innerContentView.insertSubview(gradientView, at: 0)
        gradientView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        card.layoutIfNeeded()

        XCTAssertTrue(card.innerContentView.subviews.contains(gradientView))
        XCTAssertEqual(gradientView.frame, card.innerContentView.bounds)
    }

    // MARK: - Section Header Leading to Card Grid

    func testSectionHeaderWithCards() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 500))

        let header = ThemeSectionHeader(frame: CGRect(x: 10, y: 10, width: 300, height: 44))
        header.configure(title: "Recent Items", actionTitle: "See All")
        container.addSubview(header)

        var cards: [ThemeCard] = []
        for i in 0..<4 {
            let card = ThemeCard(frame: CGRect(x: 10 + (i % 2) * 155, y: 60 + (i / 2) * 110, width: 150, height: 100))
            cards.append(card)
            container.addSubview(card)
        }

        container.layoutIfNeeded()

        XCTAssertEqual(container.subviews.count, 5)
        XCTAssertTrue(container.subviews.contains(header))
        for card in cards {
            XCTAssertTrue(container.subviews.contains(card))
        }
    }

    func testSectionHeaderActionCallback() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        var actionCalled = false

        header.onAction = { actionCalled = true }
        header.configure(title: "Section", actionTitle: "See All")

        let actionButton = header.subviews[1] as? UIButton
        actionButton?.sendActions(for: .touchUpInside)

        XCTAssertTrue(actionCalled)
    }

    // MARK: - Empty State Within a Card

    func testEmptyStateInCard() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        card.layoutIfNeeded()

        let empty = ThemeEmptyState(frame: card.innerContentView.bounds)
        empty.configure(icon: .inbox, title: "No Items", description: "Your list is empty")

        card.addContent(empty)
        card.layoutIfNeeded()

        XCTAssertTrue(card.innerContentView.subviews.contains(empty))
    }

    func testEmptyStateWithActionInCard() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 240))
        container.addSubview(card)

        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 280, height: 180))
        empty.configure(icon: .folder, title: "No Files", description: "No files found")
        card.addContent(empty)

        let button = ThemeButton(frame: CGRect(x: 20, y: 200, width: 260, height: 44))
        button.configure(title: "Add File", style: .primary)
        container.addSubview(button)

        container.layoutIfNeeded()

        XCTAssertTrue(card.innerContentView.subviews.contains(empty))
        XCTAssertTrue(container.subviews.contains(button))
    }

    // MARK: - Button with Different Styles in a Card

    func testCardWithAllButtonStyles() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        card.layoutIfNeeded()

        let primaryButton = ThemeButton(frame: CGRect(x: 20, y: 20, width: 260, height: 44))
        primaryButton.configure(title: "Primary", style: .primary)

        let secondaryButton = ThemeButton(frame: CGRect(x: 20, y: 75, width: 260, height: 44))
        secondaryButton.configure(title: "Secondary", style: .secondary)

        let ghostButton = ThemeButton(frame: CGRect(x: 20, y: 130, width: 260, height: 44))
        ghostButton.configure(title: "Ghost", style: .ghost)

        card.addContent(primaryButton)
        card.addContent(secondaryButton)
        card.addContent(ghostButton)
        card.layoutIfNeeded()

        XCTAssertEqual(primaryButton.style, .primary)
        XCTAssertEqual(primaryButton.backgroundColor, ThemeColors.current.primary)

        XCTAssertEqual(secondaryButton.style, .secondary)
        XCTAssertEqual(secondaryButton.backgroundColor, ThemeColors.current.surface)
        XCTAssertEqual(secondaryButton.layer.borderWidth, 1)

        XCTAssertEqual(ghostButton.style, .ghost)
        XCTAssertEqual(ghostButton.backgroundColor, .clear)
        XCTAssertEqual(ghostButton.layer.borderWidth, 1)
    }

    func testCardWithIconButtons() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        card.layoutIfNeeded()

        let editButton = ThemeButton(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
        editButton.configure(icon: .edit, style: .ghost)

        let deleteButton = ThemeButton(frame: CGRect(x: 75, y: 20, width: 40, height: 40))
        deleteButton.configure(icon: .trash, style: .ghost)

        let shareButton = ThemeButton(frame: CGRect(x: 130, y: 20, width: 40, height: 40))
        shareButton.configure(icon: .share, style: .ghost)

        card.addContent(editButton)
        card.addContent(deleteButton)
        card.addContent(shareButton)
        card.layoutIfNeeded()

        XCTAssertEqual(card.innerContentView.subviews.count, 3)
        XCTAssertNotNil(editButton.image(for: .normal))
        XCTAssertNotNil(deleteButton.image(for: .normal))
        XCTAssertNotNil(shareButton.image(for: .normal))
    }

    // MARK: - Multiple Badges with Different Styles

    func testBadgeStyleGrid() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))

        let styles: [ThemeBadgeStyle] = [.success, .warning, .error, .info, .default]
        var badges: [ThemeBadge] = []

        for (index, style) in styles.enumerated() {
            let badge = ThemeBadge(frame: CGRect(x: 10 + CGFloat(index) * 60, y: 20, width: 60, height: 24))
            badge.configure(text: "\(style)", style: style)
            container.addSubview(badge)
            badges.append(badge)
        }

        container.layoutIfNeeded()

        XCTAssertEqual(container.subviews.count, 5)

        for (index, badge) in badges.enumerated() {
            let style = styles[index]
            XCTAssertEqual(badge.backgroundColor, style.backgroundColor)
            let label = badge.subviews.first as? UILabel
            XCTAssertEqual(label?.textColor, style.textColor)
        }
    }

    // MARK: - Full Screen Layout Using Multiple Components

    func testFullScreenLayout() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 812))

        let header = ThemeSectionHeader(frame: CGRect(x: 20, y: 20, width: 335, height: 44))
        header.configure(title: "Dashboard")
        container.addSubview(header)

        let card1 = ThemeCard(frame: CGRect(x: 20, y: 80, width: 335, height: 150))
        container.addSubview(card1)

        let gradientView = ThemeGradientView(frame: CGRect(x: 20, y: 250, width: 335, height: 100))
        container.addSubview(gradientView)

        let card2 = ThemeCard(frame: CGRect(x: 20, y: 370, width: 335, height: 120))
        container.addSubview(card2)

        let button = ThemeButton(frame: CGRect(x: 20, y: 750, width: 335, height: 50))
        button.configure(title: "Action", style: .primary)
        container.addSubview(button)

        container.layoutIfNeeded()

        XCTAssertEqual(container.subviews.count, 5)
        XCTAssertTrue(container.subviews.contains(header))
        XCTAssertTrue(container.subviews.contains(card1))
        XCTAssertTrue(container.subviews.contains(gradientView))
        XCTAssertTrue(container.subviews.contains(card2))
        XCTAssertTrue(container.subviews.contains(button))
    }

    func testComplexCardWithMultipleComponents() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 250))
        card.layoutIfNeeded()

        let badge = ThemeBadge(frame: CGRect(x: 20, y: 20, width: 60, height: 24))
        badge.configure(text: "New", style: .success)
        card.addContent(badge)

        let title = UILabel(frame: CGRect(x: 20, y: 55, width: 260, height: 24))
        title.text = "Card Title"
        title.font = ThemeTypography.current.headline
        card.addContent(title)

        let description = UILabel(frame: CGRect(x: 20, y: 85, width: 260, height: 40))
        description.text = "This is a description"
        description.font = ThemeTypography.current.body
        description.textColor = ThemeColors.current.textSecondary
        card.addContent(description)

        let button = ThemeButton(frame: CGRect(x: 20, y: 140, width: 260, height: 44))
        button.configure(title: "Learn More", style: .primary)
        card.addContent(button)

        card.layoutIfNeeded()

        XCTAssertEqual(card.innerContentView.subviews.count, 4)
    }

    // MARK: - Theme Mode Changes Affecting All Components

    func testThemeColorsConsistency() {
        let primaryColor = ThemeColors.current.primary

        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        badge.configure(text: "Test", style: .info)

        let button = ThemeButton(frame: .zero)
        button.configure(title: "Test", style: .primary)

        XCTAssertEqual(button.backgroundColor, primaryColor)
        XCTAssertEqual(badge.backgroundColor, ThemeColors.current.info.withAlphaComponent(0.12))
    }

    func testCornerRadiusConsistency() {
        let cornerRadius = ThemeCornerRadius.default

        let badge = ThemeBadge(frame: .zero)
        let button = ThemeButton(frame: .zero)
        let card = ThemeCard(frame: .zero)
        let gradientView = ThemeGradientView(frame: .zero)

        XCTAssertEqual(badge.layer.cornerRadius, cornerRadius.sm)
        XCTAssertEqual(button.layer.cornerRadius, cornerRadius.md)
        XCTAssertEqual(card.innerContentView.layer.cornerRadius, cornerRadius.lg)
        XCTAssertEqual(gradientView.layer.cornerRadius, cornerRadius.lg)
    }

    func testTypographyConsistency() {
        let header = ThemeSectionHeader(frame: .zero)
        let empty = ThemeEmptyState(frame: .zero)

        let titleLabel = header.subviews.first as? UILabel
        let emptyTitle = empty.subviews[1] as? UILabel

        XCTAssertEqual(titleLabel?.font, ThemeTypography.current.title2)
        XCTAssertEqual(emptyTitle?.font, ThemeTypography.current.title2)
    }

    // MARK: - Layout Constraint Interactions

    func testNestedLayoutConstraints() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 500))

        let scrollView = UIScrollView(frame: container.bounds)
        container.addSubview(scrollView)

        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
        scrollView.addSubview(contentView)

        let header = ThemeSectionHeader(frame: CGRect(x: 20, y: 20, width: 335, height: 44))
        header.configure(title: "Content")
        contentView.addSubview(header)

        let card1 = ThemeCard(frame: CGRect(x: 20, y: 80, width: 335, height: 150))
        contentView.addSubview(card1)

        let card2 = ThemeCard(frame: CGRect(x: 20, y: 250, width: 335, height: 150))
        contentView.addSubview(card2)

        container.layoutIfNeeded()

        XCTAssertEqual(container.subviews.count, 1)
        XCTAssertEqual(scrollView.subviews.count, 1)
        XCTAssertEqual(contentView.subviews.count, 3)
    }

    func testComponentOverlapPrevention() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 500))

        let card1 = ThemeCard(frame: CGRect(x: 20, y: 20, width: 335, height: 100))
        container.addSubview(card1)

        let card2 = ThemeCard(frame: CGRect(x: 20, y: 140, width: 335, height: 100))
        container.addSubview(card2)

        container.layoutIfNeeded()

        let card1Max = card1.frame.maxY
        let card2Min = card2.frame.minY

        XCTAssertLessThanOrEqual(card1Max, card2Min, "Components should not overlap vertically")
    }

    // MARK: - Performance and Memory

    func testManyComponentsLayoutPerformance() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 2000))

        for i in 0..<20 {
            let card = ThemeCard(frame: CGRect(x: 20, y: CGFloat(i * 100), width: 335, height: 90))
            container.addSubview(card)
        }

        let startTime = Date()
        container.layoutIfNeeded()
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(container.subviews.count, 20)
        XCTAssertLessThan(duration, 1.0, "Layout should complete in less than 1 second")
    }

    func testComponentCreationAndLayout() {
        var components: [UIView] = []

        for i in 0..<10 {
            let badge = ThemeBadge(frame: CGRect(x: 0, y: CGFloat(i * 30), width: 60, height: 24))
            badge.configure(text: "Badge \(i)", style: .default)
            components.append(badge)
        }

        for component in components {
            component.layoutIfNeeded()
        }

        XCTAssertEqual(components.count, 10)
    }

    // MARK: - Real-World Scenarios

    func testUserProfileCard() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        card.layoutIfNeeded()

        let avatarImageView = UIImageView(frame: CGRect(x: 20, y: 20, width: 60, height: 60))
        avatarImageView.backgroundColor = .systemGray
        avatarImageView.layer.cornerRadius = 30
        card.addContent(avatarImageView)

        let nameLabel = UILabel(frame: CGRect(x: 95, y: 25, width: 185, height: 20))
        nameLabel.text = "John Doe"
        nameLabel.font = ThemeTypography.current.headline
        card.addContent(nameLabel)

        let badge = ThemeBadge(frame: CGRect(x: 95, y: 50, width: 60, height: 24))
        badge.configure(text: "Pro", style: .success)
        card.addContent(badge)

        let emailLabel = UILabel(frame: CGRect(x: 20, y: 90, width: 260, height: 20))
        emailLabel.text = "john@example.com"
        emailLabel.font = ThemeTypography.current.body
        emailLabel.textColor = ThemeColors.current.textSecondary
        card.addContent(emailLabel)

        let editButton = ThemeButton(frame: CGRect(x: 20, y: 130, width: 260, height: 44))
        editButton.configure(title: "Edit Profile", style: .primary)
        card.addContent(editButton)

        card.layoutIfNeeded()

        XCTAssertEqual(card.innerContentView.subviews.count, 5)
    }

    func testSettingsList() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 600))

        let header = ThemeSectionHeader(frame: CGRect(x: 20, y: 20, width: 335, height: 44))
        header.configure(title: "Settings")
        container.addSubview(header)

        let settings: [(String, LucideIcon)] = [
            ("Account", .user),
            ("Notifications", .bell),
            ("Privacy", .shield),
            ("Security", .lock),
            ("Help", .info)
        ]

        for (index, (title, icon)) in settings.enumerated() {
            let card = ThemeCard(frame: CGRect(x: 20, y: CGFloat(80 + index * 110), width: 335, height: 100))
            container.addSubview(card)

            let iconImageView = UIImageView(frame: CGRect(x: 20, y: 20, width: 40, height: 40))
            iconImageView.image = icon.templateImage()
            card.addContent(iconImageView)

            let titleLabel = UILabel(frame: CGRect(x: 75, y: 20, width: 240, height: 20))
            titleLabel.text = title
            titleLabel.font = ThemeTypography.current.headline
            card.addContent(titleLabel)

            let button = ThemeButton(frame: CGRect(x: 20, y: 55, width: 295, height: 35))
            button.configure(title: "Configure", style: .ghost)
            card.addContent(button)
        }

        container.layoutIfNeeded()

        XCTAssertEqual(container.subviews.count, 6)
    }
}
