import XCTest
@testable import WebBridgeKit

final class ThemeButtonTests: XCTestCase {

    // MARK: - Initialization

    func testInitialization() {
        let button = ThemeButton(frame: CGRect(x: 0, y: 0, width: 120, height: 44))
        XCTAssertNotNil(button)
        XCTAssertEqual(button.style, .primary, "Default style should be primary")
        XCTAssertEqual(button.layer.cornerRadius, ThemeCornerRadius.default.md)
    }

    func testInitializationWithZeroFrame() {
        let button = ThemeButton(frame: .zero)
        XCTAssertNotNil(button)
        XCTAssertEqual(button.frame, .zero)
    }

    // MARK: - Style Configuration

    func testConfigureWithPrimaryStyle() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Primary", style: .primary)

        XCTAssertEqual(button.style, .primary)
        XCTAssertEqual(button.backgroundColor, ThemeColors.current.primary)
        XCTAssertEqual(button.titleColor(for: .normal), .white)
        XCTAssertEqual(button.layer.borderWidth, 0, "Primary style should have no border")
    }

    func testConfigureWithSecondaryStyle() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Secondary", style: .secondary)

        XCTAssertEqual(button.style, .secondary)
        XCTAssertEqual(button.backgroundColor, ThemeColors.current.surface)
        XCTAssertEqual(button.titleColor(for: .normal), ThemeColors.current.text)
        XCTAssertEqual(button.layer.borderWidth, 1, "Secondary style should have border")
        XCTAssertNotNil(button.layer.borderColor)
    }

    func testConfigureWithGhostStyle() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Ghost", style: .ghost)

        XCTAssertEqual(button.style, .ghost)
        XCTAssertEqual(button.backgroundColor, .clear)
        XCTAssertEqual(button.titleColor(for: .normal), ThemeColors.current.primary)
        XCTAssertEqual(button.layer.borderWidth, 1, "Ghost style should have border")
        XCTAssertNotNil(button.layer.borderColor)
    }

    func testConfigureWithAllStyles() {
        let styles: [ThemeButtonStyle] = [.primary, .secondary, .ghost]
        for style in styles {
            let button = ThemeButton(frame: .zero)
            button.configure(title: "Test", style: style)
            XCTAssertEqual(button.style, style, "Style should match configured style")
        }
    }

    // MARK: - Title Configuration

    func testConfigureTitle() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Test Title", style: .primary)

        XCTAssertEqual(button.title(for: .normal), "Test Title")
    }

    func testConfigureTitleUpdates() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "First", style: .primary)
        XCTAssertEqual(button.title(for: .normal), "First")

        button.configure(title: "Second", style: .primary)
        XCTAssertEqual(button.title(for: .normal), "Second")
    }

    func testConfigureWithEmptyTitle() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "", style: .primary)

        XCTAssertEqual(button.title(for: .normal), "")
    }

    // MARK: - Icon Configuration

    func testConfigureWithIcon() {
        let button = ThemeButton(frame: .zero)
        button.configure(icon: .settings, style: .ghost)

        XCTAssertNotNil(button.image(for: .normal))
    }

    func testConfigureWithIconAndCustomPointSize() {
        let button = ThemeButton(frame: .zero)
        button.configure(icon: .home, style: .ghost, pointSize: 24)

        XCTAssertNotNil(button.image(for: .normal))
    }

    func testConfigureWithDifferentIcons() {
        let icons: [LucideIcon] = [.home, .settings, .search, .send]
        for icon in icons {
            let button = ThemeButton(frame: .zero)
            button.configure(icon: icon, style: .ghost)
            XCTAssertNotNil(button.image(for: .normal), "Icon \(icon) should produce image")
        }
    }

    func testConfigureIconWithPrimaryStyle() {
        let button = ThemeButton(frame: .zero)
        button.configure(icon: .check, style: .primary)

        XCTAssertNotNil(button.image(for: .normal))
        XCTAssertEqual(button.backgroundColor, ThemeColors.current.primary)
    }

    func testConfigureIconWithSecondaryStyle() {
        let button = ThemeButton(frame: .zero)
        button.configure(icon: .plus, style: .secondary)

        XCTAssertNotNil(button.image(for: .normal))
        XCTAssertEqual(button.backgroundColor, ThemeColors.current.surface)
    }

    // MARK: - Border Configuration

    func testPrimaryStyleHasNoBorder() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Test", style: .primary)

        XCTAssertEqual(button.layer.borderWidth, 0)
        XCTAssertNil(button.layer.borderColor)
    }

    func testSecondaryStyleHasBorder() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Test", style: .secondary)

        XCTAssertEqual(button.layer.borderWidth, 1)
        XCTAssertNotNil(button.layer.borderColor)
        XCTAssertEqual(button.layer.borderColor, ThemeColors.current.border.cgColor)
    }

    func testGhostStyleHasBorder() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Test", style: .ghost)

        XCTAssertEqual(button.layer.borderWidth, 1)
        XCTAssertNotNil(button.layer.borderColor)
        XCTAssertEqual(button.layer.borderColor, ThemeColors.current.primary.withAlphaComponent(0.3).cgColor)
    }

    func testBorderRemovesOnStyleChangeToPrimary() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Test", style: .secondary)
        XCTAssertEqual(button.layer.borderWidth, 1)

        button.configure(title: "Test", style: .primary)
        XCTAssertEqual(button.layer.borderWidth, 0)
    }

    // MARK: - Corner Radius

    func testCornerRadiusOnInitialization() {
        let button = ThemeButton(frame: .zero)
        XCTAssertEqual(button.layer.cornerRadius, ThemeCornerRadius.default.md)
    }

    func testCornerRadiusMatchesTheme() {
        let button = ThemeButton(frame: .zero)
        XCTAssertEqual(button.layer.cornerRadius, ThemeCornerRadius.default.md)
    }

    // MARK: - Font Configuration

    func testTitleFont() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Test", style: .primary)

        XCTAssertNotNil(button.titleLabel?.font)
        XCTAssertEqual(button.titleLabel?.font.pointSize, 15, accuracy: 0.1)
        XCTAssertEqual(button.titleLabel?.font.weight, .medium)
    }

    func testFontIsSetOnSetup() {
        let button = ThemeButton(frame: .zero)
        XCTAssertNotNil(button.titleLabel?.font)
        XCTAssertEqual(button.titleLabel?.font.pointSize, 15, accuracy: 0.1)
    }

    // MARK: - Text Color

    func testPrimaryStyleTextColor() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Test", style: .primary)
        XCTAssertEqual(button.titleColor(for: .normal), .white)
    }

    func testSecondaryStyleTextColor() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Test", style: .secondary)
        XCTAssertEqual(button.titleColor(for: .normal), ThemeColors.current.text)
    }

    func testGhostStyleTextColor() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Test", style: .ghost)
        XCTAssertEqual(button.titleColor(for: .normal), ThemeColors.current.primary)
    }

    // MARK: - Background Color

    func testPrimaryStyleBackgroundColor() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Test", style: .primary)
        XCTAssertEqual(button.backgroundColor, ThemeColors.current.primary)
    }

    func testSecondaryStyleBackgroundColor() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Test", style: .secondary)
        XCTAssertEqual(button.backgroundColor, ThemeColors.current.surface)
    }

    func testGhostStyleBackgroundColor() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Test", style: .ghost)
        XCTAssertEqual(button.backgroundColor, .clear)
    }

    // MARK: - Style Change Updates (didSet)

    func testStyleChangeUpdatesBackgroundColor() {
        let button = ThemeButton(frame: .zero)
        button.style = .primary
        let primaryBg = button.backgroundColor

        button.style = .secondary
        let secondaryBg = button.backgroundColor

        XCTAssertNotEqual(primaryBg, secondaryBg, "Background color should change on style update")
    }

    func testStyleChangeUpdatesTextColor() {
        let button = ThemeButton(frame: .zero)
        button.style = .primary
        let primaryColor = button.titleColor(for: .normal)

        button.style = .secondary
        let secondaryColor = button.titleColor(for: .normal)

        XCTAssertNotEqual(primaryColor, secondaryColor, "Text color should change on style update")
    }

    func testStyleChangeUpdatesBorder() {
        let button = ThemeButton(frame: .zero)
        button.style = .primary
        XCTAssertEqual(button.layer.borderWidth, 0)

        button.style = .secondary
        XCTAssertEqual(button.layer.borderWidth, 1)
    }

    func testStylePropertyDidSet() {
        let button = ThemeButton(frame: .zero)

        button.style = .ghost
        XCTAssertEqual(button.backgroundColor, .clear)
        XCTAssertEqual(button.titleColor(for: .normal), ThemeColors.current.primary)
        XCTAssertEqual(button.layer.borderWidth, 1)

        button.style = .primary
        XCTAssertEqual(button.backgroundColor, ThemeColors.current.primary)
        XCTAssertEqual(button.titleColor(for: .normal), .white)
        XCTAssertEqual(button.layer.borderWidth, 0)
    }

    // MARK: - Theme Style Colors

    func testThemeButtonStyleColors() {
        XCTAssertNotNil(ThemeButtonStyle.primary.backgroundColor)
        XCTAssertNotNil(ThemeButtonStyle.secondary.backgroundColor)
        XCTAssertEqual(ThemeButtonStyle.ghost.backgroundColor, .clear)

        XCTAssertNil(ThemeButtonStyle.primary.borderColor)
        XCTAssertNotNil(ThemeButtonStyle.secondary.borderColor)
        XCTAssertNotNil(ThemeButtonStyle.ghost.borderColor)
    }

    func testPrimaryStyleBorderColorNil() {
        XCTAssertNil(ThemeButtonStyle.primary.borderColor, "Primary style should have no border color")
    }

    func testSecondaryStyleBorderColorNotNil() {
        XCTAssertNotNil(ThemeButtonStyle.secondary.borderColor, "Secondary style should have border color")
        XCTAssertEqual(ThemeButtonStyle.secondary.borderColor, ThemeColors.current.border)
    }

    func testGhostStyleBorderColorNotNil() {
        XCTAssertNotNil(ThemeButtonStyle.ghost.borderColor, "Ghost style should have border color")
        XCTAssertEqual(ThemeButtonStyle.ghost.borderColor, ThemeColors.current.primary.withAlphaComponent(0.3))
    }

    // MARK: - Edge Cases

    func testMultipleButtonsWithDifferentStyles() {
        var buttons: [ThemeButton] = []

        for style in [ThemeButtonStyle.primary, .secondary, .ghost] {
            let button = ThemeButton(frame: .zero)
            button.configure(title: "Test", style: style)
            buttons.append(button)
        }

        XCTAssertEqual(buttons.count, 3)
        XCTAssertEqual(buttons[0].style, .primary)
        XCTAssertEqual(buttons[1].style, .secondary)
        XCTAssertEqual(buttons[2].style, .ghost)
    }

    func testButtonWithVeryLongTitle() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "This Is A Very Long Button Title That Might Wrap", style: .primary)
        XCTAssertNotNil(button.title(for: .normal))
    }

    // MARK: - Theme Integration

    func testButtonUsesThemeCornerRadius() {
        let button = ThemeButton(frame: .zero)
        XCTAssertEqual(button.layer.cornerRadius, ThemeCornerRadius.default.md)
    }

    func testButtonPrimaryColorMatchesTheme() {
        let button = ThemeButton(frame: .zero)
        button.configure(title: "Test", style: .primary)
        XCTAssertEqual(button.backgroundColor, ThemeColors.current.primary)
    }
}
