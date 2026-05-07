import XCTest
@testable import WebBridgeKit

final class CacheStatisticsTests: XCTestCase {

    func testInitialState() {
        let stats = CacheStatistics()
        XCTAssertEqual(stats.hitCount, 0)
        XCTAssertEqual(stats.missCount, 0)
        XCTAssertEqual(stats.evictionCount, 0)
        XCTAssertEqual(stats.totalEntries, 0)
        XCTAssertEqual(stats.totalSizeBytes, 0)
        XCTAssertEqual(stats.averageAccessTime, 0)
    }

    func testTotalRequestsZero() {
        let stats = CacheStatistics()
        XCTAssertEqual(stats.totalRequests, 0)
    }

    func testTotalRequestsAfterHit() {
        var stats = CacheStatistics()
        stats.recordHit()
        XCTAssertEqual(stats.totalRequests, 1)
    }

    func testTotalRequestsAfterMiss() {
        var stats = CacheStatistics()
        stats.recordMiss()
        XCTAssertEqual(stats.totalRequests, 1)
    }

    func testTotalRequestsMixed() {
        var stats = CacheStatistics()
        stats.recordHit()
        stats.recordHit()
        stats.recordMiss()
        XCTAssertEqual(stats.totalRequests, 3)
    }

    func testHitRateZeroRequests() {
        let stats = CacheStatistics()
        XCTAssertEqual(stats.hitRate, 0.0)
    }

    func testHitRateAllHits() {
        var stats = CacheStatistics()
        stats.recordHit()
        stats.recordHit()
        stats.recordHit()
        XCTAssertEqual(stats.hitRate, 1.0)
    }

    func testHitRateAllMisses() {
        var stats = CacheStatistics()
        stats.recordMiss()
        stats.recordMiss()
        XCTAssertEqual(stats.hitRate, 0.0)
    }

    func testHitRateMixed() {
        var stats = CacheStatistics()
        stats.recordHit()
        stats.recordMiss()
        XCTAssertEqual(stats.hitRate, 0.5)
    }

    func testMissRateZeroRequests() {
        let stats = CacheStatistics()
        XCTAssertEqual(stats.missRate, 1.0)
    }

    func testMissRateAllHits() {
        var stats = CacheStatistics()
        stats.recordHit()
        stats.recordHit()
        XCTAssertEqual(stats.missRate, 0.0)
    }

    func testMissRateAllMisses() {
        var stats = CacheStatistics()
        stats.recordMiss()
        stats.recordMiss()
        XCTAssertEqual(stats.missRate, 1.0)
    }

    func testRecordHitIncrementsHitCount() {
        var stats = CacheStatistics()
        stats.recordHit()
        stats.recordHit()
        stats.recordHit()
        XCTAssertEqual(stats.hitCount, 3)
    }

    func testRecordMissIncrementsMissCount() {
        var stats = CacheStatistics()
        stats.recordMiss()
        stats.recordMiss()
        XCTAssertEqual(stats.missCount, 2)
    }

    func testRecordEvictionIncrementsEvictionCount() {
        var stats = CacheStatistics()
        stats.recordEviction()
        stats.recordEviction()
        XCTAssertEqual(stats.evictionCount, 2)
    }

    func testUpdateAccessTimeFirstValue() {
        var stats = CacheStatistics()
        stats.recordHit()
        stats.updateAccessTime(0.5)
        XCTAssertEqual(stats.averageAccessTime, 0.25)
    }

    func testUpdateAccessTimeMultiple() {
        var stats = CacheStatistics()
        stats.recordHit()
        stats.updateAccessTime(0.1)
        stats.recordHit()
        stats.updateAccessTime(0.3)
        XCTAssertEqual(stats.averageAccessTime, 2.0 / 15.0, accuracy: 0.0001)
    }

    func testLastUpdatedChangesOnRecordHit() {
        var stats = CacheStatistics()
        let before = stats.lastUpdated
        Thread.sleep(forTimeInterval: 0.01)
        stats.recordHit()
        XCTAssertGreaterThanOrEqual(stats.lastUpdated, before)
    }

    func testLastUpdatedChangesOnRecordMiss() {
        var stats = CacheStatistics()
        let before = stats.lastUpdated
        Thread.sleep(forTimeInterval: 0.01)
        stats.recordMiss()
        XCTAssertGreaterThanOrEqual(stats.lastUpdated, before)
    }

    func testLastUpdatedChangesOnRecordEviction() {
        var stats = CacheStatistics()
        let before = stats.lastUpdated
        Thread.sleep(forTimeInterval: 0.01)
        stats.recordEviction()
        XCTAssertGreaterThanOrEqual(stats.lastUpdated, before)
    }

    func testCodableRoundTrip() throws {
        var stats = CacheStatistics()
        stats.recordHit()
        stats.recordHit()
        stats.recordMiss()
        stats.recordEviction()
        stats.totalEntries = 10
        stats.totalSizeBytes = 1024

        let encoder = JSONEncoder()
        let data = try encoder.encode(stats)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CacheStatistics.self, from: data)

        XCTAssertEqual(decoded.hitCount, 2)
        XCTAssertEqual(decoded.missCount, 1)
        XCTAssertEqual(decoded.evictionCount, 1)
        XCTAssertEqual(decoded.totalEntries, 10)
        XCTAssertEqual(decoded.totalSizeBytes, 1024)
        XCTAssertEqual(decoded.hitRate, stats.hitRate)
    }
}
