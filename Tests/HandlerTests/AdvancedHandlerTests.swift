import XCTest
@testable import WebBridgeKit

final class AdvancedHandlerTests: XCTestCase {

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

    // MARK: - WebOpenPageHandler

    func testOpenPageHandler_MissingPageAndURL_ReturnsError() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage missing params")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testOpenPageHandler_WithPageName_ReturnsOpening() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage with page name")

        handler.handle(body: ["params": ["page": "sdk_test"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "opening")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testOpenPageHandler_WithMode_ReturnsOpening() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage with mode")

        handler.handle(body: ["params": ["page": "test", "mode": "immersive"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "opening")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testOpenPageHandler_WithInvalidPageName_ReturnsError() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage invalid page name")

        handler.handle(body: ["params": ["page": "../secret"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testOpenPageHandler_WithURL_ReturnsOpening() {
        let handler = WebOpenPageHandler()
        let expectation = XCTestExpectation(description: "openPage with url")

        handler.handle(body: ["params": ["url": "https://example.com"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "opening")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebLayoutHandler

    func testLayoutHandler_GetStatus_ReturnsLayoutInfo() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout get status")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["orientation"])
            XCTAssertNotNil(data["fullscreen"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testLayoutHandler_SetOrientationPortrait() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout setOrientation portrait")

        handler.handle(body: ["params": ["action": "setOrientation", "orientation": "portrait"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["orientation"] as? String, "portrait")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testLayoutHandler_SetOrientationLandscape() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout setOrientation landscape")

        handler.handle(body: ["params": ["action": "setOrientation", "orientation": "landscape"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["orientation"] as? String, "landscape")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testLayoutHandler_SetFullscreen() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout setFullscreen")

        handler.handle(body: ["params": ["action": "setFullscreen", "enabled": true]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["fullscreen"] as? Bool, true)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testLayoutHandler_UnsupportedAction_ReturnsError() {
        let handler = WebLayoutHandler()
        let expectation = XCTestExpectation(description: "layout unsupported action")

        handler.handle(body: ["params": ["action": "rotateScreen"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebGestureHandler

    func testGestureHandler_GetConfigStatus_ReturnsConfig() {
        let handler = WebGestureHandler()
        let expectation = XCTestExpectation(description: "gesture get config")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["enabled"])
            XCTAssertNotNil(data["enabledGestures"])
            XCTAssertNotNil(data["pullThreshold"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGestureHandler_EnableGestures() {
        let handler = WebGestureHandler()
        let expectation = XCTestExpectation(description: "gesture enable")

        handler.handle(body: ["params": ["action": "enable", "gestures": ["pull", "swipeLeft"]]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["enabledGestures"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGestureHandler_DisableGestures() {
        let handler = WebGestureHandler()
        let expectation = XCTestExpectation(description: "gesture disable")

        handler.handle(body: ["params": ["action": "disable", "gestures": ["pull"]]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["enabledGestures"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGestureHandler_SetPullThreshold() {
        let handler = WebGestureHandler()
        let expectation = XCTestExpectation(description: "gesture set pull threshold")

        handler.handle(body: ["params": ["action": "setPullThreshold", "threshold": NSNumber(value: 0.2)]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["pullThreshold"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGestureHandler_StartPullRefresh() {
        let handler = WebGestureHandler()
        let expectation = XCTestExpectation(description: "gesture startPullRefresh")

        handler.handle(body: ["params": ["action": "startPullRefresh"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["state"] as? String, "loading")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGestureHandler_StopPullRefresh() {
        let handler = WebGestureHandler()
        let expectation = XCTestExpectation(description: "gesture stopPullRefresh")

        handler.handle(body: ["params": ["action": "stopPullRefresh"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["state"] as? String, "completed")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGestureHandler_UnsupportedAction_ReturnsError() {
        let handler = WebGestureHandler()
        let expectation = XCTestExpectation(description: "gesture unsupported action")

        handler.handle(body: ["params": ["action": "pinchZoom"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebScreenHandler

    func testScreenHandler_SetKeepScreenOn() {
        let handler = WebScreenHandler()
        let expectation = XCTestExpectation(description: "screen keepScreenOn")

        handler.handle(body: ["params": ["action": "setKeepScreenOn", "enabled": true]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["enabled"] as? Bool, true)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testScreenHandler_SetKeepScreenOff() {
        let handler = WebScreenHandler()
        let expectation = XCTestExpectation(description: "screen keepScreenOff")

        handler.handle(body: ["params": ["action": "setKeepScreenOn", "enabled": false]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["enabled"] as? Bool, false)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testScreenHandler_UnsupportedAction_ReturnsError() {
        let handler = WebScreenHandler()
        let expectation = XCTestExpectation(description: "screen unsupported action")

        handler.handle(body: ["params": ["action": "setBrightness"]]) { result in
            if let response = result as? WebBridgeResponse {
                XCTAssertEqual(response.success, false)
            } else if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - WebShareHandler

    func testShareHandler_MissingText_ReturnsError() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share missing text")

        handler.handle(body: ["params": ["url": "https://example.com"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testShareHandler_MissingURL_ReturnsError() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share missing url")

        handler.handle(body: ["params": ["text": "hello"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testShareHandler_InvalidURL_ReturnsError() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share invalid url")

        handler.handle(body: ["params": ["text": "hello", "url": "not_a_url"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testShareHandler_TopLevelParams_MissingParams_ReturnsError() {
        let handler = WebShareHandler()
        let expectation = XCTestExpectation(description: "share no params")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
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
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
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

    // MARK: - WebPageCacheHandler

    func testPageCacheHandler_MissingMethod_ReturnsError() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "pageCache missing method")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPageCacheHandler_UnsupportedMethod_ReturnsError() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "pageCache unsupported method")

        handler.handle(body: ["method": "delete"]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPageCacheHandler_Clear() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "pageCache clear")

        handler.handle(body: ["method": "clear"]) { result in
            let dict = self.assertSuccess(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPageCacheHandler_GetInfo() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "pageCache getInfo")

        handler.handle(body: ["method": "getInfo"]) { result in
            let dict = self.assertSuccess(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPageCacheHandler_Preload_MissingPageName_ReturnsError() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "pageCache preload missing pageName")

        handler.handle(body: ["method": "preload"]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - WebSpeechSynthesisHandler

    func testSpeechSynthesisHandler_Speak() {
        let handler = WebSpeechSynthesisHandler()
        let expectation = XCTestExpectation(description: "speechSynthesis speak")

        handler.handle(body: ["params": ["action": "speak", "text": "hello", "lang": "en-US", "rate": 0.5]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "speaking")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSpeechSynthesisHandler_Stop() {
        let handler = WebSpeechSynthesisHandler()
        let expectation = XCTestExpectation(description: "speechSynthesis stop")

        handler.handle(body: ["params": ["action": "stop"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSpeechSynthesisHandler_UnsupportedAction_ReturnsError() {
        let handler = WebSpeechSynthesisHandler()
        let expectation = XCTestExpectation(description: "speechSynthesis unsupported")

        handler.handle(body: ["params": ["action": "pause"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebSystemExtraHandler

    func testSystemExtraHandler_UnsupportedAction_ReturnsError() {
        let handler = WebSystemExtraHandler()
        let expectation = XCTestExpectation(description: "systemExtra unsupported")

        handler.handle(body: ["params": ["action": "restart"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebMirroringHandler

    func testMirroringHandler_GetStatus() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring getStatus")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["isMirroring"])
            XCTAssertNotNil(data["screenCount"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMirroringHandler_GetStatusAction() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring getStatus action")

        handler.handle(body: ["params": ["action": "getStatus"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["isMirroring"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMirroringHandler_StartObserve() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring startObserve")

        handler.handle(body: ["params": ["action": "startObserve"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "observing")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMirroringHandler_StopObserve() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring stopObserve")

        handler.handle(body: ["params": ["action": "stopObserve"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMirroringHandler_UnsupportedAction_ReturnsError() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring unsupported")

        handler.handle(body: ["params": ["action": "mirror"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebSensorsHandler

    func testSensorsHandler_GetStatus() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors getStatus")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["accelerometer"])
            XCTAssertNotNil(data["gyroscope"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSensorsHandler_StopAccelerometer() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors stopAccelerometer")

        handler.handle(body: ["params": ["action": "stopAccelerometer"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSensorsHandler_StopGyroscope() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors stopGyroscope")

        handler.handle(body: ["params": ["action": "stopGyroscope"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSensorsHandler_UnsupportedAction_ReturnsError() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors unsupported")

        handler.handle(body: ["params": ["action": "startMagnetometer"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebBluetoothHandler (Hardware-dependent: basic instantiation)

    func testBluetoothHandler_CanBeCreated() {
        let handler = WebBluetoothHandler()
        XCTAssertNotNil(handler)
    }

    func testBluetoothHandler_GetStatus() {
        let handler = WebBluetoothHandler()
        let expectation = XCTestExpectation(description: "bluetooth getStatus")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["available"])
            XCTAssertNotNil(data["state"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testBluetoothHandler_UnsupportedAction_ReturnsError() {
        let handler = WebBluetoothHandler()
        let expectation = XCTestExpectation(description: "bluetooth unsupported")

        handler.handle(body: ["params": ["action": "connect"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - WebPermissionHandler

    func testPermissionHandler_InvalidType_ReturnsError() {
        let handler = WebPermissionHandler()
        let expectation = XCTestExpectation(description: "permission invalid type")

        handler.handle(body: ["type": "invalidType"]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPermissionHandler_MissingType_ReturnsError() {
        let handler = WebPermissionHandler()
        let expectation = XCTestExpectation(description: "permission missing type")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebCameraHandler (Hardware-dependent: basic instantiation)

    func testCameraHandler_CanBeCreated() {
        let handler = WebCameraHandler()
        XCTAssertNotNil(handler)
    }

    func testCameraHandler_UnknownType_ReturnsError() {
        let handler = WebCameraHandler()
        let expectation = XCTestExpectation(description: "camera unknown type")

        handler.handle(body: ["params": ["type": "hologram"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebContactsHandler

    func testContactsHandler_CheckPermission() {
        let handler = WebContactsHandler()
        let expectation = XCTestExpectation(description: "contacts checkPermission")

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

        wait(for: [expectation], timeout: 2.0)
    }

    func testContactsHandler_UnknownAction_ReturnsError() {
        let handler = WebContactsHandler()
        let expectation = XCTestExpectation(description: "contacts unknown action")

        handler.handle(body: ["params": ["action": "delete"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebLocationHandler (Hardware-dependent: basic tests)

    func testLocationHandler_CanBeCreated() {
        let handler = WebLocationHandler()
        XCTAssertNotNil(handler)
    }

    // MARK: - WebScanHandler (Hardware-dependent: basic instantiation)

    func testScanHandler_CanBeCreated() {
        let handler = WebScanHandler()
        XCTAssertNotNil(handler)
    }

    // MARK: - WebSpeechHandler (Hardware-dependent: basic instantiation)

    func testSpeechHandler_CanBeCreated() {
        let handler = WebSpeechHandler()
        XCTAssertNotNil(handler)
    }

    // MARK: - WebAudioLevelHandler

    func testAudioLevelHandler_SetSensitivity() {
        let handler = WebAudioLevelHandler()
        let expectation = XCTestExpectation(description: "audioLevel setSensitivity")

        handler.handle(body: ["params": ["action": "setSensitivity", "sensitivity": 3.0]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["sensitivity"] as? Float, 3.0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAudioLevelHandler_StopWithoutStart() {
        let handler = WebAudioLevelHandler()
        let expectation = XCTestExpectation(description: "audioLevel stop without start")

        handler.handle(body: ["params": ["action": "stop"]]) { result in
            let dict = self.assertSuccess(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAudioLevelHandler_UnknownAction_ReturnsError() {
        let handler = WebAudioLevelHandler()
        let expectation = XCTestExpectation(description: "audioLevel unknown action")

        handler.handle(body: ["params": ["action": "record"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebMediaHandler

    func testMediaHandler_UnsupportedAction_ReturnsError() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media unsupported action")

        handler.handle(body: ["params": ["action": "compress"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMediaHandler_SaveImage_InvalidData_ReturnsError() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media saveImage invalid")

        handler.handle(body: ["params": ["action": "saveImage", "data": ""]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMediaHandler_UploadFile_WithValidURL_ReturnsSuccess() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media uploadFile valid url")

        handler.handle(body: ["params": ["action": "uploadFile", "path": "/tmp/file.txt", "url": "https://example.com/upload"]]) { result in
            if let response = result as? WebBridgeResponse {
                XCTAssertTrue(response.success)
            } else if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, true)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - WebOpenSettingsHandler

    func testOpenSettingsHandler_CanBeCreated() {
        let handler = WebOpenSettingsHandler()
        XCTAssertNotNil(handler)
    }
}
