import XCTest
@testable import WebBridgeKit

final class ThemeManagerTests: XCTestCase {

    // MARK: - ThemeColors

    func testThemeColorsAllTokensNonNil() {
        let colors = ThemeColors.current
        XCTAssertNotNil(colors.primary)
        XCTAssertNotNil(colors.secondary)
        XCTAssertNotNil(colors.background)
        XCTAssertNotNil(colors.surface)
        XCTAssertNotNil(colors.text)
        XCTAssertNotNil(colors.textSecondary)
        XCTAssertNotNil(colors.border)
        XCTAssertNotNil(colors.navigationBarBackground)
        XCTAssertNotNil(colors.navigationBarTitle)
        XCTAssertNotNil(colors.tabBarBackground)
        XCTAssertNotNil(colors.success)
        XCTAssertNotNil(colors.warning)
        XCTAssertNotNil(colors.error)
        XCTAssertNotNil(colors.info)
        XCTAssertNotNil(colors.cardBackground)
        XCTAssertNotNil(colors.gradientStart)
        XCTAssertNotNil(colors.gradientEnd)
        XCTAssertNotNil(colors.badgeBackground)
        XCTAssertNotNil(colors.badgeText)
        XCTAssertNotNil(colors.divider)
        XCTAssertNotNil(colors.fabBackground)
    }

    func testThemeColorsDefaultEqualsCurrent() {
        XCTAssertEqual(ThemeColors.default.primary, ThemeColors.current.primary)
    }

    // MARK: - ThemeTypography

    func testThemeTypographyAllFontsValid() {
        let typo = ThemeTypography.current
        XCTAssertGreaterThan(typo.largeTitle.pointSize, 0)
        XCTAssertGreaterThan(typo.title1.pointSize, 0)
        XCTAssertGreaterThan(typo.title2.pointSize, 0)
        XCTAssertGreaterThan(typo.headline.pointSize, 0)
        XCTAssertGreaterThan(typo.body.pointSize, 0)
        XCTAssertGreaterThan(typo.caption1.pointSize, 0)
        XCTAssertGreaterThan(typo.caption2.pointSize, 0)
    }

    // MARK: - ThemeFonts (Legacy)

    func testThemeFontsDefaults() {
        let fonts = ThemeFonts.default
        XCTAssertEqual(fonts.title.pointSize, 28)
        XCTAssertEqual(fonts.headline.pointSize, 17)
        XCTAssertEqual(fonts.body.pointSize, 15)
        XCTAssertEqual(fonts.caption.pointSize, 12)
        XCTAssertEqual(fonts.button.pointSize, 16)
    }

    // MARK: - ThemeSpacing

    func testThemeSpacingValues() {
        let spacing = ThemeSpacing.default
        XCTAssertEqual(spacing.xs, 4)
        XCTAssertEqual(spacing.sm, 8)
        XCTAssertEqual(spacing.md, 16)
        XCTAssertEqual(spacing.lg, 24)
        XCTAssertEqual(spacing.xl, 32)
    }

    // MARK: - ThemeCornerRadius

    func testThemeCornerRadiusValues() {
        let radius = ThemeCornerRadius.default
        XCTAssertEqual(radius.sm, 4)
        XCTAssertEqual(radius.md, 8)
        XCTAssertEqual(radius.lg, 16)
        XCTAssertEqual(radius.full, 999)
    }

    // MARK: - ThemeAnimation

    func testThemeAnimationConstants() {
        XCTAssertEqual(ThemeAnimation.standardDuration, 0.25)
        XCTAssertEqual(ThemeAnimation.springDuration, 0.3)
        XCTAssertEqual(ThemeAnimation.slowDuration, 0.5)
        XCTAssertEqual(ThemeAnimation.springDamping, 0.8)
    }

    // MARK: - ThemeMode

