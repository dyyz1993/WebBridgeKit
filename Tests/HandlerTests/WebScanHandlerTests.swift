import XCTest
@testable import WebBridgeKit

final class WebScanHandlerTests: XCTestCase {

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

    func testScanHandler_HandlerName() {
        let handler = WebScanHandler()
        XCTAssertEqual(handler.handlerName, "Scan")
    }

    // MARK: - Handle Returns Response

    func testScanHandler_Handle_ReturnsResponse() {
        let handler = WebScanHandler()
        let expectation = XCTestExpectation(description: "scan handle")

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

    // MARK: - Ignores Body Params

    func testScanHandler_IgnoresBodyParams() {
        let handler = WebScanHandler()
        let expectation = XCTestExpectation(description: "scan ignores body")

        handler.handle(body: ["type": "qr", "timeout": 30]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Empty Body

    func testScanHandler_EmptyBody_DoesNotCrash() {
        let handler = WebScanHandler()
        let expectation = XCTestExpectation(description: "scan empty body")

        handler.handle(body: [:]) { result in
            guard let _ = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - WebView Nil Handling

    func testScanHandler_WebViewNil_DoesNotCrash() {
        let handler = WebScanHandler()
        handler.webView = nil

        let expectation = XCTestExpectation(description: "scan nil webview")

        handler.handle(body: [:]) { result in
            guard let _ = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
}
