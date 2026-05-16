import XCTest
@testable import WebBridgeKit

final class ThemeSectionHeaderTests: XCTestCase {

    // MARK: - Initialization

    func testInitialization() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        XCTAssertNotNil(header)
        XCTAssertEqual(header.subviews.count, 2, "Should have title label and action button")
    }

    func testInitializationWithZeroFrame() {
        let header = ThemeSectionHeader(frame: .zero)
        XCTAssertNotNil(header)
        XCTAssertEqual(header.frame, .zero)
    }

    // MARK: - Title Configuration

    func testConfigureWithTitleOnly() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "Section Title")

        let titleLabel = header.subviews.first as? UILabel
        XCTAssertNotNil(titleLabel)
        XCTAssertEqual(titleLabel?.text, "Section Title")
    }

    func testConfigureWithTitleUpdates() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "First Title")

        let titleLabel = header.subviews.first as? UILabel
        XCTAssertEqual(titleLabel?.text, "First Title")

        header.configure(title: "Second Title")
        XCTAssertEqual(titleLabel?.text, "Second Title")
    }

    func testConfigureWithEmptyTitle() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "")

        let titleLabel = header.subviews.first as? UILabel
        XCTAssertEqual(titleLabel?.text, "")
    }

    func testConfigureWithLongTitle() {
        let longTitle = "This Is A Very Long Section Title That Might Wrap"
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: longTitle)

        let titleLabel = header.subviews.first as? UILabel
        XCTAssertEqual(titleLabel?.text, longTitle)
    }

    // MARK: - Action Button Configuration

    func testConfigureWithActionTitle() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "Section", actionTitle: "See All")

        let actionButton = header.subviews[1] as? UIButton
        XCTAssertNotNil(actionButton)
        XCTAssertEqual(actionButton?.title(for: .normal), "See All")
        XCTAssertFalse(actionButton?.isHidden ?? true, "Action button should be visible when action title is set")
    }

    func testConfigureWithoutActionTitle() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "Section")

        let actionButton = header.subviews[1] as? UIButton
        XCTAssertNotNil(actionButton)
        XCTAssertTrue(actionButton?.isHidden ?? false, "Action button should be hidden when no action title")
    }

    func testConfigureWithNilActionTitle() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "Section", actionTitle: nil)

        let actionButton = header.subviews[1] as? UIButton
        XCTAssertTrue(actionButton?.isHidden ?? false, "Action button should be hidden with nil action title")
    }

    func testConfigureUpdatesActionTitle() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "Section", actionTitle: "First Action")

        let actionButton = header.subviews[1] as? UIButton
        XCTAssertEqual(actionButton?.title(for: .normal), "First Action")

        header.configure(title: "Section", actionTitle: "Second Action")
        XCTAssertEqual(actionButton?.title(for: .normal), "Second Action")
    }

    func testConfigureRemovesActionTitle() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "Section", actionTitle: "See All")

        let actionButton = header.subviews[1] as? UIButton
        XCTAssertFalse(actionButton?.isHidden ?? true)

        header.configure(title: "Section", actionTitle: nil)
        XCTAssertTrue(actionButton?.isHidden ?? false)
    }

    // MARK: - Action Button Show/Hide Behavior

    func testActionButtonHiddenInitially() {
        let header = ThemeSectionHeader(frame: .zero)
        let actionButton = header.subviews[1] as? UIButton

        XCTAssertTrue(actionButton?.isHidden ?? false, "Action button should be hidden initially")
    }

    func testActionButtonVisibleWhenTitleSet() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "Section", actionTitle: "Action")

        let actionButton = header.subviews[1] as? UIButton
        XCTAssertFalse(actionButton?.isHidden ?? true)
    }

    func testActionButtonHiddenWhenTitleRemoved() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "Section", actionTitle: "Action")

        let actionButton = header.subviews[1] as? UIButton
        XCTAssertFalse(actionButton?.isHidden ?? true)

        header.configure(title: "Section")
        XCTAssertTrue(actionButton?.isHidden ?? false)
    }

    // MARK: - OnAction Callback

    func testOnActionCallback() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        var callbackCalled = false

        header.onAction = { callbackCalled = true }
        header.configure(title: "Section", actionTitle: "Action")

        let actionButton = header.subviews[1] as? UIButton
        actionButton?.sendActions(for: .touchUpInside)

        XCTAssertTrue(callbackCalled, "onAction callback should be called when button is tapped")
    }

    func testOnActionCallbackNotCalledWhenHidden() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        var callbackCalled = false

        header.onAction = { callbackCalled = true }
        header.configure(title: "Section")

        let actionButton = header.subviews[1] as? UIButton
        actionButton?.sendActions(for: .touchUpInside)

        XCTAssertFalse(callbackCalled, "onAction callback should not be called when button is hidden")
    }

    func testOnActionCallbackMultipleTimes() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        var callCount = 0

        header.onAction = { callCount += 1 }
        header.configure(title: "Section", actionTitle: "Action")

        let actionButton = header.subviews[1] as? UIButton

        actionButton?.sendActions(for: .touchUpInside)
        actionButton?.sendActions(for: .touchUpInside)
        actionButton?.sendActions(for: .touchUpInside)

        XCTAssertEqual(callCount, 3, "onAction callback should be called for each tap")
    }

    func testOnActionCallbackCanBeUpdated() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        var firstCalled = false
        var secondCalled = false

        header.onAction = { firstCalled = true }
        header.configure(title: "Section", actionTitle: "Action")

        let actionButton = header.subviews[1] as? UIButton
        actionButton?.sendActions(for: .touchUpInside)

        header.onAction = { secondCalled = true }
        actionButton?.sendActions(for: .touchUpInside)

        XCTAssertTrue(firstCalled, "First callback should be called")
        XCTAssertTrue(secondCalled, "Second callback should be called")
    }

    // MARK: - Typography and Colors

    func testTitleFont() {
        let header = ThemeSectionHeader(frame: .zero)
        let titleLabel = header.subviews.first as? UILabel

        XCTAssertNotNil(titleLabel)
        XCTAssertEqual(titleLabel?.font, ThemeTypography.current.title2)
    }

    func testTitleColor() {
        let header = ThemeSectionHeader(frame: .zero)
        let titleLabel = header.subviews.first as? UILabel

        XCTAssertNotNil(titleLabel)
        XCTAssertEqual(titleLabel?.textColor, ThemeColors.current.text)
    }

    func testActionButtonFont() {
        let header = ThemeSectionHeader(frame: .zero)
        let actionButton = header.subviews[1] as? UIButton

        XCTAssertNotNil(actionButton)
        XCTAssertEqual(actionButton?.titleLabel?.font, ThemeTypography.current.caption1)
    }

    func testActionButtonColor() {
        let header = ThemeSectionHeader(frame: .zero)
        let actionButton = header.subviews[1] as? UIButton

        XCTAssertNotNil(actionButton)
        XCTAssertEqual(actionButton?.titleColor(for: .normal), ThemeColors.current.primary)
    }

    func testAllTypographyElements() {
        let header = ThemeSectionHeader(frame: .zero)
        let titleLabel = header.subviews.first as? UILabel
        let actionButton = header.subviews[1] as? UIButton

        XCTAssertEqual(titleLabel?.font, ThemeTypography.current.title2)
        XCTAssertEqual(titleLabel?.textColor, ThemeColors.current.text)
        XCTAssertEqual(actionButton?.titleLabel?.font, ThemeTypography.current.caption1)
        XCTAssertEqual(actionButton?.titleColor(for: .normal), ThemeColors.current.primary)
    }

    // MARK: - Layout Constraints

    func testTitleLeadingConstraint() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.layoutIfNeeded()

        let titleLabel = header.subviews.first as? UILabel
        XCTAssertEqual(titleLabel?.frame.minX ?? 0, 0, accuracy: 1, "Title should be at leading edge")
    }

    func testTitleCenteredVertically() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.layoutIfNeeded()

        let titleLabel = header.subviews.first as? UILabel
        XCTAssertNotNil(titleLabel)

        let expectedCenterY = header.bounds.height / 2
        XCTAssertEqual(titleLabel?.center.y ?? 0, expectedCenterY, accuracy: 1, "Title should be vertically centered")
    }

    func testActionButtonTrailingConstraint() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "Section", actionTitle: "Action")
        header.layoutIfNeeded()

        let actionButton = header.subviews[1] as? UIButton
        XCTAssertNotNil(actionButton)

        let expectedMaxX = header.bounds.width
        XCTAssertEqual(actionButton?.frame.maxX ?? 0, expectedMaxX, accuracy: 1, "Action button should be at trailing edge")
    }

    func testActionButtonCenteredVertically() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "Section", actionTitle: "Action")
        header.layoutIfNeeded()

        let actionButton = header.subviews[1] as? UIButton
        XCTAssertNotNil(actionButton)

        let expectedCenterY = header.bounds.height / 2
        XCTAssertEqual(actionButton?.center.y ?? 0, expectedCenterY, accuracy: 1, "Action button should be vertically centered")
    }

    func testConstraintsMaintainedOnResize() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "Section", actionTitle: "Action")
        header.layoutIfNeeded()

        header.frame = CGRect(x: 0, y: 0, width: 400, height: 44)
        header.layoutIfNeeded()

        let titleLabel = header.subviews.first as? UILabel
        let actionButton = header.subviews[1] as? UIButton

        XCTAssertEqual(titleLabel?.frame.minX ?? 0, 0, accuracy: 1)
        XCTAssertEqual(actionButton?.frame.maxX ?? 0, 400, accuracy: 1)
    }

    // MARK: - Action Button Target-Action

    func testActionButtonHasTarget() {
        let header = ThemeSectionHeader(frame: .zero)
        let actionButton = header.subviews[1] as? UIButton

        XCTAssertNotNil(actionButton)
        XCTAssertNotNil(actionButton?.allTargets, "Button should have targets")
    }

    func testActionButtonHasTouchUpInsideAction() {
        let header = ThemeSectionHeader(frame: .zero)
        let actionButton = header.subviews[1] as? UIButton

        XCTAssertNotNil(actionButton)
        let actions = actionButton?.actions(forTarget: header, forControlEvent: .touchUpInside)
        XCTAssertNotNil(actions, "Button should have touchUpInside actions")
        XCTAssertGreaterThan(actions?.count ?? 0, 0, "Button should have at least one action")
    }

    func testOnActionPropertyCanBeNil() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.onAction = nil

        let actionButton = header.subviews[1] as? UIButton
        actionButton?.sendActions(for: .touchUpInside)

        XCTAssertNotNil(header.onAction)
    }

    // MARK: - Theme Typography Integration

    func testTitleUsesThemeTypography() {
        let header = ThemeSectionHeader(frame: .zero)
        let titleLabel = header.subviews.first as? UILabel
        XCTAssertEqual(titleLabel?.font, ThemeTypography.current.title2)
    }

    func testActionButtonUsesThemeTypography() {
        let header = ThemeSectionHeader(frame: .zero)
        let actionButton = header.subviews[1] as? UIButton
        XCTAssertEqual(actionButton?.titleLabel?.font, ThemeTypography.current.caption1)
    }

    func testTitleColorUsesTheme() {
        let header = ThemeSectionHeader(frame: .zero)
        let titleLabel = header.subviews.first as? UILabel
        XCTAssertEqual(titleLabel?.textColor, ThemeColors.current.text)
    }

    func testActionButtonColorUsesTheme() {
        let header = ThemeSectionHeader(frame: .zero)
        let actionButton = header.subviews[1] as? UIButton
        XCTAssertEqual(actionButton?.titleColor(for: .normal), ThemeColors.current.primary)
    }

    // MARK: - Edge Cases

    func testHeaderWithZeroHeight() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 0))
        XCTAssertNotNil(header)
        header.configure(title: "Section")
        header.layoutIfNeeded()
    }

    func testHeaderWithZeroWidth() {
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        XCTAssertNotNil(header)
        header.configure(title: "Section")
        header.layoutIfNeeded()
    }

    func testMultipleHeaders() {
        var headers: [ThemeSectionHeader] = []
        for i in 0..<5 {
            let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
            header.configure(title: "Section \(i)")
            headers.append(header)
        }

        XCTAssertEqual(headers.count, 5)

        for (index, header) in headers.enumerated() {
            let titleLabel = header.subviews.first as? UILabel
            XCTAssertEqual(titleLabel?.text, "Section \(index)")
        }
    }

    func testVeryLongActionTitle() {
        let longAction = "This Is A Very Long Action Title"
        let header = ThemeSectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        header.configure(title: "Section", actionTitle: longAction)

        let actionButton = header.subviews[1] as? UIButton
        XCTAssertEqual(actionButton?.title(for: .normal), longAction)
    }
}
