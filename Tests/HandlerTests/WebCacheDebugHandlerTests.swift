import XCTest
@testable import WebBridgeKit

final class WebCacheDebugHandlerTests: XCTestCase {

    private var handler: WebCacheDebugHandler!

    override func setUp() {
        super.setUp()
        handler = WebCacheDebugHandler()
    }

    override func tearDown() {
        handler = nil
        super.tearDown()
    }

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

    // MARK: - Empty / Unknown Action

    func testHandle_EmptyAction_RejectsUnknown() {
        let expectation = XCTestExpectation(description: "empty action rejects")

        handler.handle(body: [:]) { result in
            _ = self.assertFailure(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testHandle_UnknownAction_RejectsWithError() {
        let expectation = XCTestExpectation(description: "unknown action rejects")

        handler.handle(body: ["action": "nonExistentAction"]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Unknown action"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - getInfo

    func testHandle_GetInfo_ReturnsSuccessWithData() {
        let expectation = XCTestExpectation(description: "getInfo success")

        handler.handle(body: ["action": "getInfo"]) { result in
            let dict = self.assertSuccess(result)
            guard let outerData = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(outerData["success"])
            XCTAssertNotNil(outerData["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testHandle_GetCacheInfo_Alias_ReturnsSuccess() {
        let expectation = XCTestExpectation(description: "getCacheInfo alias success")

        handler.handle(body: ["action": "getCacheInfo"]) { result in
            _ = self.assertSuccess(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - getMemoryInfo

    func testHandle_GetMemoryInfo_ReturnsSuccessWithData() {
        let expectation = XCTestExpectation(description: "getMemoryInfo success")

        handler.handle(body: ["action": "getMemoryInfo"]) { result in
            let dict = self.assertSuccess(result)
            guard let outerData = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(outerData["success"])
            XCTAssertNotNil(outerData["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - clearAll

    func testHandle_ClearAll_ReturnsSuccess() {
        let expectation = XCTestExpectation(description: "clearAll success")

        handler.handle(body: ["action": "clearAll"]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["success"] as? Bool, true)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - getConfig

    func testHandle_GetConfig_ReturnsSuccessWithConfig() {
        let expectation = XCTestExpectation(description: "getConfig success")

        handler.handle(body: ["action": "getConfig"]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["success"] as? Bool, true)
            XCTAssertNotNil(data["config"])
            guard let config = data["config"] as? [String: Any] else {
                XCTFail("Missing config dict")
                return
            }
            XCTAssertNotNil(config["enableCompression"])
            XCTAssertNotNil(config["compressionLevel"])
            XCTAssertNotNil(config["maxCacheSize"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - isCached missing url

    func testHandle_IsCached_MissingUrl_Rejects() {
        let expectation = XCTestExpectation(description: "isCached missing url")

        handler.handle(body: ["action": "isCached"]) { result in
            let dict = self.assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Invalid URL"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - deleteByPattern missing pattern

    func testHandle_DeleteByPattern_MissingPattern_Rejects() {
        let expectation = XCTestExpectation(description: "deleteByPattern missing pattern")

        handler.handle(body: ["action": "deleteByPattern"]) { result in
            let dict = self.assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Pattern is required"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testHandle_DeleteByGlob_MissingPattern_Rejects() {
        let expectation = XCTestExpectation(description: "deleteByGlob missing pattern")

        handler.handle(body: ["action": "deleteByGlob"]) { result in
            _ = self.assertFailure(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - deleteByKey missing key

    func testHandle_DeleteByKey_MissingKey_Rejects() {
        let expectation = XCTestExpectation(description: "deleteByKey missing key")

        handler.handle(body: ["action": "deleteByKey"]) { result in
            let dict = self.assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Key is required"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - setConfig missing config

    func testHandle_SetConfig_MissingConfig_Rejects() {
        let expectation = XCTestExpectation(description: "setConfig missing config")

        handler.handle(body: ["action": "setConfig"]) { result in
            let dict = self.assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Config is required"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - addPageRule missing rule

    func testHandle_AddPageRule_MissingRule_Rejects() {
        let expectation = XCTestExpectation(description: "addPageRule missing rule")

        handler.handle(body: ["action": "addPageRule"]) { result in
            let dict = self.assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Rule is required"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - getPageRules

    func testHandle_GetPageRules_ReturnsSuccessWithRulesArray() {
        let expectation = XCTestExpectation(description: "getPageRules success")

        handler.handle(body: ["action": "getPageRules"]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["success"] as? Bool, true)
            XCTAssertNotNil(data["rules"])
            XCTAssertNotNil(data["count"])
            let rules = data["rules"] as? [[String: Any]] ?? []
            XCTAssertTrue(self.isArray(rules))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - deletePageRule missing ruleId

    func testHandle_DeletePageRule_MissingRuleId_Rejects() {
        let expectation = XCTestExpectation(description: "deletePageRule missing ruleId")

        handler.handle(body: ["action": "deletePageRule"]) { result in
            let dict = self.assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Rule ID is required"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - cachePage missing url/ruleId

    func testHandle_CachePage_MissingUrlAndRuleId_Rejects() {
        let expectation = XCTestExpectation(description: "cachePage missing params")

        handler.handle(body: ["action": "cachePage"]) { result in
            let dict = self.assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("URL and ruleId are required"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testHandle_CachePage_MissingRuleIdOnly_Rejects() {
        let expectation = XCTestExpectation(description: "cachePage missing ruleId")

        handler.handle(body: [
            "action": "cachePage",
            "params": ["url": "https://example.com"]
        ]) { result in
            _ = self.assertFailure(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - getCachedPages

    func testHandle_GetCachedPages_ReturnsSuccessWithPages() {
        let expectation = XCTestExpectation(description: "getCachedPages success")

        handler.handle(body: ["action": "getCachedPages"]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["success"] as? Bool, true)
            XCTAssertNotNil(data["pages"])
            XCTAssertNotNil(data["count"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - updatePageRule missing rule

    func testHandle_UpdatePageRule_MissingRule_Rejects() {
        let expectation = XCTestExpectation(description: "updatePageRule missing rule")

        handler.handle(body: ["action": "updatePageRule"]) { result in
            _ = self.assertFailure(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - clearAllPageRules

    func testHandle_ClearAllPageRules_ReturnsSuccess() {
        let expectation = XCTestExpectation(description: "clearAllPageRules success")

        handler.handle(body: ["action": "clearAllPageRules"]) { result in
            _ = self.assertSuccess(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - resetToPresetPageRules

    func testHandle_ResetToPresetPageRules_ReturnsSuccess() {
        let expectation = XCTestExpectation(description: "resetToPresetPageRules success")

        handler.handle(body: ["action": "resetToPresetPageRules"]) { result in
            _ = self.assertSuccess(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - addExcludePattern missing params

    func testHandle_AddExcludePattern_MissingParams_Rejects() {
        let expectation = XCTestExpectation(description: "addExcludePattern missing params")

        handler.handle(body: ["action": "addExcludePattern"]) { result in
            _ = self.assertFailure(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - removeExcludePattern missing params

    func testHandle_RemoveExcludePattern_MissingParams_Rejects() {
        let expectation = XCTestExpectation(description: "removeExcludePattern missing params")

        handler.handle(body: ["action": "removeExcludePattern"]) { result in
            _ = self.assertFailure(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - refreshCachedPage missing pageId

    func testHandle_RefreshCachedPage_MissingPageId_Rejects() {
        let expectation = XCTestExpectation(description: "refreshCachedPage missing pageId")

        handler.handle(body: ["action": "refreshCachedPage"]) { result in
            let dict = self.assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Page ID is required"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - deleteCachedPage missing pageId

    func testHandle_DeleteCachedPage_MissingPageId_Rejects() {
        let expectation = XCTestExpectation(description: "deleteCachedPage missing pageId")

        handler.handle(body: ["action": "deleteCachedPage"]) { result in
            let dict = self.assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Page ID is required"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - getEntries

    func testHandle_GetEntries_ReturnsSuccess() {
        let expectation = XCTestExpectation(description: "getEntries success")

        handler.handle(body: ["action": "getEntries"]) { result in
            _ = self.assertSuccess(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Handler Name

    func testHandler_HandlerName() {
        XCTAssertEqual(handler.handlerName, "CacheDebug")
    }

    // MARK: - Helper

    private func isArray(_ value: Any) -> Bool {
        value is [Any]
    }
}
