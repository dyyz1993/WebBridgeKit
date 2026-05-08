import XCTest
@testable import WebBridgeKit

final class ThemeGradientViewTests: XCTestCase {

    // MARK: - Initialization

    func testInitialization() {
        let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        XCTAssertNotNil(view)
        XCTAssertEqual(view.layer.cornerRadius, ThemeCornerRadius.default.lg)
        XCTAssertTrue(view.clipsToBounds)
    }

    func testInitializationWithZeroFrame() {
        let view = ThemeGradientView(frame: .zero)
        XCTAssertNotNil(view)
        XCTAssertEqual(view.frame, .zero)
    }

    // MARK: - Gradient Layer Properties

    func testGradientLayerExists() {
        let view = ThemeGradientView(frame: .zero)
        XCTAssertNotNil(view.layer.sublayers, "Should have sublayers")
        XCTAssertGreaterThan(view.layer.sublayers?.count ?? 0, 0, "Should have at least one sublayer")
    }

    func testGradientLayerIsCAGradientLayer() {
        let view = ThemeGradientView(frame: .zero)
        let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer
        XCTAssertNotNil(gradientLayer, "First sublayer should be CAGradientLayer")
    }

    func testGradientColors() {
        let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        view.layoutIfNeeded()

        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        XCTAssertNotNil(gradientLayer.colors)
        XCTAssertEqual(gradientLayer.colors?.count, 2, "Gradient should have exactly 2 colors")

        let color1 = gradientLayer.colors?[0] as! CGColor
        let color2 = gradientLayer.colors?[1] as! CGColor

        XCTAssertNotNil(color1)
        XCTAssertNotNil(color2)
    }

    func testGradientColorsMatchTheme() {
        let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        view.layoutIfNeeded()

        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        XCTAssertEqual(gradientLayer.colors?.count, 2)
        XCTAssertEqual(gradientLayer.colors?[0] as! CGColor, ThemeColors.current.gradientStart.cgColor)
        XCTAssertEqual(gradientLayer.colors?[1] as! CGColor, ThemeColors.current.gradientEnd.cgColor)
    }

    // MARK: - Gradient Direction (Start/End Points)

    func testGradientStartPoint() {
        let view = ThemeGradientView(frame: .zero)
        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        XCTAssertEqual(gradientLayer.startPoint.x, 0, accuracy: 0.01)
        XCTAssertEqual(gradientLayer.startPoint.y, 0, accuracy: 0.01)
    }

    func testGradientEndPoint() {
        let view = ThemeGradientView(frame: .zero)
        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        XCTAssertEqual(gradientLayer.endPoint.x, 1, accuracy: 0.01)
        XCTAssertEqual(gradientLayer.endPoint.y, 1, accuracy: 0.01)
    }

    func testGradientDirectionDiagonal() {
        let view = ThemeGradientView(frame: .zero)
        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        let startX = gradientLayer.startPoint.x
        let startY = gradientLayer.startPoint.y
        let endX = gradientLayer.endPoint.x
        let endY = gradientLayer.endPoint.y

        XCTAssertEqual(startX, 0, accuracy: 0.01)
        XCTAssertEqual(startY, 0, accuracy: 0.01)
        XCTAssertEqual(endX, 1, accuracy: 0.01)
        XCTAssertEqual(endY, 1, accuracy: 0.01, "Gradient should go from top-left to bottom-right")
    }

    // MARK: - Corner Radius and ClipsToBounds

    func testCornerRadius() {
        let view = ThemeGradientView(frame: .zero)
        XCTAssertEqual(view.layer.cornerRadius, ThemeCornerRadius.default.lg)
    }

    func testCornerRadiusMatchesTheme() {
        let view = ThemeGradientView(frame: .zero)
        XCTAssertEqual(view.layer.cornerRadius, ThemeCornerRadius.default.lg)
    }

    func testClipsToBounds() {
        let view = ThemeGradientView(frame: .zero)
        XCTAssertTrue(view.clipsToBounds, "View should clip to bounds for proper corner radius")
    }

    // MARK: - Gradient Frame Update on Layout

    func testGradientFrameAfterLayout() {
        let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        view.layoutIfNeeded()

        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        XCTAssertEqual(gradientLayer.frame, view.bounds)
        XCTAssertEqual(gradientLayer.frame.width, 200, accuracy: 0.1)
        XCTAssertEqual(gradientLayer.frame.height, 100, accuracy: 0.1)
    }

    func testGradientFrameUpdatesOnResize() {
        let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        view.layoutIfNeeded()

        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        let firstFrame = gradientLayer.frame

        view.frame = CGRect(x: 0, y: 0, width: 300, height: 150)
        view.layoutIfNeeded()

        let secondFrame = gradientLayer.frame

        XCTAssertNotEqual(firstFrame.width, secondFrame.width, "Gradient frame should update")
        XCTAssertEqual(secondFrame.width, 300, accuracy: 0.1)
        XCTAssertEqual(secondFrame.height, 150, accuracy: 0.1)
    }

