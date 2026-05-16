import XCTest
@testable import WebBridgeKit

final class WebPermissionHandlerTests: XCTestCase {

    // MARK: - Missing Type

    func testPermissionHandler_MissingType_ReturnsError() {
        let handler = WebPermissionHandler()
        let expectation = XCTestExpectation(description: "permission missing type")

        handler.handle(body: [:]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Invalid Type

    func testPermissionHandler_InvalidType_ReturnsError() {
        let handler = WebPermissionHandler()
        let expectation = XCTestExpectation(description: "permission invalid type")

        handler.handle(body: ["type": "invalidType"]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPermissionHandler_EmptyType_ReturnsError() {
        let handler = WebPermissionHandler()
        let expectation = XCTestExpectation(description: "permission empty type")

        handler.handle(body: ["type": ""]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPermissionHandler_GarbageType_ReturnsError() {
        let handler = WebPermissionHandler()
        let expectation = XCTestExpectation(description: "permission garbage type")

        handler.handle(body: ["type": "###123"]) { result in
            let dict = assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Invalid"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Non-String Type

    func testPermissionHandler_NonStringType_ReturnsError() {
        let handler = WebPermissionHandler()
        let expectation = XCTestExpectation(description: "permission non-string type")

        handler.handle(body: ["type": 123]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Camera Type

    func testPermissionHandler_CameraType_DoesNotCrash() {
        let handler = WebPermissionHandler()
        let expectation = XCTestExpectation(description: "permission camera type")

        handler.handle(body: ["type": "camera"]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Microphone Type

    func testPermissionHandler_MicrophoneType_DoesNotCrash() {
        let handler = WebPermissionHandler()
        let expectation = XCTestExpectation(description: "permission microphone type")

        handler.handle(body: ["type": "microphone"]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Notification Type

    func testPermissionHandler_NotificationType_DoesNotCrash() {
        let handler = WebPermissionHandler()
        let expectation = XCTestExpectation(description: "permission notification type")

        handler.handle(body: ["type": "notification"]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Location Type

    func testPermissionHandler_LocationType_DoesNotCrash() {
        let handler = WebPermissionHandler()
        let expectation = XCTestExpectation(description: "permission location type")

        handler.handle(body: ["type": "location"]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Handler Name

    func testPermissionHandler_HandlerName() {
        let handler = WebPermissionHandler()
        XCTAssertEqual(handler.handlerName, "Permission")
    }

    // MARK: - WebView Nil Handling

    func testPermissionHandler_WebViewNil_DoesNotCrash() {
        let handler = WebPermissionHandler()
        handler.webView = nil

        let expectation = XCTestExpectation(description: "permission nil webView")

        handler.handle(body: ["type": "camera"]) { result in
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
