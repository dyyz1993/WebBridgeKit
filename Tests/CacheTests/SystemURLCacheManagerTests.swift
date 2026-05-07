import XCTest
import WebKit
@testable import WebBridgeKit

final class SystemURLCacheManagerTests: XCTestCase {

    func testSharedInstance() {
        let manager = SystemURLCacheManager.shared
        XCTAssertNotNil(manager)
    }

    func testInitialStats() {
        let manager = SystemURLCacheManager.shared
        let stats = manager.getCacheStats()
        XCTAssertEqual(stats.totalRequests, 0)
        XCTAssertEqual(stats.cacheHits, 0)
        XCTAssertEqual(stats.cacheMisses, 0)
        XCTAssertEqual(stats.hitRate, 0.0)
    }

    func testRecordCacheHit() {
        let manager = SystemURLCacheManager.shared
        manager.recordCacheHit()
        let stats = manager.getCacheStats()
        XCTAssertEqual(stats.cacheHits, 1)
        XCTAssertEqual(stats.totalRequests, 1)
        XCTAssertEqual(stats.hitRate, 1.0)
    }

    func testRecordCacheMiss() {
        let manager = SystemURLCacheManager.shared
        manager.recordCacheMiss()
        let stats = manager.getCacheStats()
        XCTAssertEqual(stats.cacheMisses, 1)
        XCTAssertEqual(stats.totalRequests, 1)
        XCTAssertEqual(stats.hitRate, 0.0)
    }

    func testMixedHitsAndMisses() {
        let manager = SystemURLCacheManager.shared
        manager.recordCacheHit()
        manager.recordCacheHit()
        manager.recordCacheMiss()
        let stats = manager.getCacheStats()
        XCTAssertEqual(stats.cacheHits, 2)
        XCTAssertEqual(stats.cacheMisses, 1)
        XCTAssertEqual(stats.totalRequests, 3)
        XCTAssertEqual(stats.hitRate, 2.0 / 3.0)
    }

    func testFormattedHitRate() {
        let stats = SystemCacheStatistics(
            totalRequests: 4,
            cacheHits: 3,
            cacheMisses: 1,
            hitRate: 0.75,
            totalCacheSize: 1024
        )
        XCTAssertTrue(stats.formattedHitRate.contains("75"))
    }

    func testFormattedCacheSize() {
        let stats = SystemCacheStatistics(
            totalRequests: 0,
            cacheHits: 0,
            cacheMisses: 0,
            hitRate: 0.0,
            totalCacheSize: 0
        )
        XCTAssertFalse(stats.formattedCacheSize.isEmpty)
    }

    func testFormattedCacheSizeWithBytes() {
        let stats = SystemCacheStatistics(
            totalRequests: 0,
            cacheHits: 0,
            cacheMisses: 0,
            hitRate: 0.0,
            totalCacheSize: 1500
        )
        XCTAssertFalse(stats.formattedCacheSize.isEmpty)
    }

    func testHasCachedResponseUnknownURL() {
        let manager = SystemURLCacheManager.shared
        let url = URL(string: "https://nonexistent-\(UUID().uuidString).com/test")!
        XCTAssertFalse(manager.hasCachedResponse(for: url))
    }

    func testGetCachedResponseUnknownURL() {
        let manager = SystemURLCacheManager.shared
        let url = URL(string: "https://nonexistent-\(UUID().uuidString).com/test")!
        XCTAssertNil(manager.getCachedResponse(for: url))
    }

    func testRemoveCachedResponseUnknownURL() {
        let manager = SystemURLCacheManager.shared
        let url = URL(string: "https://nonexistent-\(UUID().uuidString).com/test")!
        manager.removeCachedResponse(for: url)
    }

    func testGetCacheSize() {
        let manager = SystemURLCacheManager.shared
        let size = manager.getCacheSize()
        XCTAssertGreaterThanOrEqual(size, 0)
    }

    func testConfiguredSession() {
        let manager = SystemURLCacheManager.shared
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let session = manager.configuredSession(for: request)
        XCTAssertNotNil(session)
    }

    func testConfiguredSessionAddsCacheControl() {
        let manager = SystemURLCacheManager.shared
        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let session = manager.configuredSession(for: request)
        XCTAssertNotNil(session)
    }

    func testConfigureWKWebViewCache() {
        let manager = SystemURLCacheManager.shared
        let config = WKWebViewConfiguration()
        manager.configureWKWebViewCache(config)
    }

    func testCleanupExpiredCache() {
        let manager = SystemURLCacheManager.shared
        manager.cleanupExpiredCache()
    }

    func testStoreAndRetrieveCachedResponse() {
        let manager = SystemURLCacheManager.shared
        let url = URL(string: "https://test-\(UUID().uuidString).com/data")!
        let request = URLRequest(url: url)
        let response = URLResponse(url: url, mimeType: "text/plain", expectedContentLength: 5, textEncodingName: nil)
        let data = "hello".data(using: .utf8)!

        manager.storeCachedResponse(data: data, for: response, request: request)
        XCTAssertTrue(manager.hasCachedResponse(for: url))

        let cached = manager.getCachedResponse(for: url)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.data, data)

        manager.removeCachedResponse(for: url)
        XCTAssertFalse(manager.hasCachedResponse(for: url))
    }

    func testSystemCacheStatisticsDefaultInit() {
        let stats = SystemCacheStatistics()
        XCTAssertEqual(stats.totalRequests, 0)
        XCTAssertEqual(stats.cacheHits, 0)
        XCTAssertEqual(stats.cacheMisses, 0)
        XCTAssertEqual(stats.hitRate, 0.0)
        XCTAssertEqual(stats.totalCacheSize, 0)
    }

    func testSystemCacheStatisticsRecordHit() {
        let stats = SystemCacheStatistics()
        stats.recordHit()
        XCTAssertEqual(stats.cacheHits, 1)
        XCTAssertEqual(stats.totalRequests, 1)
        XCTAssertEqual(stats.hitRate, 1.0)
    }

    func testSystemCacheStatisticsRecordMiss() {
        let stats = SystemCacheStatistics()
        stats.recordMiss()
        XCTAssertEqual(stats.cacheMisses, 1)
        XCTAssertEqual(stats.totalRequests, 1)
        XCTAssertEqual(stats.hitRate, 0.0)
    }

    func testSystemCacheStatisticsRecordEviction() {
        let stats = SystemCacheStatistics()
        stats.recordEviction()
    }

    func testSystemCacheStatisticsUpdateAccessTime() {
        let stats = SystemCacheStatistics()
        stats.updateAccessTime(0.1)
        stats.updateAccessTime(0.2)
    }
}
