import XCTest
@testable import WebBridgeKit

final class WebLayoutHandlerTests: XCTestCase {

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

    // MARK: - Get Status (Default)

    func testLayoutHandler_Default_ReturnsLayoutInfo() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout default")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["orientation"])
            XCTAssertNotNil(data["fullscreen"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testLayoutHandler_EmptyAction_ReturnsLayoutInfo() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout empty action")

        handler.handle(body: ["params": ["action": ""]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["orientation"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Set Orientation

    func testLayoutHandler_SetOrientation_Portrait() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout portrait")

        handler.handle(body: ["params": ["action": "setOrientation", "orientation": "portrait"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["orientation"] as? String, "portrait")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testLayoutHandler_SetOrientation_Landscape() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout landscape")

        handler.handle(body: ["params": ["action": "setOrientation", "orientation": "landscape"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["orientation"] as? String, "landscape")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testLayoutHandler_SetOrientation_Auto() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout auto")

        handler.handle(body: ["params": ["action": "setOrientation", "orientation": "auto"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["orientation"] as? String, "auto")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testLayoutHandler_SetOrientation_DefaultIsPortrait() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout default portrait")

        handler.handle(body: ["params": ["action": "setOrientation"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["orientation"] as? String, "portrait")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Set Fullscreen

    func testLayoutHandler_SetFullscreen_True() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout fullscreen true")

        handler.handle(body: ["params": ["action": "setFullscreen", "enabled": true]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["fullscreen"] as? Bool, true)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testLayoutHandler_SetFullscreen_False() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout fullscreen false")

        handler.handle(body: ["params": ["action": "setFullscreen", "enabled": false]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["fullscreen"] as? Bool, false)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testLayoutHandler_SetFullscreen_DefaultIsTrue() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout fullscreen default")

        handler.handle(body: ["params": ["action": "setFullscreen"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["fullscreen"] as? Bool, true)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Set Scroll Enabled

    func testLayoutHandler_SetScrollEnabled_True() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout scroll true")

        handler.handle(body: ["params": ["action": "setScrollEnabled", "enabled": true]]) { result in
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

    func testLayoutHandler_SetScrollEnabled_False() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout scroll false")

        handler.handle(body: ["params": ["action": "setScrollEnabled", "enabled": false]]) { result in
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

    // MARK: - Unsupported Actions

    func testLayoutHandler_UnsupportedAction_ReturnsError() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout unsupported")

        handler.handle(body: ["params": ["action": "rotateScreen"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Handler Name

    func testLayoutHandler_HandlerName() {
        let handler = WebLayoutHandler()
        XCTAssertEqual(handler.handlerName, "Layout")
    }
}
