import XCTest
@testable import WebBridgeKit

private func assertColorsEqual(_ actual: UIColor?, _ expected: UIColor?, file: StaticString = #file, line: UInt = #line) {
    guard let actual = actual, let expected = expected else {
        XCTAssertEqual(actual, expected, file: file, line: line)
        return
    }
    let trait = UITraitCollection(userInterfaceStyle: .light)
    XCTAssertEqual(actual.resolvedColor(with: trait), expected.resolvedColor(with: trait), file: file, line: line)
}

final class ThemeBadgeTests: XCTestCase {

    // MARK: - Initialization

    func testInitialization() {
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        XCTAssertNotNil(badge)
        XCTAssertEqual(badge.layer.cornerRadius, ThemeCornerRadius.default.sm)
        XCTAssertTrue(badge.clipsToBounds)
    }

    func testInitializationWithZeroFrame() {
        let badge = ThemeBadge(frame: .zero)
        XCTAssertNotNil(badge)
        XCTAssertEqual(badge.frame, .zero)
    }

    // MARK: - Style Configuration

    func testConfigureWithSuccessStyle() {
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        badge.configure(text: "Success", style: .success)

        assertColorsEqual(badge.backgroundColor, ThemeTokens.Color.success.withAlphaComponent(0.12))
        XCTAssertNotNil(badge.backgroundColor)
    }

    func testConfigureWithWarningStyle() {
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        badge.configure(text: "Warning", style: .warning)

        assertColorsEqual(badge.backgroundColor, ThemeTokens.Color.warning.withAlphaComponent(0.12))
        XCTAssertNotNil(badge.backgroundColor)
    }

    func testConfigureWithErrorStyle() {
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        badge.configure(text: "Error", style: .error)

        assertColorsEqual(badge.backgroundColor, ThemeTokens.Color.error.withAlphaComponent(0.12))
        XCTAssertNotNil(badge.backgroundColor)
    }

    func testConfigureWithInfoStyle() {
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        badge.configure(text: "Info", style: .info)

        assertColorsEqual(badge.backgroundColor, ThemeTokens.Color.info.withAlphaComponent(0.12))
        XCTAssertNotNil(badge.backgroundColor)
    }

    func testConfigureWithDefaultStyle() {
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        badge.configure(text: "Default", style: .default)

        assertColorsEqual(badge.backgroundColor, ThemeTokens.Color.badgeBackground)
        XCTAssertNotNil(badge.backgroundColor)
    }

    func testConfigureWithAllStyles() {
        let styles: [ThemeBadgeStyle] = [.success, .warning, .error, .info, .default]
        for style in styles {
            let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
            badge.configure(text: "Test", style: style)
            XCTAssertNotNil(badge.backgroundColor, "Style \(style) should have background color")
        }
    }

    // MARK: - Custom Color Configuration

    func testConfigureWithCustomColor() {
        let customColor = UIColor.systemPurple
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        badge.configure(text: "Custom", color: customColor)

        let expectedBackgroundColor = customColor.withAlphaComponent(0.12)
        XCTAssertEqual(badge.backgroundColor, expectedBackgroundColor)
    }

    func testCustomColorAlphaValue() {
        let customColor = UIColor.systemRed
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        badge.configure(text: "Test", color: customColor)

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        badge.backgroundColor?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(alpha, 0.12, accuracy: 0.01, "Alpha should be 0.12 for background")
    }

    // MARK: - Style Colors

