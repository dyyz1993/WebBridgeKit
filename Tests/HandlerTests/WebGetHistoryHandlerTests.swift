import XCTest
@testable import WebBridgeKit

final class WebGetHistoryHandlerTests: XCTestCase {

    // MARK: - Handler Name

    func testGetHistoryHandler_HandlerName() {
        let handler = WebGetHistoryHandler()
        XCTAssertEqual(handler.handlerName, "GetHistory")
    }

    // MARK: - Handle Returns Success

    func testGetHistoryHandler_Handle_ReturnsSuccess() {
        let handler = WebGetHistoryHandler()
        let expectation = XCTestExpectation(description: "get history handle")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Response Contains Expected Keys

    func testGetHistoryHandler_ContainsHistoryKeys() {
        let handler = WebGetHistoryHandler()
        let expectation = XCTestExpectation(description: "get history keys")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["history"])
            XCTAssertNotNil(data["count"])
            XCTAssertNotNil(data["currentIndex"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - History Is Array

    func testGetHistoryHandler_HistoryIsArray() {
        let handler = WebGetHistoryHandler()
        let expectation = XCTestExpectation(description: "get history is array")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any],
                  let history = data["history"] as? [[String: Any]] else {
                XCTFail("History is not an array of dictionaries")
                return
            }
            XCTAssertNotNil(history)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Count Is Non-Negative

    func testGetHistoryHandler_CountIsNonNegative() {
        let handler = WebGetHistoryHandler()
        let expectation = XCTestExpectation(description: "get history count")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any],
                  let count = data["count"] as? Int else {
                XCTFail("Missing count")
                return
            }
            XCTAssertGreaterThanOrEqual(count, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Ignores Body Parameters

    func testGetHistoryHandler_IgnoresBodyParams() {
        let handler = WebGetHistoryHandler()
        let expectation = XCTestExpectation(description: "get history ignores body")

        handler.handle(body: ["filter": "recent", "limit": 10]) { result in
            let dict = assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
