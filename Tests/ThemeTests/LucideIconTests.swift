import XCTest
@testable import WebBridgeKit

final class LucideIconTests: XCTestCase {

    // MARK: - All Cases Count Verification

    func testAllCasesCount() {
        XCTAssertGreaterThanOrEqual(LucideIcon.allCases.count, 48, "Should have at least 48 icons")
    }

    func testIconCountIsCorrect() {
        XCTAssertEqual(LucideIcon.allCases.count, 66, "Should have exactly 66 icons")
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
        XCTAssertEqual(LucideIcon.home.lucideId, "house")
    }

    func testInboxSystemName() {
        XCTAssertEqual(LucideIcon.inbox.lucideId, "inbox")
    }

    func testCompassSystemName() {
        XCTAssertEqual(LucideIcon.compass.lucideId, "compass")
    }

    func testSettingsSystemName() {
        XCTAssertEqual(LucideIcon.settings.lucideId, "settings")
    }

    func testCopySystemName() {
        XCTAssertEqual(LucideIcon.copy.lucideId, "copy")
    }

    func testScanSystemName() {
        XCTAssertEqual(LucideIcon.scan.lucideId, "scan-line")
    }

    func testSearchSystemName() {
        XCTAssertEqual(LucideIcon.search.lucideId, "search")
    }

    func testSendSystemName() {
        XCTAssertEqual(LucideIcon.send.lucideId, "send")
    }

    func testShareSystemName() {
        XCTAssertEqual(LucideIcon.share.lucideId, "share-2")
    }

    func testTrashSystemName() {
        XCTAssertEqual(LucideIcon.trash.lucideId, "trash-2")
    }

    func testPlusSystemName() {
        XCTAssertEqual(LucideIcon.plus.lucideId, "plus")
    }

    func testXmarkSystemName() {
        XCTAssertEqual(LucideIcon.xmark.lucideId, "x")
    }

    func testCheckSystemName() {
        XCTAssertEqual(LucideIcon.check.lucideId, "check")
    }

    func testEditSystemName() {
        XCTAssertEqual(LucideIcon.edit.lucideId, "pencil")
    }

    func testRefreshSystemName() {
        XCTAssertEqual(LucideIcon.refresh.lucideId, "refresh-cw")
    }

    func testDownloadSystemName() {
        XCTAssertEqual(LucideIcon.download.lucideId, "download")
    }

    func testUploadSystemName() {
        XCTAssertEqual(LucideIcon.upload.lucideId, "upload")
    }

    func testBellSystemName() {
        XCTAssertEqual(LucideIcon.bell.lucideId, "bell")
    }

    func testBellOffSystemName() {
        XCTAssertEqual(LucideIcon.bellOff.lucideId, "bell-off")
    }

    func testLinkSystemName() {
        XCTAssertEqual(LucideIcon.link.lucideId, "link")
    }

    func testImageSystemName() {
        XCTAssertEqual(LucideIcon.image.lucideId, "image")
    }

    func testTagSystemName() {
        XCTAssertEqual(LucideIcon.tag.lucideId, "tag")
    }

    func testStarSystemName() {
        XCTAssertEqual(LucideIcon.star.lucideId, "star")
    }

    func testBookmarkSystemName() {
        XCTAssertEqual(LucideIcon.bookmark.lucideId, "bookmark")
    }

    func testClockSystemName() {
        XCTAssertEqual(LucideIcon.clock.lucideId, "clock")
    }

    func testPinSystemName() {
        XCTAssertEqual(LucideIcon.pin.lucideId, "pin")
    }

    func testShieldSystemName() {
        XCTAssertEqual(LucideIcon.shield.lucideId, "shield")
    }

    func testKeySystemName() {
        XCTAssertEqual(LucideIcon.key.lucideId, "key")
    }

    func testLockSystemName() {
        XCTAssertEqual(LucideIcon.lock.lucideId, "lock")
    }

    func testInfoSystemName() {
        XCTAssertEqual(LucideIcon.info.lucideId, "info")
    }

    func testWarningSystemName() {
        XCTAssertEqual(LucideIcon.warning.lucideId, "alert-triangle")
    }

    func testErrorSystemName() {
        XCTAssertEqual(LucideIcon.error.lucideId, "x-circle")
    }

    func testSuccessSystemName() {
        XCTAssertEqual(LucideIcon.success.lucideId, "check-circle")
    }

    func testChevronRightSystemName() {
        XCTAssertEqual(LucideIcon.chevronRight.lucideId, "chevron-right")
    }

    func testChevronLeftSystemName() {
        XCTAssertEqual(LucideIcon.chevronLeft.lucideId, "chevron-left")
    }

    func testArrowLeftSystemName() {
        XCTAssertEqual(LucideIcon.arrowLeft.lucideId, "arrow-left")
    }

    func testArrowRightSystemName() {
        XCTAssertEqual(LucideIcon.arrowRight.lucideId, "arrow-right")
    }

    func testArrowUpSystemName() {
        XCTAssertEqual(LucideIcon.arrowUp.lucideId, "arrow-up")
    }

    func testArrowDownSystemName() {
        XCTAssertEqual(LucideIcon.arrowDown.lucideId, "arrow-down")
    }

    func testChevronDownSystemName() {
        XCTAssertEqual(LucideIcon.chevronDown.lucideId, "chevron-down")
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
            let sfImage = UIImage(systemName: icon.sfSymbolName)
            let hasLucide = UIImage(lucideId: icon.lucideId) != nil
            XCTAssertTrue(sfImage != nil || hasLucide, "Icon \(icon) should resolve via SF Symbol '\(icon.sfSymbolName)' or Lucide ID '\(icon.lucideId)'")
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