    func testThemeBadgeStyleColorsNonNil() {
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

    func testThemeBadgeStyleSuccessColors() {
        assertColorsEqual(ThemeBadgeStyle.success.backgroundColor, ThemeTokens.Color.success.withAlphaComponent(0.12))
        assertColorsEqual(ThemeBadgeStyle.success.textColor, ThemeTokens.Color.success)
    }

    func testThemeBadgeStyleWarningColors() {
        assertColorsEqual(ThemeBadgeStyle.warning.backgroundColor, ThemeTokens.Color.warning.withAlphaComponent(0.12))
        assertColorsEqual(ThemeBadgeStyle.warning.textColor, ThemeTokens.Color.warning)
    }

    func testThemeBadgeStyleErrorColors() {
        assertColorsEqual(ThemeBadgeStyle.error.backgroundColor, ThemeTokens.Color.error.withAlphaComponent(0.12))
        assertColorsEqual(ThemeBadgeStyle.error.textColor, ThemeTokens.Color.error)
    }

    func testThemeBadgeStyleInfoColors() {
        assertColorsEqual(ThemeBadgeStyle.info.backgroundColor, ThemeTokens.Color.info.withAlphaComponent(0.12))
        assertColorsEqual(ThemeBadgeStyle.info.textColor, ThemeTokens.Color.info)
    }

    func testThemeBadgeStyleDefaultColors() {
        assertColorsEqual(ThemeBadgeStyle.default.backgroundColor, ThemeTokens.Color.badgeBackground)
        assertColorsEqual(ThemeBadgeStyle.default.textColor, ThemeTokens.Color.badgeText)
    }

    // MARK: - Label Properties

    func testLabelFont() {
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        badge.configure(text: "Test", style: .default)
        badge.layoutIfNeeded()

        let label = badge.subviews.first as? UILabel
        XCTAssertNotNil(label)
        let fontSize = label?.font.pointSize ?? 0
        XCTAssertEqual(fontSize, CGFloat(10), accuracy: 0.1)
        let traits = label?.font.fontDescriptor.symbolicTraits ?? []
        XCTAssertTrue(traits.contains(.traitBold))
    }

    func testLabelTextAlignment() {
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        badge.configure(text: "Test", style: .default)
        badge.layoutIfNeeded()

        let label = badge.subviews.first as? UILabel
        XCTAssertNotNil(label)
        XCTAssertEqual(label?.textAlignment, .center)
    }

    func testLabelTextColorUpdates() {
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        badge.configure(text: "Test", style: .success)

        let label = badge.subviews.first as? UILabel
        assertColorsEqual(label?.textColor, ThemeTokens.Color.success)

        badge.configure(text: "Test2", style: .error)
        assertColorsEqual(label?.textColor, ThemeTokens.Color.error)
    }

    // MARK: - Layout and Constraints

    func testLabelConstraintsApplied() {
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        badge.configure(text: "Test", style: .default)
        badge.layoutIfNeeded()

        XCTAssertEqual(badge.subviews.count, 1, "Should have exactly one subview (label)")
    }

    func testBadgeWithLongText() {
        let longText = "Very Long Badge Text"
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 150, height: 24))
        badge.configure(text: longText, style: .default)
        badge.layoutIfNeeded()

        let label = badge.subviews.first as? UILabel
        XCTAssertNotNil(label)
        XCTAssertEqual(label?.text, longText)
    }

    func testBadgeWithEmptyText() {
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        badge.configure(text: "", style: .default)
        badge.layoutIfNeeded()

        let label = badge.subviews.first as? UILabel
        XCTAssertNotNil(label)
        XCTAssertEqual(label?.text, "")
    }

    // MARK: - Edge Cases

    func testReconfigurationUpdatesAllProperties() {
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))

        badge.configure(text: "First", style: .success)
        let firstBackgroundColor = badge.backgroundColor

        badge.configure(text: "Second", style: .error)
        let secondBackgroundColor = badge.backgroundColor

        XCTAssertNotEqual(firstBackgroundColor, secondBackgroundColor, "Background color should change on reconfiguration")
    }

    func testMultipleBadgesWithDifferentStyles() {
        var badges: [ThemeBadge] = []

        for style in [ThemeBadgeStyle.success, .warning, .error, .info, .default] {
            let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
            badge.configure(text: "Test", style: style)
            badges.append(badge)
        }

        XCTAssertEqual(badges.count, 5)

        for badge in badges {
            XCTAssertNotNil(badge.backgroundColor)
        }
    }

    // MARK: - Theme Integration

    func testBadgeUsesThemeCornerRadius() {
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        XCTAssertEqual(badge.layer.cornerRadius, ThemeCornerRadius.default.sm)
    }

    func testBadgeColorsMatchThemeColors() {
        let badge = ThemeBadge(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        badge.configure(text: "Test", style: .default)

        assertColorsEqual(badge.backgroundColor, ThemeTokens.Color.badgeBackground)

        let label = badge.subviews.first as? UILabel
        assertColorsEqual(label?.textColor, ThemeTokens.Color.badgeText)
    }
}
