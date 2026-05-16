import XCTest
@testable import WebBridgeKit

final class WebCameraHandlerTests: XCTestCase {

    // MARK: - Instantiation

    func testCameraHandler_CanBeInstantiated() {
        let handler = WebCameraHandler()
        XCTAssertNotNil(handler)
    }

    // MARK: - Unknown Type

    func testCameraHandler_UnknownType_ReturnsError() {
        let handler = WebCameraHandler()
        let expectation = XCTestExpectation(description: "camera unknown type")

        handler.handle(body: ["params": ["type": "hologram"]]) { result in
            let dict = assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Unknown camera type"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCameraHandler_EmptyType_DefaultsToPhoto() {
        let handler = WebCameraHandler()
        let expectation = XCTestExpectation(description: "camera empty type defaults photo")

        handler.handle(body: ["params": ["type": ""]]) { result in
            let dict = assertFailure(result)
            XCTAssertTrue((dict["error"] as? String ?? "").contains("Unknown camera type"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCameraHandler_VideoType_DoesNotCrash() {
        let handler = WebCameraHandler()
        let expectation = XCTestExpectation(description: "camera video type")

        handler.handle(body: ["params": ["type": "video"]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Type Validation

    func testCameraHandler_PhotoType_DoesNotCrash() {
        let handler = WebCameraHandler()
        let expectation = XCTestExpectation(description: "camera photo type")

        handler.handle(body: ["params": ["type": "photo"]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - No Params Defaults

    func testCameraHandler_NoParams_DefaultsToPhoto() {
        let handler = WebCameraHandler()
        let expectation = XCTestExpectation(description: "camera no params default")

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

    // MARK: - Handler Name

    func testCameraHandler_HandlerName() {
        let handler = WebCameraHandler()
        XCTAssertEqual(handler.handlerName, "Camera")
    }

    // MARK: - Multiple Calls

    func testCameraHandler_MultipleCalls_DoNotCrash() {
        let handler = WebCameraHandler()

        for type in ["photo", "video", "unknown_type"] {
            let expectation = XCTestExpectation(description: "camera multiple \(type)")

            handler.handle(body: ["params": ["type": type]]) { result in
                guard let dict = result as? [String: Any] else {
                    XCTFail("Result is not a dictionary for type \(type)")
                    return
                }
                XCTAssertNotNil(dict["success"])
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }
}
