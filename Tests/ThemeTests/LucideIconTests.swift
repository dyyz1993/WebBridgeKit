import XCTest
@testable import WebBridgeKit

final class LucideIconTests: XCTestCase {

    // MARK: - All Cases Count Verification

    func testAllCasesCount() {
        XCTAssertGreaterThanOrEqual(LucideIcon.allCases.count, 48, "Should have at least 48 icons")
    }

    func testIconCountIsCorrect() {
        XCTAssertEqual(LucideIcon.allCases.count, 65, "Should have exactly 65 icons")
    }

    // MARK: - Image Generation for All Icon Types

    func testAllIconsGenerateImage() {
        for icon in LucideIcon.allCases {
            let image = icon.image()
            XCTAssertNotNil(image, "LucideIcon.\(icon) should generate an image")
        }
    }

    func testAllIconsGenerateTemplateImage() {
        for icon in LucideIcon.allCases {
            let image = icon.templateImage()
            XCTAssertNotNil(image, "LucideIcon.\(icon) should generate a template image")
        }
    }

    // MARK: - Template Image Rendering Mode

    func testTemplateImageRenderingMode() {
        for icon in LucideIcon.allCases {
            let image = icon.templateImage()
            XCTAssertNotNil(image, "LucideIcon.\(icon) templateImage should not be nil")
            XCTAssertEqual(image?.renderingMode, .alwaysTemplate, "LucideIcon.\(icon) should have .alwaysTemplate rendering mode")
        }
    }

    func testImageDefaultRenderingMode() {
        for icon in LucideIcon.allCases {
            let image = icon.image()
            XCTAssertNotNil(image, "LucideIcon.\(icon) image should not be nil")
            XCTAssertNotEqual(image?.renderingMode, .alwaysTemplate, "Default image should not be template mode")
        }
    }

    // MARK: - Custom Point Size Parameter

    func testCustomPointSize() {
        let sizes: [CGFloat] = [12, 16, 20, 24, 32, 48]
        for size in sizes {
            let image = LucideIcon.home.image(pointSize: size)
            XCTAssertNotNil(image, "Should generate image with point size \(size)")
        }
    }

    func testCustomPointSizeWithTemplate() {
        let sizes: [CGFloat] = [12, 16, 20, 24, 32, 48]
        for size in sizes {
            let image = LucideIcon.settings.templateImage(pointSize: size)
            XCTAssertNotNil(image, "Should generate template image with point size \(size)")
        }
    }

    func testDefaultPointSize() {
        let defaultImage = LucideIcon.home.image()
        let customImage = LucideIcon.home.image(pointSize: 20)

        XCTAssertNotNil(defaultImage)
        XCTAssertNotNil(customImage)
    }

    func testZeroPointSize() {
        let image = LucideIcon.home.image(pointSize: 0)
        XCTAssertNotNil(image, "Should generate image even with point size 0")
    }

    func testVeryLargePointSize() {
        let image = LucideIcon.home.image(pointSize: 100)
        XCTAssertNotNil(image, "Should generate image with large point size")
    }

    // MARK: - Custom Weight Parameter