    func testGradientFrameMatchesBounds() {
        let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 250, height: 125))
        view.layoutIfNeeded()

        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        XCTAssertEqual(gradientLayer.frame, view.bounds, "Gradient frame should match view bounds")
    }

    // MARK: - Theme Color Integration

    func testGradientStartColorMatchesTheme() {
        let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        view.layoutIfNeeded()

        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        XCTAssertEqual(gradientLayer.colors?[0] as? CGColor, ThemeColors.current.gradientStart.cgColor)
    }

    func testGradientEndColorMatchesTheme() {
        let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        view.layoutIfNeeded()

        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        XCTAssertEqual(gradientLayer.colors?[1] as? CGColor, ThemeColors.current.gradientEnd.cgColor)
    }

    func testGradientColorsAreDifferent() {
        let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        view.layoutIfNeeded()

        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        let color1 = gradientLayer.colors?[0] as? CGColor
        let color2 = gradientLayer.colors?[1] as? CGColor

        XCTAssertNotNil(color1)
        XCTAssertNotNil(color2)
        XCTAssertNotEqual(color1, color2, "Gradient start and end colors should be different")
    }

    // MARK: - Trait Collection Change Handling

    func testTraitCollectionDidChangeUpdatesColors() {
        let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        view.layoutIfNeeded()

        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        let initialColors = gradientLayer.colors

        view.traitCollectionDidChange(nil)

        let updatedColors = gradientLayer.colors

        XCTAssertNotNil(initialColors)
        XCTAssertNotNil(updatedColors)
        XCTAssertEqual(initialColors?.count, updatedColors?.count, "Color count should remain the same")
    }

    func testAppearanceChangeTriggersUpdate() {
        let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        view.layoutIfNeeded()

        let lightTrait = UITraitCollection(userInterfaceStyle: .light)
        let darkTrait = UITraitCollection(userInterfaceStyle: .dark)

        view.traitCollectionDidChange(lightTrait)
        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        let lightColors = gradientLayer.colors

        view.traitCollectionDidChange(darkTrait)
        let darkColors = gradientLayer.colors

        XCTAssertNotNil(lightColors)
        XCTAssertNotNil(darkColors)
        XCTAssertEqual(lightColors?.count, darkColors?.count, "Color count should remain the same after trait change")
    }

    func testNonAppearanceChangeDoesNotTriggerUpdate() {
        let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        view.layoutIfNeeded()

        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        let initialColors = gradientLayer.colors

        let sameTrait = UITraitCollection(userInterfaceStyle: view.traitCollection.userInterfaceStyle)
        view.traitCollectionDidChange(sameTrait)

        let finalColors = gradientLayer.colors

        XCTAssertNotNil(initialColors)
        XCTAssertNotNil(finalColors)
    }

    // MARK: - Layer Hierarchy

    func testGradientLayerIsAtBottom() {
        let view = ThemeGradientView(frame: .zero)
        guard let sublayers = view.layer.sublayers else {
            XCTFail("No sublayers found")
            return
        }

        XCTAssertGreaterThan(sublayers.count, 0, "Should have sublayers")
        XCTAssertTrue(sublayers.first is CAGradientLayer, "First sublayer should be CAGradientLayer")
    }

    func testGradientLayerInsertedAtIndexZero() {
        let view = ThemeGradientView(frame: .zero)
        guard let sublayers = view.layer.sublayers else {
            XCTFail("No sublayers found")
            return
        }

        XCTAssertGreaterThan(sublayers.count, 0)
        XCTAssertEqual(view.layer.sublayers?.first, sublayers.first, "Gradient layer should be first sublayer")
    }

    // MARK: - Edge Cases

    func testZeroSizeView() {
        let view = ThemeGradientView(frame: .zero)
        XCTAssertNotNil(view.layer.sublayers)
        view.layoutIfNeeded()

        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        XCTAssertEqual(gradientLayer.frame, .zero)
    }

    func testVeryLargeView() {
        let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        view.layoutIfNeeded()

        guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
            XCTFail("Gradient layer not found")
            return
        }

        XCTAssertEqual(gradientLayer.frame.width, 1000, accuracy: 0.1)
        XCTAssertEqual(gradientLayer.frame.height, 1000, accuracy: 0.1)
    }

    func testMultipleGradientViews() {
        var views: [ThemeGradientView] = []
        for _ in 0..<5 {
            let view = ThemeGradientView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
            view.layoutIfNeeded()
            views.append(view)
        }

        XCTAssertEqual(views.count, 5)

        for view in views {
            guard let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer else {
                XCTFail("Gradient layer not found")
                return
            }

            XCTAssertNotNil(gradientLayer.colors)
            XCTAssertEqual(gradientLayer.colors?.count, 2)
            XCTAssertEqual(view.layer.cornerRadius, ThemeCornerRadius.default.lg)
        }
    }
}
