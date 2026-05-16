import XCTest
@testable import WebBridgeKit

final class WebPayloadHandlerTests: XCTestCase {

    // MARK: - Handler Name

    func testPayloadHandler_HandlerName() {
        let handler = WebPayloadHandler()
        XCTAssertEqual(handler.handlerName, "Payload")
    }

    // MARK: - Handle Returns Success

    func testPayloadHandler_Handle_ReturnsSuccess() {
        let handler = WebPayloadHandler()
        let expectation = XCTestExpectation(description: "payload handle success")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Response Contains Message

    func testPayloadHandler_ContainsMessageHint() {
        let handler = WebPayloadHandler()
        let expectation = XCTestExpectation(description: "payload message hint")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["message"] as? String)
            XCTAssertNotNil(data["hint"] as? String)
            XCTAssertTrue((data["message"] as? String ?? "").contains("SuperCachePayload"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Ignores Body Parameters

    func testPayloadHandler_IgnoresBodyParams() {
        let handler = WebPayloadHandler()
        let expectation = XCTestExpectation(description: "payload ignores body")

        handler.handle(body: ["foo": "bar", "key": 123]) { result in
            let dict = assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Empty Body

    func testPayloadHandler_EmptyBody_ReturnsSuccess() {
        let handler = WebPayloadHandler()
        let expectation = XCTestExpectation(description: "payload empty body")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
