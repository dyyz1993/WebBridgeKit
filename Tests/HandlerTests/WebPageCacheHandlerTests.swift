import XCTest
@testable import WebBridgeKit

final class WebPageCacheHandlerTests: XCTestCase {

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

    func testPageCacheHandler_HandlerName() {
        let handler = WebPageCacheHandler()
        XCTAssertEqual(handler.handlerName, "PageCache")
    }

    // MARK: - Missing Method Returns Error

    func testPageCacheHandler_MissingMethod_ReturnsError() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "page cache missing method")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Unknown Method Returns Error

    func testPageCacheHandler_UnknownMethod_ReturnsError() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "page cache unknown method")

        handler.handle(body: ["method": "deleteAll"]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Clear Method Returns Success

    func testPageCacheHandler_Clear_ReturnsSuccess() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "page cache clear")

        handler.handle(body: ["method": "clear"]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - GetInfo Method Returns Success

    func testPageCacheHandler_GetInfo_ReturnsSuccess() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "page cache get info")

        handler.handle(body: ["method": "getInfo"]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - GetInfo Contains Cache Metrics

    func testPageCacheHandler_GetInfo_ContainsCacheMetrics() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "page cache info metrics")

        handler.handle(body: ["method": "getInfo"]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["countMetrics"])
            XCTAssertNotNil(data["memoryMetrics"])
            XCTAssertNotNil(data["cachedPages"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Preload Missing PageName Returns Error

    func testPageCacheHandler_Preload_MissingPageName_ReturnsError() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "page cache preload missing name")

        handler.handle(body: ["method": "preload"]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Preload With PageName Returns Response

    func testPageCacheHandler_Preload_WithPageName_ReturnsResponse() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "page cache preload with name")

        handler.handle(body: ["method": "preload", "pageName": "test-page"]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Non-String Method Returns Error

    func testPageCacheHandler_NonStringMethod_ReturnsError() {
        let handler = WebPageCacheHandler()
        let expectation = XCTestExpectation(description: "page cache non-string method")

        handler.handle(body: ["method": 123]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - PageCacheManager Is Singleton

    func testPageCacheManager_IsSingleton() {
        let manager1 = PageCacheManager.shared
        let manager2 = PageCacheManager.shared
        XCTAssertTrue(manager1 === manager2, "PageCacheManager should be a singleton")
    }

    // MARK: - PageCacheManager ClearCache DoesNotCrash

    func testPageCacheManager_ClearCache_DoesNotCrash() {
        PageCacheManager.shared.clearCache()
    }

    // MARK: - PageCacheManager GetCacheInfo ReturnsStructure

    func testPageCacheManager_GetCacheInfo_ReturnsStructure() {
        let info = PageCacheManager.shared.getCacheInfo()

        XCTAssertNotNil(info["countMetrics"])
        XCTAssertNotNil(info["memoryMetrics"])
        XCTAssertNotNil(info["cachedPages"])

        guard let countMetrics = info["countMetrics"] as? [String: Any] else {
            XCTFail("countMetrics is not a dictionary")
            return
        }
        XCTAssertNotNil(countMetrics["cacheSize"])
        XCTAssertNotNil(countMetrics["maxCacheSize"])
    }

    // MARK: - PageCacheManager IsCached Returns False For NonExistent

    func testPageCacheManager_IsCached_ReturnsFalseForNonExistent() {
        let isCached = PageCacheManager.shared.isCached(pageName: "non-existent-page-\(UUID().uuidString)")
        XCTAssertFalse(isCached)
    }

    // MARK: - PageCacheManager GetCachedPage Returns Nil For NonExistent

    func testPageCacheManager_GetCachedPage_ReturnsNilForNonExistent() {
        let page = PageCacheManager.shared.getCachedPage(named: "non-existent-page-\(UUID().uuidString)")
        XCTAssertNil(page)
    }

    // MARK: - PageCacheManager CachedPage Structure

    func testPageCacheManager_CachedPage_HasCorrectProperties() {
        let page = PageCacheManager.CachedPage(pageName: "test", html: "<html></html>", baseURL: nil)

        XCTAssertEqual(page.pageName, "test")
        XCTAssertEqual(page.html, "<html></html>")
        XCTAssertNil(page.baseURL)
        XCTAssertEqual(page.hitCount, 0)
        XCTAssertGreaterThan(page.cachedAt.timeIntervalSince1970, 0)
    }

    // MARK: - PageCacheManager CachedPage EstimatedSizeKB

    func testPageCacheManager_CachedPage_EstimatedSizeKB() {
        let html = String(repeating: "a", count: 2048)
        let page = PageCacheManager.CachedPage(pageName: "test", html: html, baseURL: nil)
        XCTAssertGreaterThan(page.estimatedSizeKB, 0)
    }
}
