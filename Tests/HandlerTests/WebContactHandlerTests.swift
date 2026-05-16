import XCTest
@testable import WebBridgeKit

final class WebContactHandlerTests: XCTestCase {

    // MARK: - Instantiation

    func testContactsHandler_CanBeInstantiated() {
        let handler = WebContactsHandler()
        XCTAssertNotNil(handler)
    }

    // MARK: - Handler Name

    func testContactsHandler_HandlerName() {
        let handler = WebContactsHandler()
        XCTAssertEqual(handler.handlerName, "Contacts")
    }

    // MARK: - Check Permission

    func testContactsHandler_CheckPermission_ReturnsStatus() {
        let handler = WebContactsHandler()
        let expectation = XCTestExpectation(description: "contacts checkPermission")

        handler.handle(body: ["params": ["action": "checkPermission"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["authorized"])
            XCTAssertNotNil(data["status"])
            XCTAssertTrue(data["authorized"] is Bool)
            XCTAssertTrue(data["status"] is String)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Pick Default Action

    func testContactsHandler_DefaultAction_IsPick() {
        let handler = WebContactsHandler()
        let expectation = XCTestExpectation(description: "contacts default pick")

        handler.handle(body: [:]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Unknown Action

    func testContactsHandler_UnknownAction_ReturnsError() {
        let handler = WebContactsHandler()
        let expectation = XCTestExpectation(description: "contacts unknown action")

        handler.handle(body: ["params": ["action": "delete"]]) { result in
            let dict = assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Unknown action"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testContactsHandler_CreateAction_ReturnsError() {
        let handler = WebContactsHandler()
        let expectation = XCTestExpectation(description: "contacts create action")

        handler.handle(body: ["params": ["action": "create"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - GetAll Action

    func testContactsHandler_GetAll_DoesNotCrash() {
        let handler = WebContactsHandler()
        let expectation = XCTestExpectation(description: "contacts getAll")

        handler.handle(body: ["params": ["action": "getAll", "limit": 5]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Limit Parameter

    func testContactsHandler_LimitAsNSNumber() {
        let handler = WebContactsHandler()
        let expectation = XCTestExpectation(description: "contacts limit nsnumber")

        handler.handle(body: ["params": ["action": "getAll", "limit": NSNumber(value: 3)]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
