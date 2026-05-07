import XCTest
@testable import WebBridgeKit

final class WebFileHandlerTests: XCTestCase {

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

    func testFileHandler_CanBeInstantiated() {
        let handler = WebFileHandler()
        XCTAssertNotNil(handler)
    }

    // MARK: - Handler Name

    func testFileHandler_HandlerName() {
        let handler = WebFileHandler()
        XCTAssertEqual(handler.handlerName, "File")
    }

    // MARK: - Default Parameters

    func testFileHandler_DefaultAccept_IsAllFiles() {
        let handler = WebFileHandler()
        let expectation = XCTestExpectation(description: "file default accept")

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

    // MARK: - With Accept Type

    func testFileHandler_WithAcceptType_DoesNotCrash() {
        let handler = WebFileHandler()
        let expectation = XCTestExpectation(description: "file accept type")

        handler.handle(body: ["accept": "image/*"]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Multiple Selection

    func testFileHandler_MultipleSelection_DoesNotCrash() {
        let handler = WebFileHandler()
        let expectation = XCTestExpectation(description: "file multiple selection")

        handler.handle(body: ["multiple": true, "accept": "application/pdf"]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - WebView Nil

    func testFileHandler_WebViewNil_DoesNotCrash() {
        let handler = WebFileHandler()
        handler.webView = nil

        let expectation = XCTestExpectation(description: "file nil webView")

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
}
