import XCTest
@testable import WebBridgeKit

final class WebScreenHandlerTests: XCTestCase {

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

    // MARK: - Set Keep Screen On

    func testScreenHandler_SetKeepScreenOn_True() {
        let handler = WebScreenHandler()
        let expectation = XCTestExpectation(description: "screen keepScreenOn true")

        handler.handle(body: ["params": ["action": "setKeepScreenOn", "enabled": true]]) { result in
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

    func testScreenHandler_SetKeepScreenOn_False() {
        let handler = WebScreenHandler()
        let expectation = XCTestExpectation(description: "screen keepScreenOn false")

        handler.handle(body: ["params": ["action": "setKeepScreenOn", "enabled": false]]) { result in
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

    func testScreenHandler_SetKeepScreenOn_DefaultIsTrue() {
        let handler = WebScreenHandler()
        let expectation = XCTestExpectation(description: "screen keepScreenOn default")

        handler.handle(body: ["params": ["action": "setKeepScreenOn"]]) { result in
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

    // MARK: - Stealth Mode (requires key window)

    func testScreenHandler_EnterStealthMode_DoesNotCrash() {
        let handler = WebScreenHandler()
        let expectation = XCTestExpectation(description: "screen enter stealth")

        handler.handle(body: ["params": ["action": "enterStealthMode"]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testScreenHandler_ExitStealthMode_WithoutEntering_ReturnsNotInStealth() {
        let handler = WebScreenHandler()
        let expectation = XCTestExpectation(description: "screen exit stealth without enter")

        handler.handle(body: ["params": ["action": "exitStealthMode"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "not_in_stealth_mode")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testScreenHandler_ExitStealthMode_DoesNotCrash() {
        let handler = WebScreenHandler()
        let expectation = XCTestExpectation(description: "screen exit stealth")

        handler.handle(body: ["params": ["action": "exitStealthMode"]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Unsupported Actions

    func testScreenHandler_UnsupportedAction_ReturnsError() {
        let handler = WebScreenHandler()
        let expectation = XCTestExpectation(description: "screen unsupported action")

        handler.handle(body: ["params": ["action": "setBrightness"]]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            } else if let response = result as? WebBridgeResponse {
                XCTAssertFalse(response.success)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testScreenHandler_UnknownAction_ReturnsError() {
        let handler = WebScreenHandler()
        let expectation = XCTestExpectation(description: "screen unknown action")

        handler.handle(body: ["params": ["action": "rotate"]]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            } else if let response = result as? WebBridgeResponse {
                XCTAssertFalse(response.success)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Handler Name

    func testScreenHandler_HandlerName() {
        let handler = WebScreenHandler()
        XCTAssertEqual(handler.handlerName, "Screen")
    }
}
