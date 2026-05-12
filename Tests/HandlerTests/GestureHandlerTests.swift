import XCTest
@testable import WebBridgeKit

extension AdvancedHandlerTests {

    // MARK: - WebGestureHandler

    func testGestureHandler_GetConfigStatus_ReturnsConfig() {
        let handler = WebGestureHandler()
        let expectation = XCTestExpectation(description: "gesture get config")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["enabled"])
            XCTAssertNotNil(data["enabledGestures"])
            XCTAssertNotNil(data["pullThreshold"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGestureHandler_EnableGestures() {
        let handler = WebGestureHandler()
        let expectation = XCTestExpectation(description: "gesture enable")

        handler.handle(body: ["params": ["action": "enable", "gestures": ["pull", "swipeLeft"]]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["enabledGestures"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGestureHandler_DisableGestures() {
        let handler = WebGestureHandler()
        let expectation = XCTestExpectation(description: "gesture disable")

        handler.handle(body: ["params": ["action": "disable", "gestures": ["pull"]]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["enabledGestures"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGestureHandler_SetPullThreshold() {
        let handler = WebGestureHandler()
        let expectation = XCTestExpectation(description: "gesture set pull threshold")

        handler.handle(body: ["params": ["action": "setPullThreshold", "threshold": NSNumber(value: 0.2)]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["pullThreshold"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGestureHandler_StartPullRefresh() {
        let handler = WebGestureHandler()
        let expectation = XCTestExpectation(description: "gesture startPullRefresh")

        handler.handle(body: ["params": ["action": "startPullRefresh"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["state"] as? String, "loading")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGestureHandler_StopPullRefresh() {
        let handler = WebGestureHandler()
        let expectation = XCTestExpectation(description: "gesture stopPullRefresh")

        handler.handle(body: ["params": ["action": "stopPullRefresh"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["state"] as? String, "completed")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGestureHandler_UnsupportedAction_ReturnsError() {
        let handler = WebGestureHandler()
        let expectation = XCTestExpectation(description: "gesture unsupported action")

        handler.handle(body: ["params": ["action": "pinchZoom"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
