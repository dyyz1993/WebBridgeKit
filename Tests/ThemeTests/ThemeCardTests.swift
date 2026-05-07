import XCTest
@testable import WebBridgeKit

final class ThemeCardTests: XCTestCase {

    // MARK: - Initialization

    func testInitialization() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        XCTAssertNotNil(card)
        XCTAssertEqual(card.subviews.count, 1, "Should have one subview (content view)")
    }

    func testInitializationWithZeroFrame() {
        let card = ThemeCard(frame: .zero)
        XCTAssertNotNil(card)
        XCTAssertEqual(card.frame, .zero)
    }

    // MARK: - Inner Content View

    func testInnerContentViewProperty() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let innerView = card.innerContentView

        XCTAssertNotNil(innerView)
        XCTAssertTrue(innerView.layer.cornerRadius > 0)
    }

    func testInnerContentViewCornerRadius() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        XCTAssertEqual(card.innerContentView.layer.cornerRadius, ThemeCornerRadius.default.lg)
    }

    func testInnerContentViewIsAccessible() {
        let card = ThemeCard(frame: .zero)
        let innerView = card.innerContentView
        XCTAssertEqual(innerView, card.subviews.first, "innerContentView should return the first subview")
    }

    // MARK: - Shadow Properties

    func testShadowOffset() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let contentView = card.innerContentView

        XCTAssertEqual(contentView.layer.shadowOffset.width, 0, accuracy: 0.1)
        XCTAssertEqual(contentView.layer.shadowOffset.height, 4, accuracy: 0.1)
    }

    func testShadowRadius() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let contentView = card.innerContentView

        XCTAssertEqual(contentView.layer.shadowRadius, 12, accuracy: 0.1)
    }

    func testShadowOpacity() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let contentView = card.innerContentView

        XCTAssertEqual(contentView.layer.shadowOpacity, 0.08, accuracy: 0.01)
    }

    func testShadowColor() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let contentView = card.innerContentView

        XCTAssertEqual(contentView.layer.shadowColor, UIColor.black.cgColor)
    }

    func testAllShadowProperties() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let contentView = card.innerContentView

        XCTAssertEqual(contentView.layer.shadowColor, UIColor.black.cgColor)
        XCTAssertEqual(contentView.layer.shadowOffset.width, 0, accuracy: 0.1)
        XCTAssertEqual(contentView.layer.shadowOffset.height, 4, accuracy: 0.1)
        XCTAssertEqual(contentView.layer.shadowRadius, 12, accuracy: 0.1)
        XCTAssertEqual(contentView.layer.shadowOpacity, 0.08, accuracy: 0.01)
    }

    // MARK: - Corner Radius

    func testCardCornerRadius() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        XCTAssertEqual(card.innerContentView.layer.cornerRadius, ThemeCornerRadius.default.lg)
    }

    func testCornerRadiusMatchesTheme() {
        let card = ThemeCard(frame: .zero)
        XCTAssertEqual(card.innerContentView.layer.cornerRadius, ThemeCornerRadius.default.lg)
    }

    // MARK: - Background Color

    func testBackgroundColorAfterLayout() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        card.layoutIfNeeded()

        XCTAssertEqual(card.innerContentView.backgroundColor, ThemeColors.current.cardBackground)
    }

    func testBackgroundColorUpdatesOnSecondLayout() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        card.layoutIfNeeded()
        let firstColor = card.innerContentView.backgroundColor

        card.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        card.layoutIfNeeded()
        let secondColor = card.innerContentView.backgroundColor

        XCTAssertEqual(firstColor, secondColor, "Color should remain consistent across layouts")
    }

    // MARK: - Add Content

    func testAddContentSubview() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let label = UILabel()

        card.addContent(label)

        XCTAssertTrue(card.innerContentView.subviews.contains(label), "Label should be added to inner content view")
    }

    func testAddContentMultipleViews() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let label1 = UILabel()
        let label2 = UILabel()
        let button = UIButton()

        card.addContent(label1)
        card.addContent(label2)
        card.addContent(button)

        XCTAssertEqual(card.innerContentView.subviews.count, 3, "Should have 3 added subviews")
        XCTAssertTrue(card.innerContentView.subviews.contains(label1))
        XCTAssertTrue(card.innerContentView.subviews.contains(label2))
        XCTAssertTrue(card.innerContentView.subviews.contains(button))
    }

    func testAddContentViewConstraint() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let label = UILabel()

        card.addContent(label)

        XCTAssertEqual(label.superview, card.innerContentView, "Label's superview should be inner content view")
    }

    // MARK: - Layout and Constraints

    func testContentViewFillsCard() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        card.layoutIfNeeded()

        let contentView = card.innerContentView
        XCTAssertEqual(contentView.frame, card.bounds, "Content view should fill card bounds")
    }

    func testContentViewConstraints() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        card.layoutIfNeeded()

        let contentView = card.innerContentView
        XCTAssertEqual(contentView.frame.minX, 0, accuracy: 0.1)
        XCTAssertEqual(contentView.frame.minY, 0, accuracy: 0.1)
        XCTAssertEqual(contentView.frame.width, 300, accuracy: 0.1)
        XCTAssertEqual(contentView.frame.height, 200, accuracy: 0.1)
    }

    func testCardResizeWithContentView() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        card.layoutIfNeeded()

        card.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        card.layoutIfNeeded()

        let contentView = card.innerContentView
        XCTAssertEqual(contentView.frame.width, 400, accuracy: 0.1)
        XCTAssertEqual(contentView.frame.height, 300, accuracy: 0.1)
    }

    // MARK: - Theme Integration

    func testCardBackgroundColorMatchesTheme() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        card.layoutIfNeeded()

        XCTAssertEqual(card.innerContentView.backgroundColor, ThemeColors.current.cardBackground)
    }

    func testCardCornerRadiusMatchesTheme() {
        let card = ThemeCard(frame: .zero)
        XCTAssertEqual(card.innerContentView.layer.cornerRadius, ThemeCornerRadius.default.lg)
    }

    // MARK: - Edge Cases

    func testCardWithZeroSize() {
        let card = ThemeCard(frame: .zero)
        XCTAssertNotNil(card.innerContentView)
        card.layoutIfNeeded()
    }

    func testMultipleCards() {
        var cards: [ThemeCard] = []
        for _ in 0..<5 {
            let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
            cards.append(card)
        }

        XCTAssertEqual(cards.count, 5)

        for card in cards {
            XCTAssertNotNil(card.innerContentView)
            XCTAssertEqual(card.innerContentView.layer.cornerRadius, ThemeCornerRadius.default.lg)
        }
    }

    func testCardContentNotClipped() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        XCTAssertEqual(card.clipsToBounds, false, "Card itself should not clip")
    }

    func testInnerContentViewNotClipped() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        XCTAssertEqual(card.innerContentView.clipsToBounds, false, "Inner content view should not clip")
    }

    func testShadowVisible() {
        let card = ThemeCard(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let contentView = card.innerContentView

        XCTAssertGreaterThan(contentView.layer.shadowOpacity, 0, "Shadow should be visible (opacity > 0)")
        XCTAssertLessThan(contentView.layer.shadowOpacity, 1, "Shadow opacity should be less than 1")
    }
}
