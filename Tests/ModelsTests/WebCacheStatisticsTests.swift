import XCTest
@testable import WebBridgeKit

final class WebCacheStatisticsTests: XCTestCase {

    func testDefaultDomainIsEmpty() {
        let stats = WebCacheStatistics()
        XCTAssertEqual(stats.domain, "")
    }

    func testDefaultTotalSizeIsZero() {
        let stats = WebCacheStatistics()
        XCTAssertEqual(stats.totalSize, 0)
    }

    func testDefaultFileCountIsZero() {
        let stats = WebCacheStatistics()
        XCTAssertEqual(stats.fileCount, 0)
    }

    func testPrimaryKeyIsDomain() {
        XCTAssertEqual(WebCacheStatistics.primaryKey(), "domain")
    }

    func testIndexedProperties() {
        let indexed = WebCacheStatistics.indexedProperties()
        XCTAssertTrue(indexed.contains("domain"))
        XCTAssertTrue(indexed.contains("lastUpdate"))
        XCTAssertEqual(indexed.count, 2)
    }

    func testFormattedSizeZeroBytes() {
        let stats = WebCacheStatistics()
        stats.totalSize = 0
        let formatted = stats.formattedSize
        XCTAssertTrue(formatted.contains("0 bytes") || formatted.isEmpty || formatted == "0 bytes")
    }

    func testFormattedSizeSmallValue() {
        let stats = WebCacheStatistics()
        stats.totalSize = 512
        let formatted = stats.formattedSize
        XCTAssertFalse(formatted.isEmpty)
    }

    func testFormattedSizeKilobytes() {
        let stats = WebCacheStatistics()
        stats.totalSize = 1024
        let formatted = stats.formattedSize
        XCTAssertTrue(formatted.contains("KB"))
    }

    func testFormattedSizeMegabytes() {
        let stats = WebCacheStatistics()
        stats.totalSize = 5 * 1024 * 1024
        let formatted = stats.formattedSize
        XCTAssertTrue(formatted.contains("MB"))
    }

    func testFormattedSizeGigabytes() {
        let stats = WebCacheStatistics()
        stats.totalSize = Int64(2) * 1024 * 1024 * 1024
        let formatted = stats.formattedSize
        XCTAssertTrue(formatted.contains("GB"))
    }

    func testPropertyAssignment() {
        let stats = WebCacheStatistics()
        stats.domain = "example.com"
        stats.totalSize = 999999
        stats.fileCount = 42
        let now = Date()
        stats.lastUpdate = now

        XCTAssertEqual(stats.domain, "example.com")
        XCTAssertEqual(stats.totalSize, 999999)
        XCTAssertEqual(stats.fileCount, 42)
        XCTAssertEqual(stats.lastUpdate, now)
    }

    func testLastUpdateDefaultsToRecentDate() {
        let stats = WebCacheStatistics()
        let now = Date()
        let diff = abs(stats.lastUpdate.timeIntervalSince(now))
        XCTAssertLessThan(diff, 10.0)
    }

    func testFileCountAssignment() {
        let stats = WebCacheStatistics()
        stats.fileCount = 100
        XCTAssertEqual(stats.fileCount, 100)
    }
}
