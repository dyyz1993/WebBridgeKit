import XCTest
@testable import WebBridgeKit

extension AdvancedHandlerTests {

    // MARK: - WebLayoutHandler

    func testLayoutHandler_GetStatus_ReturnsLayoutInfo() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout get status")

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

    func testLayoutHandler_SetOrientationPortrait() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout setOrientation portrait")

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

    func testLayoutHandler_SetOrientationLandscape() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout setOrientation landscape")

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

    func testLayoutHandler_SetFullscreen() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout setFullscreen")

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

    func testLayoutHandler_UnsupportedAction_ReturnsError() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout unsupported action")

        handler.handle(body: ["params": ["action": "rotateScreen"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
