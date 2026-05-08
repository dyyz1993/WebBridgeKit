import XCTest
@testable import WebBridgeKit

final class WebClipboardHandlerTests: XCTestCase {

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

    // MARK: - Read Action

    func testClipboardHandler_ReadAction_ReturnsText() {
        let handler = WebClipboardHandler()
        let expectation = XCTestExpectation(description: "clipboard read")

        handler.handle(body: ["action": "read"]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["text"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testClipboardHandler_DefaultAction_IsRead() {
        let handler = WebClipboardHandler()
        let expectation = XCTestExpectation(description: "clipboard default read")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["text"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Write Action

    func testClipboardHandler_WriteAction_WithText() {
        let handler = WebClipboardHandler()
        let expectation = XCTestExpectation(description: "clipboard write")

        handler.handle(body: ["action": "write", "text": "hello world"]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["text"] as? String, "hello world")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testClipboardHandler_WriteAction_ViaParams() {
        let handler = WebClipboardHandler()
        let expectation = XCTestExpectation(description: "clipboard write via params")

        handler.handle(body: ["params": ["action": "write", "text": "test value"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["text"] as? String, "test value")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testClipboardHandler_WriteAction_EmptyText_Succeeds() {
        let handler = WebClipboardHandler()
        let expectation = XCTestExpectation(description: "clipboard write empty text")

        handler.handle(body: ["action": "write", "text": ""]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["text"] as? String, "")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Write Missing Text

    func testClipboardHandler_WriteAction_MissingText_ReturnsError() {
        let handler = WebClipboardHandler()
        let expectation = XCTestExpectation(description: "clipboard write missing text")

        handler.handle(body: ["action": "write"]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Invalid Action

    func testClipboardHandler_InvalidAction_ReturnsError() {
        let handler = WebClipboardHandler()
        let expectation = XCTestExpectation(description: "clipboard invalid action")

        handler.handle(body: ["action": "delete"]) { result in
            let dict = self.assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Unknown action"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testClipboardHandler_RandomAction_ReturnsError() {
        let handler = WebClipboardHandler()
        let expectation = XCTestExpectation(description: "clipboard random action")

        handler.handle(body: ["action": "clear"]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Handler Name

    func testClipboardHandler_HandlerName() {
        let handler = WebClipboardHandler()
        XCTAssertEqual(handler.handlerName, "Clipboard")
    }

    // MARK: - Write Then Read

    func testClipboardHandler_WriteThenRead_ReturnsWrittenText() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("UIPasteboard access restricted in simulator sandbox")
        #endif

        let handler = WebClipboardHandler()
        let writeExp = XCTestExpectation(description: "clipboard write 2")
        let readExp = XCTestExpectation(description: "clipboard read 2")

        handler.handle(body: ["action": "write", "text": "test_roundtrip"]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertEqual((dict["data"] as? [String: Any])?["text"] as? String, "test_roundtrip")
            writeExp.fulfill()
        }

        wait(for: [writeExp], timeout: 2.0)

        handler.handle(body: ["action": "read"]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["text"] as? String, "test_roundtrip")
            readExp.fulfill()
        }

        wait(for: [readExp], timeout: 2.0)
    }
}
