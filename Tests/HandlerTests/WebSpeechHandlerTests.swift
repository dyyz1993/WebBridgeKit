import XCTest
@testable import WebBridgeKit

final class WebSpeechHandlerTests: XCTestCase {

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

    // MARK: - Handler Name

    func testSpeechHandler_HandlerName() {
        let handler = WebSpeechHandler()
        XCTAssertEqual(handler.handlerName, "Speech")
    }

    // MARK: - Empty Action Checks Permission

    func testSpeechHandler_EmptyAction_ReturnsPermissionStatus() {
        let handler = WebSpeechHandler()
        let expectation = XCTestExpectation(description: "speech permission check")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["authorized"])
            XCTAssertNotNil(data["status"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - CheckPermission Action

    func testSpeechHandler_CheckPermission_ReturnsStatus() {
        let handler = WebSpeechHandler()
        let expectation = XCTestExpectation(description: "speech check permission action")

        handler.handle(body: ["params": ["action": "checkPermission"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["authorized"])
            XCTAssertNotNil(data["status"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Unknown Action Returns Error

    func testSpeechHandler_UnknownAction_ReturnsError() {
        let handler = WebSpeechHandler()
        let expectation = XCTestExpectation(description: "speech unknown action")

        handler.handle(body: ["params": ["action": "unknownAction"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Stop Action Returns Success

    func testSpeechHandler_StopAction_ReturnsSuccess() {
        let handler = WebSpeechHandler()
        let expectation = XCTestExpectation(description: "speech stop action")

        handler.handle(body: ["params": ["action": "stop"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["message"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Start Action Without WebView Returns Error

    func testSpeechHandler_StartAction_ReturnsResponse() {
        let handler = WebSpeechHandler()
        let expectation = XCTestExpectation(description: "speech start action")

        handler.handle(body: ["params": ["action": "start", "language": "zh-CN"]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Language Parameter Defaults To zh-CN

    func testSpeechHandler_StartAction_DefaultLanguage() {
        let handler = WebSpeechHandler()
        let expectation = XCTestExpectation(description: "speech default language")

        handler.handle(body: ["params": ["action": "start"]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Params In Body Directly (No Nested Params)

    func testSpeechHandler_DirectBodyParams_ReturnsPermissionStatus() {
        let handler = WebSpeechHandler()
        let expectation = XCTestExpectation(description: "speech direct body params")

        handler.handle(body: ["action": "checkPermission"]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["authorized"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Status Is Valid String

    func testSpeechHandler_PermissionStatus_IsValidString() {
        let handler = WebSpeechHandler()
        let expectation = XCTestExpectation(description: "speech valid status string")

        handler.handle(body: ["params": ["action": "checkPermission"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any],
                  let status = data["status"] as? String else {
                XCTFail("Missing status")
                return
            }
            let validStatuses = ["authorized", "denied", "restricted", "notDetermined", "unknown"]
            XCTAssertTrue(validStatuses.contains(status), "Invalid status: \(status)")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
