import XCTest
@testable import WebBridgeKit

final class WebPageOfflineCacheManagerTests: XCTestCase {

    func testSharedInstance() {
        let manager = WebPageOfflineCacheManager.shared
        XCTAssertNotNil(manager)
    }

    func testGetCachedPagesInitiallyEmpty() {
        let manager = WebPageOfflineCacheManager.shared
        let pages = manager.getCachedPages()
        XCTAssertTrue(pages.isEmpty)
    }

    func testGetCachedPagesForNonExistentRule() {
        let manager = WebPageOfflineCacheManager.shared
        let pages = manager.getCachedPages(for: "nonexistent-\(UUID().uuidString)")
        XCTAssertTrue(pages.isEmpty)
    }

    func testGetCachedCountInitiallyZero() {
        let manager = WebPageOfflineCacheManager.shared
        let count = manager.getCachedCount()
        XCTAssertEqual(count, 0)
    }

    func testGetTotalCacheSizeInitiallyZero() {
        let manager = WebPageOfflineCacheManager.shared
        let size = manager.getTotalCacheSize()
        XCTAssertEqual(size, 0)
    }

    func testDeleteCachedPageNonExistentReturnsFalse() {
        let manager = WebPageOfflineCacheManager.shared
        let result = manager.deleteCachedPage(pageId: "nonexistent-\(UUID().uuidString)")
        XCTAssertFalse(result)
    }

    func testClearAllCacheNoCrash() {
        let manager = WebPageOfflineCacheManager.shared
        manager.clearAllCache()
    }

    func testCleanupLRUNoCrash() {
        let manager = WebPageOfflineCacheManager.shared
        manager.cleanupLRU(maxCount: 20)
    }

    func testCacheErrorDescriptions() {
        let errors: [WebPageOfflineCacheManager.CacheError] = [
            .invalidURL, .downloadFailed, .ruleMatchFailed
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testCacheErrorInvalidURL() {
        let error = WebPageOfflineCacheManager.CacheError.invalidURL
        XCTAssertEqual(error.errorDescription, "Invalid URL")
    }

    func testCacheErrorDownloadFailed() {
        let error = WebPageOfflineCacheManager.CacheError.downloadFailed
        XCTAssertEqual(error.errorDescription, "Download failed")
    }

    func testCacheErrorRuleMatchFailed() {
        let error = WebPageOfflineCacheManager.CacheError.ruleMatchFailed
        XCTAssertEqual(error.errorDescription, "Rule does not match this URL")
    }
}
