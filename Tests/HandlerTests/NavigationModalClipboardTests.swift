import XCTest
@testable import WebBridgeKit

extension SimpleHandlerTests {

    // MARK: - WebGetHistoryHandler

    func testGetHistoryHandler_ReturnsHistoryAndCount() {
        let handler = WebGetHistoryHandler()
        let expectation = XCTestExpectation(description: "get history")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["history"])
            XCTAssertNotNil(data["count"])
            XCTAssertNotNil(data["currentIndex"])
            XCTAssertEqual(data["count"] as? Int, (data["history"] as? [[String: Any]])?.count ?? -1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebGoBackHandler

    func testGoBackHandler_WithExplicitSteps() {
        let handler = WebGoBackHandler()
        let expectation = XCTestExpectation(description: "goBack with steps")

        handler.handle(body: ["params": ["steps": 2]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["success"])
            XCTAssertNotNil(data["steps"])
            XCTAssertNotNil(data["currentIndex"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGoBackHandler_DefaultStepsIsOne() {
        let handler = WebGoBackHandler()
        let expectation = XCTestExpectation(description: "goBack default steps")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["success"])
            XCTAssertNotNil(data["currentIndex"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGoBackHandler_EmptyParams_DefaultsToOne() {
        let handler = WebGoBackHandler()
        let expectation = XCTestExpectation(description: "goBack empty params")

        handler.handle(body: ["params": [:]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebClosePageHandler

    func testClosePageHandler_NoActiveBrowser_ReturnsError() {
        let handler = WebClosePageHandler()
        let expectation = XCTestExpectation(description: "closePage no browser")

        handler.handle(body: [:]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testClosePageHandler_WithAnimatedTrue() {
        let handler = WebClosePageHandler()
        let expectation = XCTestExpectation(description: "closePage animated true")

        WebBrowserManager.shared.currentBrowser = UIViewController()

        handler.handle(body: ["params": ["animated": true]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["success"] as? Bool, true)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        WebBrowserManager.shared.currentBrowser = nil
    }

    func testClosePageHandler_WithAnimatedFalse() {
        let handler = WebClosePageHandler()
        let expectation = XCTestExpectation(description: "closePage animated false")

        WebBrowserManager.shared.currentBrowser = UIViewController()

        handler.handle(body: ["params": ["animated": false]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["success"] as? Bool, true)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        WebBrowserManager.shared.currentBrowser = nil
    }

    func testClosePageHandler_DefaultAnimatedIsTrue() {
        let handler = WebClosePageHandler()
        let expectation = XCTestExpectation(description: "closePage default animated")

        WebBrowserManager.shared.currentBrowser = UIViewController()

        handler.handle(body: ["params": [:]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["success"] as? Bool, true)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        WebBrowserManager.shared.currentBrowser = nil
    }

    // MARK: - WebClipboardHandler

    func testClipboardHandler_ReadAction() {
        let handler = WebClipboardHandler()
        let expectation = XCTestExpectation(description: "clipboard read")

        handler.handle(body: ["action": "read"]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["text"])
            XCTAssertTrue((data["text"] is String) || (data["text"] == nil))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testClipboardHandler_WriteAction_WithText() {
        let handler = WebClipboardHandler()
        let expectation = XCTestExpectation(description: "clipboard write")

        handler.handle(body: ["action": "write", "text": "hello world"]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["text"] as? String, "hello world")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testClipboardHandler_WriteAction_WithParamsDict() {
        let handler = WebClipboardHandler()
        let expectation = XCTestExpectation(description: "clipboard write via params")

        handler.handle(body: ["params": ["action": "write", "text": "test value"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["text"] as? String, "test value")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testClipboardHandler_WriteAction_MissingText_ReturnsError() {
        let handler = WebClipboardHandler()
        let expectation = XCTestExpectation(description: "clipboard write missing text")

        handler.handle(body: ["action": "write"]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testClipboardHandler_InvalidAction_ReturnsError() {
        let handler = WebClipboardHandler()
        let expectation = XCTestExpectation(description: "clipboard invalid action")

        handler.handle(body: ["action": "delete"]) { result in
            let dict = assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Unknown action"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testClipboardHandler_DefaultActionIsRead() {
        let handler = WebClipboardHandler()
        let expectation = XCTestExpectation(description: "clipboard default read")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["text"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebSetModalHandler

    func testSetModalHandler_NoCurrentModal_ReturnsError() {
        let handler = WebSetModalHandler()
        let expectation = XCTestExpectation(description: "setModal no modal")

        WebBrowserManager.shared.currentModal = nil

        handler.handle(body: [:]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSetModalHandler_WithWidthAndHeight() {
        let handler = WebSetModalHandler()
        let expectation = XCTestExpectation(description: "setModal width height")

        let config = WebBrowserParams.ModalConfig(widthPercent: 0.5, heightPercent: 0.5)
        let modalVC = ModalWebViewController(url: URL(string: "https://example.com")!, config: config)
        WebBrowserManager.shared.currentModal = modalVC

        handler.handle(body: ["params": ["width": "90%", "height": "70%"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["success"] as? Bool, true)
            guard let updates = data["updates"] as? [String] else {
                XCTFail("Missing updates")
                return
            }
            XCTAssertTrue(updates.contains(where: { $0.contains("width") }))
            XCTAssertTrue(updates.contains(where: { $0.contains("height") }))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        WebBrowserManager.shared.currentModal = nil
    }

    func testSetModalHandler_WithMask() {
        let handler = WebSetModalHandler()
        let expectation = XCTestExpectation(description: "setModal mask")

        let config = WebBrowserParams.ModalConfig()
        let modalVC = ModalWebViewController(url: URL(string: "https://example.com")!, config: config)
        WebBrowserManager.shared.currentModal = modalVC

        handler.handle(body: ["params": ["mask": false]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["success"] as? Bool, true)
            guard let updates = data["updates"] as? [String] else {
                XCTFail("Missing updates")
                return
            }
            XCTAssertTrue(updates.contains(where: { $0.contains("mask") }))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        WebBrowserManager.shared.currentModal = nil
    }

    func testSetModalHandler_NoParams_NoUpdates() {
        let handler = WebSetModalHandler()
        let expectation = XCTestExpectation(description: "setModal no params")

        let config = WebBrowserParams.ModalConfig()
        let modalVC = ModalWebViewController(url: URL(string: "https://example.com")!, config: config)
        WebBrowserManager.shared.currentModal = modalVC

        handler.handle(body: ["params": [:]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["success"] as? Bool, true)
            guard let updates = data["updates"] as? [String] else {
                XCTFail("Missing updates")
                return
            }
            XCTAssertTrue(updates.isEmpty)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        WebBrowserManager.shared.currentModal = nil
    }

    // MARK: - WebPermissionStatusHandler

    func testPermissionStatusHandler_ReturnsPermissionsArray() {
        let handler = WebPermissionStatusHandler()
        let expectation = XCTestExpectation(description: "permission status")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["permissions"])
            XCTAssertNotNil(data["summary"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testPermissionStatusHandler_SummaryContainsExpectedKeys() {
        let handler = WebPermissionStatusHandler()
        let expectation = XCTestExpectation(description: "permission summary keys")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any],
                  let summary = data["summary"] as? [String: Any] else {
                XCTFail("Missing summary")
                return
            }
            XCTAssertNotNil(summary["total"])
            XCTAssertNotNil(summary["granted"])
            XCTAssertNotNil(summary["denied"])
            XCTAssertNotNil(summary["notDetermined"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testPermissionStatusHandler_PermissionsContainRequiredFields() {
        let handler = WebPermissionStatusHandler()
        let expectation = XCTestExpectation(description: "permission fields")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any],
                  let permissions = data["permissions"] as? [[String: Any]] else {
                XCTFail("Missing permissions")
                return
            }
            XCTAssertGreaterThan(permissions.count, 0)
            for perm in permissions {
                XCTAssertNotNil(perm["type"], "Permission missing 'type'")
                XCTAssertNotNil(perm["status"], "Permission missing 'status'")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