    func testThemeModeCases() {
        let allCases = ThemeMode.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.light))
        XCTAssertTrue(allCases.contains(.dark))
        XCTAssertTrue(allCases.contains(.system))
    }

    func testThemeModeRawValues() {
        XCTAssertEqual(ThemeMode.light.rawValue, "light")
        XCTAssertEqual(ThemeMode.dark.rawValue, "dark")
        XCTAssertEqual(ThemeMode.system.rawValue, "system")
    }

    // MARK: - LucideIcon

    func testLucideIconAllCasesReturnNonNil() {
        for icon in LucideIcon.allCases {
            XCTAssertNotNil(icon.image(), "LucideIcon.\(icon) returned nil image")
        }
    }

    func testLucideIconTemplateImageRenderingMode() {
        for icon in LucideIcon.allCases {
            let img = icon.templateImage()
            XCTAssertNotNil(img, "LucideIcon.\(icon) templateImage returned nil")
            XCTAssertEqual(img?.renderingMode, .alwaysTemplate, "LucideIcon.\(icon) not template mode")
        }
    }

    func testLucideIconCount() {
        XCTAssertGreaterThanOrEqual(LucideIcon.allCases.count, 48, "Should have at least 48 icons")
    }

    // MARK: - ThemeCard

    func testThemeCardInitialization() {
        let card = ThemeCard(frame: .zero)
        XCTAssertNotNil(card)
        XCTAssertEqual(card.innerContentView.layer.cornerRadius, ThemeCornerRadius.default.lg)
    }

    // MARK: - ThemeBadge

    func testThemeBadgeStyleVariants() {
        let styles: [ThemeBadgeStyle] = [.success, .warning, .error, .info, .default]
        for style in styles {
            let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
            badge.configure(text: "Test", style: style)
            XCTAssertNotNil(badge.backgroundColor)
        }
    }

    func testThemeBadgeStyleColors() {
        XCTAssertNotNil(ThemeBadgeStyle.success.backgroundColor)
        XCTAssertNotNil(ThemeBadgeStyle.warning.backgroundColor)
        XCTAssertNotNil(ThemeBadgeStyle.error.backgroundColor)
        XCTAssertNotNil(ThemeBadgeStyle.info.backgroundColor)
        XCTAssertNotNil(ThemeBadgeStyle.default.backgroundColor)
        XCTAssertNotNil(ThemeBadgeStyle.success.textColor)
        XCTAssertNotNil(ThemeBadgeStyle.warning.textColor)
        XCTAssertNotNil(ThemeBadgeStyle.error.textColor)
        XCTAssertNotNil(ThemeBadgeStyle.info.textColor)
        XCTAssertNotNil(ThemeBadgeStyle.default.textColor)
    }

    // MARK: - ThemeButton

    func testThemeButtonPrimaryStyle() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Primary", style: .primary)
        XCTAssertEqual(button.style, .primary)
    }

    func testThemeButtonSecondaryStyle() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Secondary", style: .secondary)
        XCTAssertEqual(button.style, .secondary)
    }

    func testThemeButtonGhostStyle() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Ghost", style: .ghost)
        XCTAssertEqual(button.style, .ghost)
    }

    func testThemeButtonStyleColors() {
        XCTAssertNotNil(ThemeButtonStyle.primary.backgroundColor)
        XCTAssertNotNil(ThemeButtonStyle.secondary.backgroundColor)
        XCTAssertEqual(ThemeButtonStyle.ghost.backgroundColor, .clear)
        XCTAssertNil(ThemeButtonStyle.primary.borderColor)
        XCTAssertNotNil(ThemeButtonStyle.secondary.borderColor)
        XCTAssertNotNil(ThemeButtonStyle.ghost.borderColor)
    }

    // MARK: - ThemeEmptyState

    func testThemeEmptyStateInitialization() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.configure(icon: .inbox, title: "Empty", description: "Nothing here")
        XCTAssertNotNil(empty)
    }

    // MARK: - ThemeSectionHeader

    func testThemeSectionHeaderInitialization() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "Section")
        XCTAssertNotNil(header)
    }

    func testThemeSectionHeaderWithAction() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        var actionCalled = false
        header.onAction = { actionCalled = true }
        header.configure(title: "Section", actionTitle: "See All")
        header.onAction?()
        XCTAssertTrue(actionCalled)
    }

    // MARK: - ThemeGradientView

    func testThemeGradientViewGradientApplied() {
        let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        view.layoutIfNeeded()
        guard let gradient = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("No gradient layer found")
            return
        }
        XCTAssertNotNil(gradient.colors)
        XCTAssertEqual(gradient.colors?.count, 2)
        XCTAssertEqual(gradient.cornerRadius, ThemeCornerRadius.default.lg)
    }

    // MARK: - Theme (Legacy)

    func testThemeDefault() {
        let theme = Theme.default
        XCTAssertFalse(theme.isDark)
        XCTAssertEqual(theme.name, "default")
    }

    func testThemeDark() {
        let theme = Theme.dark
        XCTAssertTrue(theme.isDark)
        XCTAssertEqual(theme.name, "dark")
    }
}
