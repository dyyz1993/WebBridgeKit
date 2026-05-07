//
//  WebBrowserParamsTests+Extended.swift
//  CoreTests
//

import XCTest
@testable import WebBridgeKit

final class WebBrowserParamsExtendedTests: XCTestCase {

    // MARK: - ModalSize Edge Cases

    func testModalSizeFromEmptyString() {
        if case .percent(let w, let h) = WebBrowserParams.ModalSize.from(string: "") {
            XCTAssertEqual(w, "80%")
            XCTAssertEqual(h, "80%")
        } else {
            XCTFail("Expected percent modal size")
        }
    }

    func testModalSizeCaseInsensitive() {
        XCTAssertEqual(WebBrowserParams.ModalSize.from(string: "FULLSCREEN"), .fullscreen)
        XCTAssertEqual(WebBrowserParams.ModalSize.from(string: "Half"), .half)
    }

    func testModalSizePercentCustomValues() {
        let size = WebBrowserParams.ModalSize.percent(width: "50%", height: "30%")
        if case .percent(let w, let h) = size {
            XCTAssertEqual(w, "50%")
            XCTAssertEqual(h, "30%")
        } else {
            XCTFail("Expected percent")
        }
    }

    func testModalSizeEquality() {
        XCTAssertEqual(WebBrowserParams.ModalSize.fullscreen, WebBrowserParams.ModalSize.fullscreen)
        XCTAssertEqual(WebBrowserParams.ModalSize.half, WebBrowserParams.ModalSize.half)
        XCTAssertNotEqual(WebBrowserParams.ModalSize.fullscreen, WebBrowserParams.ModalSize.half)
    }

    // MARK: - CloseReason Edge Cases

    func testCloseReasonCaseInsensitive() {
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "JAVASCRIPT"), .javascript)
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "ERROR"), .error)
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "TIMEOUT"), .timeout)
    }

    func testCloseReasonFromEmptyString() {
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: ""), .userAction)
    }

    func testCloseReasonRawValues() {
        XCTAssertEqual(WebBrowserParams.CloseReason.userAction.rawValue, "userAction")
        XCTAssertEqual(WebBrowserParams.CloseReason.javascript.rawValue, "javascript")
        XCTAssertEqual(WebBrowserParams.CloseReason.systemGesture.rawValue, "systemGesture")
        XCTAssertEqual(WebBrowserParams.CloseReason.backgroundTap.rawValue, "backgroundTap")
        XCTAssertEqual(WebBrowserParams.CloseReason.timeout.rawValue, "timeout")
        XCTAssertEqual(WebBrowserParams.CloseReason.error.rawValue, "error")
    }

    // MARK: - Orientation Parsing

    func testOrientationLandscapeLeft() {
        let url = URL(string: "https://example.com?orientation=landscapeleft")!
        let params = WebBrowserParams.from(url: url)
        XCTAssertEqual(params.orientation, .landscapeLeft)
    }

    func testOrientationLandscapeRight() {
        let url = URL(string: "https://example.com?orientation=landscaperight")!
        let params = WebBrowserParams.from(url: url)
        XCTAssertEqual(params.orientation, .landscapeRight)
    }

    func testOrientationAuto() {
        let url = URL(string: "https://example.com?orientation=auto")!
        let params = WebBrowserParams.from(url: url)
        XCTAssertEqual(params.orientation, .all)
    }

    func testOrientationUnknown() {
        let url = URL(string: "https://example.com?orientation=unknown")!
        let params = WebBrowserParams.from(url: url)
        XCTAssertEqual(params.orientation, .all)
    }

    // MARK: - toModalConfig with Flags

    func testToModalConfigWithShowMaskFalse() {
        let params = WebBrowserParams(displayMode: .modal, showMask: false)
        let config = params.toModalConfig()
        XCTAssertEqual(config.showMask, false)
    }

    func testToModalConfigWithClickMaskClosesFalse() {
        let params = WebBrowserParams(displayMode: .modal, clickMaskCloses: false)
        let config = params.toModalConfig()
        XCTAssertEqual(config.clickMaskCloses, false)
    }

    func testToModalConfigWithCustomCornerAndShadow() {
        let config = WebBrowserParams.ModalConfig(
            widthPercent: 0.5,
            heightPercent: 0.5,
            showMask: false,
            clickMaskCloses: false,
            cornerRadius: 20,
            shadowOpacity: 0.5
        )
        XCTAssertEqual(config.cornerRadius, 20)
        XCTAssertEqual(config.shadowOpacity, 0.5)
        XCTAssertEqual(config.widthPercent, 0.5)
    }

    func testToModalConfigPercentWithNoPercentSign() {
        let params = WebBrowserParams(displayMode: .modal, modalSize: .percent(width: "60", height: "40"))
        let config = params.toModalConfig()
        XCTAssertEqual(config.widthPercent, 0.6, accuracy: 0.01)
        XCTAssertEqual(config.heightPercent, 0.4, accuracy: 0.01)
    }

    // MARK: - from(url:) Combined Parameters

    func testFromURLWithAllParameters() {
        let url = URL(string: "https://example.com?mode=modal&modal=half&mask=false&closebutton=false&hidenavbar=true&hidestatusbar=true&disableswipeback=true&orientation=portrait&allowclose=false&title=Test&debugmode=true")!
        let params = WebBrowserParams.from(url: url)

        XCTAssertEqual(params.displayMode, .modal)
        XCTAssertEqual(params.modalSize, .half)
        XCTAssertEqual(params.showMask, false)
        XCTAssertEqual(params.showCloseButton, false)
        XCTAssertEqual(params.hideNavigationBar, true)
        XCTAssertEqual(params.hideStatusBar, true)
        XCTAssertEqual(params.disableSwipeBack, true)
        XCTAssertEqual(params.orientation, .portrait)
        XCTAssertEqual(params.allowJavaScriptClose, false)
        XCTAssertEqual(params.customTitle, "Test")
        XCTAssertEqual(params.debugMode, true)
    }

    func testFromURLWithUnknownQueryParameters() {
        let url = URL(string: "https://example.com?foo=bar&baz=qux")!
        let params = WebBrowserParams.from(url: url)
        XCTAssertEqual(params.displayMode, .normal)
    }

    func testFromURLWithWidthOnly() {
        let url = URL(string: "https://example.com?width=95%")!
        let params = WebBrowserParams.from(url: url)
        if case .percent(let w, let h) = params.modalSize {
            XCTAssertEqual(w, "95%")
            XCTAssertEqual(h, "80%")
        } else {
            XCTFail("Expected percent")
        }
    }

    func testFromURLWithHeightOnly() {
        let url = URL(string: "https://example.com?height=60%")!
        let params = WebBrowserParams.from(url: url)
        if case .percent(let w, let h) = params.modalSize {
            XCTAssertEqual(w, "80%")
            XCTAssertEqual(h, "60%")
        } else {
            XCTFail("Expected percent")
        }
    }

    // MARK: - Debug Mode Mutation

    func testDebugModeIsMutable() {
        var params = WebBrowserParams()
        XCTAssertEqual(params.debugMode, false)
        params.debugMode = true
        XCTAssertEqual(params.debugMode, true)
    }
}
