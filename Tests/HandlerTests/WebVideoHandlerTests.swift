import XCTest
@testable import WebBridgeKit

final class WebVideoHandlerTests: XCTestCase {

    private func assertSuccess(_ result: Any) -> [String: Any] {
        guard let dict = result as? [String: Any] else {
            XCTFail("Result is not a dictionary")
            return [:]
        }
        XCTAssertEqual(dict["success"] as? Bool, true)
        return dict
    }

    private func assertFailure(_ result: Any) -> [String: Any] {
        guard let dict = result as? [String: Any] else {
            XCTFail("Result is not a dictionary")
            return [:]
        }
        XCTAssertEqual(dict["success"] as? Bool, false)
        return dict
    }

    // MARK: - Handler Name

    func testVideoHandler_HandlerName() {
        let handler = WebVideoHandler()
        XCTAssertEqual(handler.handlerName, "Video")
    }

    // MARK: - Unknown Action Returns Error

    func testVideoHandler_UnknownAction_ReturnsError() {
        let handler = WebVideoHandler()
        let expectation = XCTestExpectation(description: "video unknown action")

        handler.handle(body: ["params": ["action": "unknownAction"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - ToggleFaceTracking Without Param Toggles

    func testVideoHandler_ToggleFaceTracking_NoParam_Toggles() {
        let handler = WebVideoHandler()
        let expectation = XCTestExpectation(description: "video toggle face tracking")

        handler.handle(body: ["params": ["action": "toggleFaceTracking"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["enabled"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - ToggleFaceTracking With Enabled True

    func testVideoHandler_ToggleFaceTracking_EnabledTrue() {
        let handler = WebVideoHandler()
        let expectation = XCTestExpectation(description: "video enable face tracking")

        handler.handle(body: ["params": ["action": "toggleFaceTracking", "enabled": true]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["enabled"] as? Bool, true)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - ToggleFaceTracking With Enabled False

    func testVideoHandler_ToggleFaceTracking_EnabledFalse() {
        let handler = WebVideoHandler()
        let expectation = XCTestExpectation(description: "video disable face tracking")

        handler.handle(body: ["params": ["action": "toggleFaceTracking", "enabled": false]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["enabled"] as? Bool, false)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - ToggleHandTracking Without Param Toggles

    func testVideoHandler_ToggleHandTracking_NoParam_Toggles() {
        let handler = WebVideoHandler()
        let expectation = XCTestExpectation(description: "video toggle hand tracking")

        handler.handle(body: ["params": ["action": "toggleHandTracking"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["enabled"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - ToggleFrameTransfer Without Param Toggles

    func testVideoHandler_ToggleFrameTransfer_NoParam_Toggles() {
        let handler = WebVideoHandler()
        let expectation = XCTestExpectation(description: "video toggle frame transfer")

        handler.handle(body: ["params": ["action": "toggleFrameTransfer"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["enabled"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - ToggleFrameTransfer With Enabled True

    func testVideoHandler_ToggleFrameTransfer_EnabledTrue() {
        let handler = WebVideoHandler()
        let expectation = XCTestExpectation(description: "video enable frame transfer")

        handler.handle(body: ["params": ["action": "toggleFrameTransfer", "enabled": true]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["enabled"] as? Bool, true)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Config Action Returns Success

    func testVideoHandler_Config_ReturnsSuccess() {
        let handler = WebVideoHandler()
        let expectation = XCTestExpectation(description: "video config")

        handler.handle(body: ["params": ["action": "config", "faceTracking": true, "handTracking": false, "frameTransfer": true, "transferMode": "base64"]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Stop Action Without Start Returns Success

    func testVideoHandler_StopWithoutStart_ReturnsSuccess() {
        let handler = WebVideoHandler()
        let expectation = XCTestExpectation(description: "video stop without start")

        handler.handle(body: ["params": ["action": "stop"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["message"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - CheckPermission Returns Response

    func testVideoHandler_CheckPermission_ReturnsResponse() {
        let handler = WebVideoHandler()
        let expectation = XCTestExpectation(description: "video check permission")

        handler.handle(body: ["params": ["action": "checkPermission"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["authorized"])
            XCTAssertNotNil(data["status"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Start Without WebView Returns Error

    func testVideoHandler_StartWithoutWebView_ReturnsError() {
        let handler = WebVideoHandler()
        handler.webView = nil
        let expectation = XCTestExpectation(description: "video start no webview")

        handler.handle(body: ["params": ["action": "start"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - StartOverlay Without WebView Returns Error

    func testVideoHandler_StartOverlayWithoutWebView_ReturnsError() {
        let handler = WebVideoHandler()
        handler.webView = nil
        let expectation = XCTestExpectation(description: "video startOverlay no webview")

        handler.handle(body: ["params": ["action": "startOverlay"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - UpdateOverlay Without Active Overlay Returns Error

    func testVideoHandler_UpdateOverlayNotActive_ReturnsError() {
        let handler = WebVideoHandler()
        let expectation = XCTestExpectation(description: "video update overlay not active")

        handler.handle(body: ["params": ["action": "updateOverlay", "x": 10, "y": 20]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Switch Without Running Session Returns Error

    func testVideoHandler_SwitchWithoutSession_ReturnsError() {
        let handler = WebVideoHandler()
        let expectation = XCTestExpectation(description: "video switch no session")

        handler.handle(body: ["params": ["action": "switch"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Default Action Is Start

    func testVideoHandler_DefaultAction_IsStart() {
        let handler = WebVideoHandler()
        handler.webView = nil
        let expectation = XCTestExpectation(description: "video default action")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