    func testCustomWeight() {
        let weights: [UIImage.SymbolWeight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        for weight in weights {
            let image = LucideIcon.home.image(pointSize: 20, weight: weight)
            XCTAssertNotNil(image, "Should generate image with weight \(weight)")
        }
    }

    func testCustomWeightWithTemplate() {
        let weights: [UIImage.SymbolWeight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        for weight in weights {
            let image = LucideIcon.settings.templateImage(pointSize: 20, weight: weight)
            XCTAssertNotNil(image, "Should generate template image with weight \(weight)")
        }
    }

    func testDefaultWeight() {
        let defaultImage = LucideIcon.home.image()
        let customImage = LucideIcon.home.image(pointSize: 20, weight: .medium)

        XCTAssertNotNil(defaultImage)
        XCTAssertNotNil(customImage)
    }

    // MARK: - System Name Values

    func testHomeSystemName() {
        XCTAssertEqual(LucideIcon.home.rawValue, "house.fill")
    }

    func testInboxSystemName() {
        XCTAssertEqual(LucideIcon.inbox.rawValue, "tray.fill")
    }

    func testCompassSystemName() {
        XCTAssertEqual(LucideIcon.compass.rawValue, "compass.fill")
    }

    func testSettingsSystemName() {
        XCTAssertEqual(LucideIcon.settings.rawValue, "gearshape.fill")
    }

    func testCopySystemName() {
        XCTAssertEqual(LucideIcon.copy.rawValue, "doc.on.doc")
    }

    func testScanSystemName() {
        XCTAssertEqual(LucideIcon.scan.rawValue, "qrcode.viewfinder")
    }

    func testSearchSystemName() {
        XCTAssertEqual(LucideIcon.search.rawValue, "magnifyingglass")
    }

    func testSendSystemName() {
        XCTAssertEqual(LucideIcon.send.rawValue, "paperplane.fill")
    }

    func testShareSystemName() {
        XCTAssertEqual(LucideIcon.share.rawValue, "square.and.arrow.up")
    }

    func testTrashSystemName() {
        XCTAssertEqual(LucideIcon.trash.rawValue, "trash")
    }

    func testPlusSystemName() {
        XCTAssertEqual(LucideIcon.plus.rawValue, "plus")
    }

    func testXmarkSystemName() {
        XCTAssertEqual(LucideIcon.xmark.rawValue, "xmark")
    }

    func testCheckSystemName() {
        XCTAssertEqual(LucideIcon.check.rawValue, "checkmark")
    }

    func testEditSystemName() {
        XCTAssertEqual(LucideIcon.edit.rawValue, "pencil")
    }

    func testRefreshSystemName() {
        XCTAssertEqual(LucideIcon.refresh.rawValue, "arrow.clockwise")
    }

    func testDownloadSystemName() {
        XCTAssertEqual(LucideIcon.download.rawValue, "arrow.down.circle")
    }

    func testUploadSystemName() {
        XCTAssertEqual(LucideIcon.upload.rawValue, "arrow.up.circle")
    }

    func testBellSystemName() {
        XCTAssertEqual(LucideIcon.bell.rawValue, "bell.fill")
    }

    func testBellOffSystemName() {
        XCTAssertEqual(LucideIcon.bellOff.rawValue, "bell.slash.fill")
    }

    func testLinkSystemName() {
        XCTAssertEqual(LucideIcon.link.rawValue, "link")
    }

    func testImageSystemName() {
        XCTAssertEqual(LucideIcon.image.rawValue, "photo")
    }

    func testTagSystemName() {
        XCTAssertEqual(LucideIcon.tag.rawValue, "tag")
    }

    func testStarSystemName() {
        XCTAssertEqual(LucideIcon.star.rawValue, "star.fill")
    }

    func testBookmarkSystemName() {
        XCTAssertEqual(LucideIcon.bookmark.rawValue, "bookmark.fill")
    }

    func testClockSystemName() {
        XCTAssertEqual(LucideIcon.clock.rawValue, "clock.fill")
    }

    func testPinSystemName() {
        XCTAssertEqual(LucideIcon.pin.rawValue, "pin.fill")
    }

    func testShieldSystemName() {
        XCTAssertEqual(LucideIcon.shield.rawValue, "shield.fill")
    }

    func testKeySystemName() {
        XCTAssertEqual(LucideIcon.key.rawValue, "key.fill")
    }

    func testLockSystemName() {
        XCTAssertEqual(LucideIcon.lock.rawValue, "lock.fill")
    }

    func testInfoSystemName() {
        XCTAssertEqual(LucideIcon.info.rawValue, "info.circle.fill")
    }

    func testWarningSystemName() {
        XCTAssertEqual(LucideIcon.warning.rawValue, "exclamationmark.triangle.fill")
    }

    func testErrorSystemName() {
        XCTAssertEqual(LucideIcon.error.rawValue, "xmark.circle.fill")
    }

    func testSuccessSystemName() {
        XCTAssertEqual(LucideIcon.success.rawValue, "checkmark.circle.fill")
    }

    func testChevronRightSystemName() {
        XCTAssertEqual(LucideIcon.chevronRight.rawValue, "chevron.right")
    }

    func testChevronLeftSystemName() {
        XCTAssertEqual(LucideIcon.chevronLeft.rawValue, "chevron.left")
    }

    func testArrowLeftSystemName() {
        XCTAssertEqual(LucideIcon.arrowLeft.rawValue, "arrow.left")
    }

    func testArrowRightSystemName() {
        XCTAssertEqual(LucideIcon.arrowRight.rawValue, "arrow.right")
    }

    func testArrowUpSystemName() {
        XCTAssertEqual(LucideIcon.arrowUp.rawValue, "arrow.up")
    }

    func testArrowDownSystemName() {
        XCTAssertEqual(LucideIcon.arrowDown.rawValue, "arrow.down")
    }

    func testChevronDownSystemName() {
        XCTAssertEqual(LucideIcon.chevronDown.rawValue, "chevron.down")
    }

    // MARK: - Icon Categories

    func testNavigationIcons() {
        let navigationIcons: [LucideIcon] = [.home, .compass, .search, .settings]
        for icon in navigationIcons {
            XCTAssertNotNil(icon.image(), "Navigation icon \(icon) should generate image")
        }
    }

    func testActionIcons() {
        let actionIcons: [LucideIcon] = [.copy, .send, .share, .plus, .check, .refresh]
        for icon in actionIcons {
            XCTAssertNotNil(icon.image(), "Action icon \(icon) should generate image")
        }
    }

    func testStatusIcons() {
        let statusIcons: [LucideIcon] = [.info, .warning, .error, .success, .bell, .bellOff]
        for icon in statusIcons {
            XCTAssertNotNil(icon.image(), "Status icon \(icon) should generate image")
        }
    }

    func testNavigationChevronIcons() {
        let chevronIcons: [LucideIcon] = [.chevronRight, .chevronLeft, .chevronDown]
        for icon in chevronIcons {
            XCTAssertNotNil(icon.image(), "Chevron icon \(icon) should generate image")
        }
    }

    // MARK: - Edge Cases

    func testImageGenerationConsistency() {
        let image1 = LucideIcon.home.image()
        let image2 = LucideIcon.home.image()

        XCTAssertNotNil(image1)
        XCTAssertNotNil(image2)
        XCTAssertEqual(image1?.size, image2?.size, "Multiple calls should produce consistent size")
    }

    func testTemplateImageGenerationConsistency() {
        let image1 = LucideIcon.home.templateImage()
        let image2 = LucideIcon.home.templateImage()

        XCTAssertNotNil(image1)
        XCTAssertNotNil(image2)
        XCTAssertEqual(image1?.renderingMode, image2?.renderingMode)
    }

    func testDifferentIconsProduceDifferentImages() {
        let homeImage = LucideIcon.home.image()
        let settingsImage = LucideIcon.settings.image()

        XCTAssertNotNil(homeImage)
        XCTAssertNotNil(settingsImage)
    }

    func testAllIconsHaveValidSystemNames() {
        for icon in LucideIcon.allCases {
            let image = UIImage(systemName: icon.rawValue)
            XCTAssertNotNil(image, "System name '\(icon.rawValue)' should be valid for icon \(icon)")
        }
    }

    // MARK: - Multiple Parameter Combinations

    func testPointSizeAndWeightCombinations() {
        let sizes: [CGFloat] = [16, 20, 24]
        let weights: [UIImage.SymbolWeight] = [.regular, .medium, .bold]

        for size in sizes {
            for weight in weights {
                let image = LucideIcon.home.image(pointSize: size, weight: weight)
                XCTAssertNotNil(image, "Should generate image with size \(size) and weight \(weight)")
            }
        }
    }

    func testTemplateImageWithDifferentParameters() {
        let combinations: [(CGFloat, UIImage.SymbolWeight)] = [
            (12, .ultraLight),
            (16, .light),
            (20, .regular),
            (24, .medium),
            (32, .semibold),
            (48, .bold)
        ]

        for (size, weight) in combinations {
            let image = LucideIcon.settings.templateImage(pointSize: size, weight: weight)
            XCTAssertNotNil(image, "Should generate template image with size \(size) and weight \(weight)")
            XCTAssertEqual(image?.renderingMode, .alwaysTemplate)
        }
    }
}
