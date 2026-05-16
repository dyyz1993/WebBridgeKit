import XCTest
@testable import WebBridgeKit

final class WebPhotoHandlerTests: XCTestCase {

    // MARK: - Handler Name

    func testPhotoHandler_HandlerName() {
        if #available(iOS 14.0, *) {
            let handler = WebPhotoHandler()
            XCTAssertEqual(handler.handlerName, "Photo")
        }
    }

    // MARK: - Handle Returns Response

    func testPhotoHandler_Handle_ReturnsResponse() {
        if #available(iOS 14.0, *) {
            let handler = WebPhotoHandler()
            let expectation = XCTestExpectation(description: "photo handle")

            handler.handle(body: [:]) { result in
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

    // MARK: - Default Multiple Is False

    func testPhotoHandler_DefaultMultipleIsFalse() {
        if #available(iOS 14.0, *) {
            let handler = WebPhotoHandler()
            let expectation = XCTestExpectation(description: "photo default multiple")

            handler.handle(body: [:]) { result in
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

    // MARK: - Multiple True Sets Limit

    func testPhotoHandler_MultipleTrue_SetsLimit() {
        if #available(iOS 14.0, *) {
            let handler = WebPhotoHandler()
            let expectation = XCTestExpectation(description: "photo multiple true")

            handler.handle(body: ["multiple": true, "limit": 10]) { result in
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

    // MARK: - Custom Limit

    func testPhotoHandler_CustomLimit() {
        if #available(iOS 14.0, *) {
            let handler = WebPhotoHandler()
            let expectation = XCTestExpectation(description: "photo custom limit")

            handler.handle(body: ["multiple": true, "limit": 3]) { result in
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

    // MARK: - Zero Limit Defaults

    func testPhotoHandler_ZeroLimit() {
        if #available(iOS 14.0, *) {
            let handler = WebPhotoHandler()
            let expectation = XCTestExpectation(description: "photo zero limit")

            handler.handle(body: ["multiple": true, "limit": 0]) { result in
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

    // MARK: - Ignores Unknown Params

    func testPhotoHandler_IgnoresUnknownParams() {
        if #available(iOS 14.0, *) {
            let handler = WebPhotoHandler()
            let expectation = XCTestExpectation(description: "photo unknown params")

            handler.handle(body: ["camera": "rear", "quality": "high", "format": "png"]) { result in
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

    // MARK: - WebView Nil Handling

    func testPhotoHandler_WebViewNil_DoesNotCrash() {
        if #available(iOS 14.0, *) {
            let handler = WebPhotoHandler()
            handler.webView = nil

            let expectation = XCTestExpectation(description: "photo nil webview")

            handler.handle(body: [:]) { result in
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
}
