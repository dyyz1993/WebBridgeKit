import XCTest
@testable import WebBridgeKit

final class WebSystemExtraHandlerTests: XCTestCase {

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

    // MARK: - Instantiation

    func testSystemExtraHandler_CanBeInstantiated() {
        let handler = WebSystemExtraHandler()
        XCTAssertNotNil(handler)
    }

    // MARK: - Handler Name

    func testSystemExtraHandler_HandlerName() {
        let handler = WebSystemExtraHandler()
        XCTAssertEqual(handler.handlerName, "SystemExtra")
    }

    // MARK: - SetTorch Action

    func testSystemExtraHandler_SetTorch_DoesNotCrash() {
        let handler = WebSystemExtraHandler()
        let expectation = XCTestExpectation(description: "systemExtra setTorch")

        handler.handle(body: ["params": ["action": "setTorch", "enabled": true]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testSystemExtraHandler_SetTorchOff_DoesNotCrash() {
        let handler = WebSystemExtraHandler()
        let expectation = XCTestExpectation(description: "systemExtra setTorch off")

        handler.handle(body: ["params": ["action": "setTorch", "enabled": false]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - SetBadge Action (requires notification permission - test in simulator)

    func testSystemExtraHandler_SetBadge_DoesNotCrash() {
        let handler = WebSystemExtraHandler()
        let expectation = XCTestExpectation(description: "systemExtra setBadge")

        handler.handle(body: ["params": ["action": "setBadge", "count": 5]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testSystemExtraHandler_SetBadge_Zero() {
        let handler = WebSystemExtraHandler()
        let expectation = XCTestExpectation(description: "systemExtra setBadge zero")

        handler.handle(body: ["params": ["action": "setBadge", "count": 0]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Authenticate Action

    func testSystemExtraHandler_Authenticate_DoesNotCrash() {
        let handler = WebSystemExtraHandler()
        let expectation = XCTestExpectation(description: "systemExtra authenticate")

        handler.handle(body: ["params": ["action": "authenticate", "reason": "Verify identity"]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testSystemExtraHandler_Authenticate_DefaultReason() {
        let handler = WebSystemExtraHandler()
        let expectation = XCTestExpectation(description: "systemExtra authenticate default")

        handler.handle(body: ["params": ["action": "authenticate"]]) { result in
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

    func testSystemExtraHandler_UnsupportedAction_ReturnsError() {
        let handler = WebSystemExtraHandler()
        let expectation = XCTestExpectation(description: "systemExtra unsupported")

        handler.handle(body: ["params": ["action": "restart"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSystemExtraHandler_EmptyAction_ReturnsError() {
        let handler = WebSystemExtraHandler()
        let expectation = XCTestExpectation(description: "systemExtra empty action")

        handler.handle(body: ["params": [:]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Default Parameters

    func testSystemExtraHandler_SetTorch_DefaultEnabled() {
        let handler = WebSystemExtraHandler()
        let expectation = XCTestExpectation(description: "systemExtra torch default")

        handler.handle(body: ["params": ["action": "setTorch"]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testSystemExtraHandler_SetBadge_DefaultCount() {
        let handler = WebSystemExtraHandler()
        let expectation = XCTestExpectation(description: "systemExtra badge default")

        handler.handle(body: ["params": ["action": "setBadge"]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
}
