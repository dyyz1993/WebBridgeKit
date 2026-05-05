//
//  WebBrowserParamsTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class WebBrowserParamsTests: XCTestCase {

    // MARK: - Default Initialization

    func testDefaultInitialization() {
        let params = WebBrowserParams()

        XCTAssertEqual(params.displayMode, .normal)
        XCTAssertEqual(params.showMask, true)
        XCTAssertEqual(params.clickMaskCloses, true)
        XCTAssertEqual(params.showCloseButton, true)
        XCTAssertEqual(params.hideNavigationBar, false)
        XCTAssertEqual(params.hideStatusBar, false)
        XCTAssertEqual(params.hideTabBar, false)
        XCTAssertEqual(params.disableSwipeBack, false)
        XCTAssertEqual(params.allowJavaScriptClose, true)
        XCTAssertNil(params.customTitle)
        XCTAssertEqual(params.debugMode, false)
        XCTAssertNil(params.payload)
    }

    func testDefaultStaticProperty() {
        let params = WebBrowserParams.default
        XCTAssertEqual(params.displayMode, .normal)
    }

    // MARK: - Custom Initialization

    func testCustomInitialization() {
        let params = WebBrowserParams(
            displayMode: .modal,
            showMask: false,
            clickMaskCloses: false,
            showCloseButton: false,
            hideNavigationBar: true,
            hideStatusBar: true,
            hideTabBar: true,
            disableSwipeBack: true,
            allowJavaScriptClose: false,
            customTitle: "Test Title",
            debugMode: true,
            payload: ["key": "value"]
        )

        XCTAssertEqual(params.displayMode, .modal)
        XCTAssertEqual(params.showMask, false)
        XCTAssertEqual(params.clickMaskCloses, false)
        XCTAssertEqual(params.showCloseButton, false)
        XCTAssertEqual(params.hideNavigationBar, true)
        XCTAssertEqual(params.hideStatusBar, true)
        XCTAssertEqual(params.hideTabBar, true)
        XCTAssertEqual(params.disableSwipeBack, true)
        XCTAssertEqual(params.allowJavaScriptClose, false)
        XCTAssertEqual(params.customTitle, "Test Title")
        XCTAssertEqual(params.debugMode, true)
        XCTAssertEqual(params.payload?["key"], "value")
    }

    // MARK: - DisplayMode

    func testDisplayModeFromNormal() {
        XCTAssertEqual(WebBrowserParams.DisplayMode.from(string: "normal"), .normal)
    }

    func testDisplayModeFromImmersive() {
        XCTAssertEqual(WebBrowserParams.DisplayMode.from(string: "immersive"), .immersive)
    }

    func testDisplayModeFromModal() {
        XCTAssertEqual(WebBrowserParams.DisplayMode.from(string: "modal"), .modal)
    }

    func testDisplayModeFromUnknown() {
        XCTAssertEqual(WebBrowserParams.DisplayMode.from(string: "unknown"), .normal)
    }

    func testDisplayModeFromEmpty() {
        XCTAssertEqual(WebBrowserParams.DisplayMode.from(string: ""), .normal)
    }

    func testDisplayModeCaseInsensitive() {
        XCTAssertEqual(WebBrowserParams.DisplayMode.from(string: "IMMERSIVE"), .immersive)
        XCTAssertEqual(WebBrowserParams.DisplayMode.from(string: "Modal"), .modal)
    }

    func testDisplayModeRawValues() {
        XCTAssertEqual(WebBrowserParams.DisplayMode.normal.rawValue, "normal")
        XCTAssertEqual(WebBrowserParams.DisplayMode.immersive.rawValue, "immersive")
        XCTAssertEqual(WebBrowserParams.DisplayMode.modal.rawValue, "modal")
    }

    // MARK: - ModalSize

    func testModalSizeFromFullscreen() {
        XCTAssertEqual(WebBrowserParams.ModalSize.from(string: "fullscreen"), .fullscreen)
    }

    func testModalSizeFromHalf() {
        XCTAssertEqual(WebBrowserParams.ModalSize.from(string: "half"), .half)
    }

    func testModalSizeFromUnknown() {
        if case .percent(let w, let h) = WebBrowserParams.ModalSize.from(string: "custom") {
            XCTAssertEqual(w, "80%")
            XCTAssertEqual(h, "80%")
        } else {
            XCTFail("Expected percent modal size")
        }
    }

    // MARK: - CloseReason

    func testCloseReasonFromStrings() {
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "userAction"), .userAction)
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "javascript"), .javascript)
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "system_gesture"), .systemGesture)
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "background_tap"), .backgroundTap)
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "timeout"), .timeout)
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "error"), .error)
    }

    func testCloseReasonFromUnknown() {
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "unknown"), .userAction)
    }

    // MARK: - from(url:) Factory

    func testFromURLWithNoQuery() {
        let url = URL(string: "https://example.com")!
        let params = WebBrowserParams.from(url: url)

        XCTAssertEqual(params.displayMode, .normal)
        XCTAssertEqual(params.showMask, true)
    }

    func testFromURLWithDisplayMode() {
        let url = URL(string: "https://example.com?mode=immersive")!
        let params = WebBrowserParams.from(url: url)

        XCTAssertEqual(params.displayMode, .immersive)
        XCTAssertEqual(params.hideTabBar, true)
    }

    func testFromURLWithModalMode() {
        let url = URL(string: "https://example.com?mode=modal&modal=fullscreen")!
        let params = WebBrowserParams.from(url: url)

        XCTAssertEqual(params.displayMode, .modal)
        XCTAssertEqual(params.modalSize, .fullscreen)
    }

    func testFromURLWithBooleanFlags() {
        let url = URL(string: "https://example.com?mask=false&clickmaskclose=false&closebutton=false&hidenavbar=true&hidestatusbar=true&hidetabbar=true&disableswipeback=true&allowclose=false")!
        let params = WebBrowserParams.from(url: url)

        XCTAssertEqual(params.showMask, false)
        XCTAssertEqual(params.clickMaskCloses, false)
        XCTAssertEqual(params.showCloseButton, false)
        XCTAssertEqual(params.hideNavigationBar, true)
        XCTAssertEqual(params.hideStatusBar, true)
        XCTAssertEqual(params.hideTabBar, true)
        XCTAssertEqual(params.disableSwipeBack, true)
        XCTAssertEqual(params.allowJavaScriptClose, false)
    }

    func testFromURLWithBooleanShortFlags() {
        let url = URL(string: "https://example.com?mask=1&closebutton=0")!
        let params = WebBrowserParams.from(url: url)

        XCTAssertEqual(params.showMask, true)
        XCTAssertEqual(params.showCloseButton, false)
    }

    func testFromURLWithCustomTitle() {
        let url = URL(string: "https://example.com?title=My%20Page")!
        let params = WebBrowserParams.from(url: url)

        XCTAssertEqual(params.customTitle, "My Page")
    }

    func testFromURLWithDebugMode() {
        let url = URL(string: "https://example.com?debugmode=true")!
        let params = WebBrowserParams.from(url: url)

        XCTAssertEqual(params.debugMode, true)
    }

    func testFromURLWithOrientationPortrait() {
        let url = URL(string: "https://example.com?orientation=portrait")!
        let params = WebBrowserParams.from(url: url)

        XCTAssertEqual(params.orientation, .portrait)
    }

    func testFromURLWithOrientationLandscape() {
        let url = URL(string: "https://example.com?orientation=landscape")!
        let params = WebBrowserParams.from(url: url)

        XCTAssertEqual(params.orientation, .landscape)
    }

    func testFromURLWithWidthAndHeight() {
        let url = URL(string: "https://example.com?width=90%&height=70%")!
        let params = WebBrowserParams.from(url: url)

        if case .percent(let w, let h) = params.modalSize {
            XCTAssertEqual(w, "90%")
            XCTAssertEqual(h, "70%")
        } else {
            XCTFail("Expected percent modal size")
        }
    }

    // MARK: - Immersive Mode Auto-Hides TabBar

    func testImmersiveModeAutoHidesTabBar() {
        let url = URL(string: "https://example.com?mode=immersive&hidetabbar=false")!
        let params = WebBrowserParams.from(url: url)

        XCTAssertEqual(params.displayMode, .immersive)
        XCTAssertEqual(params.hideTabBar, true)
    }

    // MARK: - ModalConfig

    func testModalConfigDefault() {
        let config = WebBrowserParams.ModalConfig.default
        XCTAssertEqual(config.widthPercent, 0.8)
        XCTAssertEqual(config.heightPercent, 0.8)
        XCTAssertEqual(config.showMask, true)
        XCTAssertEqual(config.cornerRadius, 12)
        XCTAssertEqual(config.shadowOpacity, 0.3)
    }

    func testToModalConfigFullscreen() {
        let params = WebBrowserParams(displayMode: .modal, modalSize: .fullscreen)
        let config = params.toModalConfig()

        XCTAssertEqual(config.widthPercent, 1.0)
        XCTAssertEqual(config.heightPercent, 1.0)
    }

    func testToModalConfigHalf() {
        let params = WebBrowserParams(displayMode: .modal, modalSize: .half)
        let config = params.toModalConfig()

        XCTAssertEqual(config.widthPercent, 1.0)
        XCTAssertEqual(config.heightPercent, 0.5)
    }

    func testToModalConfigPercent() {
        let params = WebBrowserParams(displayMode: .modal, modalSize: .percent(width: "60%", height: "40%"))
        let config = params.toModalConfig()

        XCTAssertEqual(config.widthPercent, 0.6, accuracy: 0.01)
        XCTAssertEqual(config.heightPercent, 0.4, accuracy: 0.01)
    }

    func testToModalConfigInvalidPercentFallsBack() {
        let params = WebBrowserParams(displayMode: .modal, modalSize: .percent(width: "abc", height: "xyz"))
        let config = params.toModalConfig()

        XCTAssertEqual(config.widthPercent, 0.8, accuracy: 0.01)
        XCTAssertEqual(config.heightPercent, 0.8, accuracy: 0.01)
    }
}
