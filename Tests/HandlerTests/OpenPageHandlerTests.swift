import XCTest
@testable import WebBridgeKit

extension AdvancedHandlerTests {

    // MARK: - WebOpenPageHandler

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

    func testOpenPageHandler_WithInvalidPageName_ReturnsError() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage invalid page name")

        handler.handle(body: ["params": ["page": "../secret"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

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
}
