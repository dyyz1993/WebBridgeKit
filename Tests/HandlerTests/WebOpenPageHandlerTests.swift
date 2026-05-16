import XCTest
@testable import WebBridgeKit

final class WebOpenPageHandlerTests: XCTestCase {

    // MARK: - Missing Parameters

    func testOpenPageHandler_MissingPageAndURL_ReturnsError() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage missing params")

        handler.handle(body: [:]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testOpenPageHandler_EmptyParams_ReturnsError() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage empty params")

        handler.handle(body: ["params": [:]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - With Page Name

    func testOpenPageHandler_WithPageName_ReturnsOpening() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage with page name")

        handler.handle(body: ["params": ["page": "sdk_test"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "opening")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testOpenPageHandler_WithMode_ReturnsOpening() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage with mode")

        handler.handle(body: ["params": ["page": "test", "mode": "immersive"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "opening")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testOpenPageHandler_WithModalParams_ReturnsOpening() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage modal params")

        handler.handle(body: ["params": ["page": "test", "modal": "present", "width": "50%"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "opening")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - With URL

    func testOpenPageHandler_WithURL_ReturnsOpening() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage with url")

        handler.handle(body: ["params": ["url": "https://example.com"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "opening")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Invalid Page Name (Path Traversal)

    func testOpenPageHandler_InvalidPageName_PathTraversal() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage path traversal")

        handler.handle(body: ["params": ["page": "../secret"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testOpenPageHandler_InvalidPageName_DoubleDot() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage double dot")

        handler.handle(body: ["params": ["page": "../../etc/passwd"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Handler Name

    func testOpenPageHandler_HandlerName() {
        let handler = WebOpenPageHandler()
        XCTAssertEqual(handler.handlerName, "OpenPage")
    }

    // MARK: - Various Modes

    func testOpenPageHandler_ImmersiveMode() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage immersive")

        handler.handle(body: ["params": ["page": "test", "mode": "immersive"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "opening")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testOpenPageHandler_ImmersiveBooleanTrue() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage immersive bool")

        handler.handle(body: ["params": ["page": "test", "immersive": true]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "opening")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testOpenPageHandler_WithExtraParams() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage extra params")

        handler.handle(body: ["params": [
            "page": "test",
            "title": "Test Page",
            "hideStatusBar": true,
            "hideTabBar": false,
            "disableSwipeBack": true,
            "orientation": "portrait"
        ]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "opening")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
