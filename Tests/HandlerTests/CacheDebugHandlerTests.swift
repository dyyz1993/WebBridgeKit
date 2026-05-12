import XCTest
@testable import WebBridgeKit

extension AdvancedHandlerTests {

    private func assertSuccess(_ result: Any) -> [String: Any] {
        let dict = result as? [String: Any] ?? [:]
        XCTAssertTrue(dict["success"] as? Bool ?? false)
        return dict
    }

    private func assertFailure(_ result: Any) -> [String: Any] {
        let dict = result as? [String: Any] ?? [:]
        XCTAssertFalse(dict["success"] as? Bool ?? true)
        return dict
    }

    // MARK: - WebCacheDebugHandler

    func testCacheDebugHandler_GetCacheInfo() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug getCacheInfo")

        handler.handle(body: ["params": ["action": "getCacheInfo"]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_GetMemoryInfo() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug getMemoryInfo")

        handler.handle(body: ["params": ["action": "getMemoryInfo"]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_GetConfig() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug getConfig")

        handler.handle(body: ["params": ["action": "getConfig"]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_ClearAll() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug clearAll")

        handler.handle(body: ["params": ["action": "clearAll"]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_GetEntries() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug getEntries")

        handler.handle(body: ["params": ["action": "getEntries"]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_GetEntriesGroupedByDomain() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug getEntriesGroupedByDomain")

        handler.handle(body: ["params": ["action": "getEntriesGroupedByDomain"]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_IsCached_InvalidURL_ReturnsError() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug isCached invalid url")

        handler.handle(body: ["params": ["action": "isCached"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_DeleteByPattern_MissingPattern_ReturnsError() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug deleteByPattern missing")

        handler.handle(body: ["params": ["action": "deleteByPattern"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_DeleteByKey_MissingKey_ReturnsError() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug deleteByKey missing")

        handler.handle(body: ["params": ["action": "deleteByKey"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_SetConfig() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug setConfig")

        handler.handle(body: ["params": ["action": "setConfig", "config": ["enableCompression": true]]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_SetConfig_MissingConfig_ReturnsError() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug setConfig missing")

        handler.handle(body: ["params": ["action": "setConfig"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_GetRules() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug getRules")

        handler.handle(body: ["params": ["action": "getRules"]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_GetPageRules() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug getPageRules")

        handler.handle(body: ["params": ["action": "getPageRules"]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_AddPageRule_MissingParams_ReturnsError() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug addPageRule missing")

        handler.handle(body: ["params": ["action": "addPageRule"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_AddPageRule_WithValidParams() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug addPageRule valid")

        handler.handle(body: ["params": [
            "action": "addPageRule",
            "rule": [
                "name": "Test Rule",
                "includePatterns": ["https://example.com/*"]
            ]
        ]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                expectation.fulfill()
                return
            }
            if dict["success"] as? Bool != true {
                let msg = dict["message"] ?? dict["error"] ?? "unknown error"
                XCTFail("addPageRule failed: \(msg)")
            }
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testCacheDebugHandler_DeletePageRule_MissingId_ReturnsError() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug deletePageRule missing")

        handler.handle(body: ["params": ["action": "deletePageRule"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_ClearAllPageRules() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug clearAllPageRules")

        handler.handle(body: ["params": ["action": "clearAllPageRules"]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_ResetToPresetPageRules() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug resetToPresetPageRules")

        handler.handle(body: ["params": ["action": "resetToPresetPageRules"]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_GetCachedPages() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug getCachedPages")

        handler.handle(body: ["params": ["action": "getCachedPages"]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_CachePage_MissingParams_ReturnsError() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug cachePage missing")

        handler.handle(body: ["params": ["action": "cachePage"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_DeleteCachedPage_MissingId_ReturnsError() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug deleteCachedPage missing")

        handler.handle(body: ["params": ["action": "deleteCachedPage"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_RefreshCachedPage_MissingId_ReturnsError() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug refreshCachedPage missing")

        handler.handle(body: ["params": ["action": "refreshCachedPage"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_AddExcludePattern_MissingParams_ReturnsError() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug addExcludePattern missing")

        handler.handle(body: ["params": ["action": "addExcludePattern"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_ClearAllRules() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug clearAllRules")

        handler.handle(body: ["params": ["action": "clearAllRules"]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_ResetToPresetRules() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug resetToPresetRules")

        handler.handle(body: ["params": ["action": "resetToPresetRules"]]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCacheDebugHandler_UnknownAction_ReturnsError() {
        let handler = WebCacheDebugHandler()
        let expectation = XCTestExpectation(description: "cacheDebug unknown action")

        handler.handle(body: ["params": ["action": "unknownAction"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
