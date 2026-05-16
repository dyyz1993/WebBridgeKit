import XCTest
@testable import WebBridgeKit

final class ThemeEmptyStateTests: XCTestCase {

    // MARK: - Initialization

    func testInitialization() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        XCTAssertNotNil(empty)
        XCTAssertEqual(empty.subviews.count, 3, "Should have icon, title, and description labels")
    }

    func testInitializationWithZeroFrame() {
        let empty = ThemeEmptyState(frame: .zero)
        XCTAssertNotNil(empty)
        XCTAssertEqual(empty.frame, .zero)
    }

    // MARK: - Icon Configuration with LucideIcon

    func testConfigureWithLucideIcon() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.configure(icon: .inbox, title: "Empty", description: "No items")

        XCTAssertNotNil(empty.subviews.first as? UIImageView, "First subview should be image view")
        let imageView = empty.subviews.first as? UIImageView
        XCTAssertNotNil(imageView?.image)
    }

    func testConfigureWithDifferentLucideIcons() {
        let icons: [LucideIcon] = [.inbox, .search, .folder, .home]
        for icon in icons {
            let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
            empty.configure(icon: icon, title: "Title", description: "Desc")

            let imageView = empty.subviews.first as? UIImageView
            XCTAssertNotNil(imageView?.image, "Icon \(icon) should produce an image")
        }
    }

    func testConfigureWithLucideIconInbox() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.configure(icon: .inbox, title: "Test", description: "Test desc")

        let imageView = empty.subviews.first as? UIImageView
        XCTAssertNotNil(imageView?.image)
    }

    func testConfigureWithLucideIconSearch() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.configure(icon: .search, title: "Test", description: "Test desc")

        let imageView = empty.subviews.first as? UIImageView
        XCTAssertNotNil(imageView?.image)
    }

    // MARK: - Icon Configuration with System Name String

    func testConfigureWithSystemName() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.configure(icon: "tray.fill", title: "Empty", description: "No items")

        let imageView = empty.subviews.first as? UIImageView
        XCTAssertNotNil(imageView?.image)
    }

    func testConfigureWithMultipleSystemNames() {
        let systemNames = ["tray.fill", "folder.fill", "doc.text.fill"]
        for name in systemNames {
            let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
            empty.configure(icon: name, title: "Title", description: "Desc")

            let imageView = empty.subviews.first as? UIImageView
            XCTAssertNotNil(imageView?.image, "System name '\(name)' should produce an image")
        }
    }

    func testConfigureWithInvalidSystemName() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.configure(icon: "invalid.icon.name", title: "Title", description: "Desc")

        let imageView = empty.subviews.first as? UIImageView
        XCTAssertNotNil(imageView, "Image view should exist even with invalid icon")
    }

    // MARK: - Title and Description Configuration

    func testConfigureTitle() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.configure(icon: .inbox, title: "Empty Title", description: "Description")

        let titleLabel = empty.subviews[1] as? UILabel
        XCTAssertNotNil(titleLabel)
        XCTAssertEqual(titleLabel?.text, "Empty Title")
    }

    func testConfigureDescription() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.configure(icon: .inbox, title: "Title", description: "This is a description")

        let descriptionLabel = empty.subviews[2] as? UILabel
        XCTAssertNotNil(descriptionLabel)
        XCTAssertEqual(descriptionLabel?.text, "This is a description")
    }

    func testConfigureUpdatesTitle() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.configure(icon: .inbox, title: "First Title", description: "Desc")

        let titleLabel = empty.subviews[1] as? UILabel
        XCTAssertEqual(titleLabel?.text, "First Title")

        empty.configure(icon: .inbox, title: "Second Title", description: "Desc")
        XCTAssertEqual(titleLabel?.text, "Second Title")
    }

    func testConfigureUpdatesDescription() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.configure(icon: .inbox, title: "Title", description: "First Description")

        let descriptionLabel = empty.subviews[2] as? UILabel
        XCTAssertEqual(descriptionLabel?.text, "First Description")

        empty.configure(icon: .inbox, title: "Title", description: "Second Description")
        XCTAssertEqual(descriptionLabel?.text, "Second Description")
    }

    // MARK: - Typography and Text Colors

    func testTitleFont() {
        let empty = ThemeEmptyState(frame: .zero)
        let titleLabel = empty.subviews[1] as? UILabel

        XCTAssertNotNil(titleLabel)
        XCTAssertEqual(titleLabel?.font, ThemeTypography.current.title2)
    }

    func testTitleColor() {
        let empty = ThemeEmptyState(frame: .zero)
        let titleLabel = empty.subviews[1] as? UILabel

        XCTAssertNotNil(titleLabel)
        XCTAssertEqual(titleLabel?.textColor, ThemeColors.current.text)
    }

    func testTitleTextAlignment() {
        let empty = ThemeEmptyState(frame: .zero)
        let titleLabel = empty.subviews[1] as? UILabel

        XCTAssertNotNil(titleLabel)
        XCTAssertEqual(titleLabel?.textAlignment, .center)
    }

    func testTitleNumberOfLines() {
        let empty = ThemeEmptyState(frame: .zero)
        let titleLabel = empty.subviews[1] as? UILabel

        XCTAssertNotNil(titleLabel)
        XCTAssertEqual(titleLabel?.numberOfLines, 0, "Title should support multiple lines")
    }

    func testDescriptionFont() {
        let empty = ThemeEmptyState(frame: .zero)
        let descriptionLabel = empty.subviews[2] as? UILabel

        XCTAssertNotNil(descriptionLabel)
        XCTAssertEqual(descriptionLabel?.font, ThemeTypography.current.body)
    }

    func testDescriptionColor() {
        let empty = ThemeEmptyState(frame: .zero)
        let descriptionLabel = empty.subviews[2] as? UILabel

        XCTAssertNotNil(descriptionLabel)
        XCTAssertEqual(descriptionLabel?.textColor, ThemeColors.current.textSecondary)
    }

    func testDescriptionTextAlignment() {
        let empty = ThemeEmptyState(frame: .zero)
        let descriptionLabel = empty.subviews[2] as? UILabel

        XCTAssertNotNil(descriptionLabel)
        XCTAssertEqual(descriptionLabel?.textAlignment, .center)
    }

    func testDescriptionNumberOfLines() {
        let empty = ThemeEmptyState(frame: .zero)
        let descriptionLabel = empty.subviews[2] as? UILabel

        XCTAssertNotNil(descriptionLabel)
        XCTAssertEqual(descriptionLabel?.numberOfLines, 0, "Description should support multiple lines")
    }

    // MARK: - Icon Properties

    func testIconSize() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.layoutIfNeeded()

        let imageView = empty.subviews.first as? UIImageView
        XCTAssertNotNil(imageView)
        XCTAssertEqual(imageView?.bounds.width ?? 0, 64, accuracy: 0.1, "Icon should be 64x64 points")
        XCTAssertEqual(imageView?.bounds.height ?? 0, 64, accuracy: 0.1)
    }

    func testIconTintColor() {
        let empty = ThemeEmptyState(frame: .zero)
        let imageView = empty.subviews.first as? UIImageView

        XCTAssertNotNil(imageView)
        XCTAssertEqual(imageView?.tintColor, ThemeColors.current.textSecondary)
    }

    func testIconContentMode() {
        let empty = ThemeEmptyState(frame: .zero)
        let imageView = empty.subviews.first as? UIImageView

        XCTAssertNotNil(imageView)
        XCTAssertEqual(imageView?.contentMode, .scaleAspectFit)
    }

    func testIconIsTemplateRenderingMode() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.configure(icon: .inbox, title: "Title", description: "Desc")

        let imageView = empty.subviews.first as? UIImageView
        XCTAssertNotNil(imageView?.image)
        XCTAssertEqual(imageView?.image?.renderingMode, .alwaysTemplate)
    }

    // MARK: - Layout Constraints

    func testIconConstraints() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.layoutIfNeeded()

        let imageView = empty.subviews.first as? UIImageView
        XCTAssertNotNil(imageView)
        XCTAssertEqual(imageView?.center.x ?? 0, 150, accuracy: 1, "Icon should be centered horizontally")
        XCTAssertEqual(imageView?.frame.minY ?? 0, 0, accuracy: 1, "Icon should be at top")
    }

    func testTitleConstraints() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.configure(icon: .inbox, title: "Title", description: "Desc")
        empty.layoutIfNeeded()

        let titleLabel = empty.subviews[1] as? UILabel
        XCTAssertNotNil(titleLabel)
        XCTAssertEqual(titleLabel?.frame.minY ?? 0, 64 + ThemeSpacing.default.md, accuracy: 1, "Title should be below icon with md spacing")
    }

    func testDescriptionConstraints() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.configure(icon: .inbox, title: "Title", description: "Description")
        empty.layoutIfNeeded()

        let titleLabel = empty.subviews[1] as? UILabel
        let descriptionLabel = empty.subviews[2] as? UILabel
        XCTAssertNotNil(descriptionLabel)

        let expectedMinY = (titleLabel?.frame.maxY ?? 0) + ThemeSpacing.default.sm
        XCTAssertEqual(descriptionLabel?.frame.minY ?? 0, expectedMinY, accuracy: 1, "Description should be below title with sm spacing")
    }

    func testLeadingTrailingConstraints() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.layoutIfNeeded()

        let titleLabel = empty.subviews[1] as? UILabel
        let descriptionLabel = empty.subviews[2] as? UILabel

        XCTAssertEqual(titleLabel?.frame.minX ?? 0, 0, accuracy: 1)
        XCTAssertEqual(titleLabel?.frame.maxX ?? 0, 300, accuracy: 1)
        XCTAssertEqual(descriptionLabel?.frame.minX ?? 0, 0, accuracy: 1)
        XCTAssertEqual(descriptionLabel?.frame.maxX ?? 0, 300, accuracy: 1)
    }

    // MARK: - Edge Cases

    func testEmptyConfiguration() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        empty.configure(icon: .inbox, title: "", description: "")

        let titleLabel = empty.subviews[1] as? UILabel
        let descriptionLabel = empty.subviews[2] as? UILabel

        XCTAssertEqual(titleLabel?.text, "")
        XCTAssertEqual(descriptionLabel?.text, "")
    }

    func testLongTitleAndDescription() {
        let longTitle = "This Is A Very Long Title That Might Wrap To Multiple Lines"
        let longDesc = "This is a very long description that should wrap to multiple lines when displayed in the empty state view component"
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        empty.configure(icon: .inbox, title: longTitle, description: longDesc)

        let titleLabel = empty.subviews[1] as? UILabel
        let descriptionLabel = empty.subviews[2] as? UILabel

        XCTAssertEqual(titleLabel?.text, longTitle)
        XCTAssertEqual(descriptionLabel?.text, longDesc)
    }

    func testZeroHeight() {
        let empty = ThemeEmptyState(frame: CGRect(x: 0, y: 0, width: 300, height: 0))
        XCTAssertNotNil(empty)
        empty.layoutIfNeeded()
    }

    // MARK: - Theme Typography Integration

    func testTitleUsesThemeTypography() {
        let empty = ThemeEmptyState(frame: .zero)
        let titleLabel = empty.subviews[1] as? UILabel
        XCTAssertEqual(titleLabel?.font, ThemeTypography.current.title2)
    }

    func testDescriptionUsesThemeTypography() {
        let empty = ThemeEmptyState(frame: .zero)
        let descriptionLabel = empty.subviews[2] as? UILabel
        XCTAssertEqual(descriptionLabel?.font, ThemeTypography.current.body)
    }

    func testAllTypographyElements() {
        let empty = ThemeEmptyState(frame: .zero)
        let titleLabel = empty.subviews[1] as? UILabel
        let descriptionLabel = empty.subviews[2] as? UILabel

        XCTAssertEqual(titleLabel?.font, ThemeTypography.current.title2)
        XCTAssertEqual(descriptionLabel?.font, ThemeTypography.current.body)
        XCTAssertEqual(titleLabel?.textColor, ThemeColors.current.text)
        XCTAssertEqual(descriptionLabel?.textColor, ThemeColors.current.textSecondary)
    }
}
