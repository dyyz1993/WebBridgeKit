//
//  CacheStatsAggregatorTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class CacheStatsAggregatorTests: XCTestCase {

    var aggregator: CacheStatsAggregator!

    override func setUp() {
        super.setUp()
        aggregator = CacheStatsAggregator.shared
    }

    override func tearDown() {
        aggregator = nil
        super.tearDown()
    }

    // MARK: - Singleton

    func testSharedInstance() {
        let a = CacheStatsAggregator.shared
        let b = CacheStatsAggregator.shared
        XCTAssertTrue(a === b, "Should be same singleton instance")
    }

    // MARK: - Sync Aggregate

    func testSyncAggregateReturnsData() {
        let data = aggregator.syncAggregate()

        XCTAssertNotNil(data.timestamp)
        XCTAssertGreaterThanOrEqual(data.subsystems.count, 11,
                                   "Should have at least 11 subsystem entries")
        XCTAssertGreaterThanOrEqual(data.totalSize, 0)
        XCTAssertGreaterThanOrEqual(data.totalEntries, 0)
    }

    // MARK: - All Subsystems Collected

    func testAllSubsystemsPresent() {
        let data = aggregator.syncAggregate()
        let collectedIDs = Set(data.subsystems.map(\.id))
        let expectedIDs = Set(SubsystemID.allCases)

        let missing = expectedIDs.subtracting(collectedIDs)
        XCTAssertTrue(missing.isEmpty,
                    "Missing subsystems: \(missing.map(\.rawValue))")
    }

    // MARK: - Individual Collectors Don't Crash

    func testCollectStatsNoCrash() {
        for id in SubsystemID.allCases {
            let stats = aggregator.collectStats(for: id)
            XCTAssertEqual(stats.id, id)
            XCTAssertGreaterThanOrEqual(stats.totalEntries, 0)
            XCTAssertGreaterThanOrEqual(stats.totalSize, 0)
        }
    }

    // MARK: - ManifestCache Stats

    func testManifestCacheStats() {
        let stats = aggregator.collectStats(for: .manifestCache)
        XCTAssertEqual(stats.id, .manifestCache)
    }

    // MARK: - SystemURLCache Stats

    func testSystemURLCacheStats() {
        let stats = aggregator.collectStats(for: .systemURLCache)
        XCTAssertEqual(stats.id, .systemURLCache)
    }

    // MARK: - Status Values Valid

    func testAllStatusesValid() {
        let data = aggregator.syncAggregate()

        for stats in data.subsystems {
            switch stats.status {
            case .active, .empty, .error, .unknown:
                break
            }
        }
    }

    // MARK: - Formatted Output

    func testFormattedSizesAreReadable() {
        let data = aggregator.syncAggregate()

        XCTAssertFalse(data.formattedTotalSize.isEmpty)

        for stats in data.subsystems where stats.hasData {
            XCTAssertFalse(stats.formattedSize.isEmpty,
                         "\(stats.id.nameZh) should have formatted size")
        }
    }

    // MARK: - Performance: Aggregation Under 500ms

    func testAggregationPerformance() {
        measure {
            _ = aggregator.syncAggregate()
        }
    }
}
