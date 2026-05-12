import XCTest
@testable import WebBridgeKit

extension AdvancedHandlerTests {

    // MARK: - WebScreenHandler

    func testScreenHandler_SetKeepScreenOn() {
        let handler = WebScreenHandler()
        let expectation = XCTestExpectation(description: "screen keepScreenOn")

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

    func testScreenHandler_SetKeepScreenOff() {
        let handler = WebScreenHandler()
        let expectation = XCTestExpectation(description: "screen keepScreenOff")

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

    func testScreenHandler_UnsupportedAction_ReturnsError() {
        let handler = WebScreenHandler()
        let expectation = XCTestExpectation(description: "screen unsupported action")

        handler.handle(body: ["params": ["action": "setBrightness"]]) { result in
            if let response = result as? WebBridgeResponse {
                XCTAssertEqual(response.success, false)
            } else if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - WebShareHandler

    func testShareHandler_MissingText_ReturnsError() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share missing text")

        handler.handle(body: ["params": ["url": "https://example.com"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testShareHandler_MissingURL_ReturnsError() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share missing url")

        handler.handle(body: ["params": ["text": "hello"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testShareHandler_InvalidURL_ReturnsError() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share invalid url")

        handler.handle(body: ["params": ["text": "hello", "url": "not_a_url"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testShareHandler_TopLevelParams_MissingParams_ReturnsError() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share no params")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebPageCacheHandler

    func testPageCacheHandler_MissingMethod_ReturnsError() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "pageCache missing method")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPageCacheHandler_UnsupportedMethod_ReturnsError() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "pageCache unsupported method")

        handler.handle(body: ["method": "delete"]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPageCacheHandler_Clear() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "pageCache clear")

        handler.handle(body: ["method": "clear"]) { result in
            let dict = self.assertSuccess(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPageCacheHandler_GetInfo() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "pageCache getInfo")

        handler.handle(body: ["method": "getInfo"]) { result in
            let dict = self.assertSuccess(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPageCacheHandler_Preload_MissingPageName_ReturnsError() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "pageCache preload missing pageName")

        handler.handle(body: ["method": "preload"]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
