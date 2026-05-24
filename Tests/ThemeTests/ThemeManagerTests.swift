import XCTest
@testable import WebBridgeKit

final class ThemeManagerTests: XCTestCase {

    // MARK: - ThemeTokens.Color

    func testThemeTokensColorAllNonNil() {
        let tokens: [UIColor] = [
            ThemeTokens.Color.primary,
            ThemeTokens.Color.secondary,
            ThemeTokens.Color.background,
            ThemeTokens.Color.surface,
            ThemeTokens.Color.text,
            ThemeTokens.Color.textSecondary,
            ThemeTokens.Color.border,
            ThemeTokens.Color.navigationBarBackground,
            ThemeTokens.Color.navigationBarTitle,
            ThemeTokens.Color.tabBarBackground,
            ThemeTokens.Color.success,
            ThemeTokens.Color.warning,
            ThemeTokens.Color.error,
            ThemeTokens.Color.info,
            ThemeTokens.Color.cardBackground,
            ThemeTokens.Color.gradientStart,
            ThemeTokens.Color.gradientEnd,
            ThemeTokens.Color.badgeBackground,
            ThemeTokens.Color.badgeText,
            ThemeTokens.Color.divider,
            ThemeTokens.Color.fabBackground,
        ]
        for (index, color) in tokens.enumerated() {
            XCTAssertNotNil(color, "ThemeTokens.Color token at index \(index) is nil")
        }
    }

    func testThemeTokensColorPrimaryConsistency() {
        let trait = UITraitCollection(userInterfaceStyle: .light)
        let resolved = ThemeTokens.Color.primary.resolvedColor(with: trait)
        XCTAssertNotNil(resolved)
    }

    // MARK: - ThemeTokens.Typography

    func testThemeTokensTypographyAllFontsValid() {
        let fonts: [UIFont] = [
            ThemeTokens.Typography.largeTitle,
            ThemeTokens.Typography.title1,
            ThemeTokens.Typography.title3,
            ThemeTokens.Typography.headline,
            ThemeTokens.Typography.body,
            ThemeTokens.Typography.caption1,
            ThemeTokens.Typography.caption2,
        ]
        for (index, font) in fonts.enumerated() {
            XCTAssertGreaterThan(font.pointSize, 0, "Typography token at index \(index) has invalid pointSize")
        }
    }

    // MARK: - ThemeTokens.Typography (Legacy Font Sizes)

    func testThemeTokensLegacyFontSizes() {
        XCTAssertEqual(ThemeTokens.Typography.largeTitle.pointSize, 28)
        XCTAssertEqual(ThemeTokens.Typography.headline.pointSize, 17)
        XCTAssertEqual(ThemeTokens.Typography.body.pointSize, 17)
        XCTAssertEqual(ThemeTokens.Typography.caption1.pointSize, 12)
        XCTAssertEqual(ThemeTokens.Typography.callout.pointSize, 16)
    }

    // MARK: - ThemeTokens.Spacing

    func testThemeTokensSpacingValues() {
        XCTAssertEqual(ThemeTokens.Spacing.xs, 4)
        XCTAssertEqual(ThemeTokens.Spacing.sm, 8)
        XCTAssertEqual(ThemeTokens.Spacing.md, 16)
        XCTAssertEqual(ThemeTokens.Spacing.lg, 24)
        XCTAssertEqual(ThemeTokens.Spacing.xl, 32)
    }

    // MARK: - ThemeTokens.CornerRadius

    func testThemeTokensCornerRadiusValues() {
        XCTAssertEqual(ThemeTokens.CornerRadius.sm, 4)
        XCTAssertEqual(ThemeTokens.CornerRadius.md, 8)
        XCTAssertEqual(ThemeTokens.CornerRadius.lg, 12)
        XCTAssertEqual(ThemeTokens.CornerRadius.full, 999)
    }

    // MARK: - ThemeAnimation (deprecated → ThemeTokens.Animation)

    func testThemeAnimationConstants() {
        XCTAssertEqual(ThemeTokens.Animation.normal.duration, 0.25)
        XCTAssertEqual(ThemeTokens.Animation.spring.duration, 0.5)
        XCTAssertEqual(ThemeTokens.Animation.slow.duration, 0.4)
        XCTAssertEqual(ThemeTokens.Animation.spring.damping, 0.85)
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
        XCTAssertEqual(card.innerContentView.layer.cornerRadius, ThemeTokens.CornerRadius.lg)
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
        XCTAssertEqual(view.layer.cornerRadius, ThemeTokens.CornerRadius.lg)
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
