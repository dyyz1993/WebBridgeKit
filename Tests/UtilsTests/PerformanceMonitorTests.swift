//
//  PerformanceMonitorTests.swift
//  UtilsTests
//

import XCTest
@testable import WebBridgeKit

final class PerformanceMonitorTests: XCTestCase {

    private var monitor: PerformanceMonitor!

    override func setUp() {
        super.setUp()
        monitor = PerformanceMonitor.shared
        monitor.clearAllMetrics()
        monitor.isEnabled = true
    }

    override func tearDown() {
        monitor.clearAllMetrics()
        monitor.isEnabled = true
        super.tearDown()
    }

    // MARK: - Measure Execution Time

    func testMeasureSyncOperation() {
        let result = monitor.measure("test.sync") {
            return 42
        }
        XCTAssertEqual(result, 42)

        sleep(1)

        let stats = monitor.getStatistics(for: "test.sync")
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.count, 1)
    }

    func testMeasureSyncOperationWithDuration() {
        let result = monitor.measure("test.duration") {
            Thread.sleep(forTimeInterval: 0.01)
            return "done"
        }
        XCTAssertEqual(result, "done")

        sleep(1)

        let stats = monitor.getStatistics(for: "test.duration")
        XCTAssertNotNil(stats)
        XCTAssertGreaterThanOrEqual(stats!.average, 0.005)
    }

    func testMeasureThrowingSyncOperation() throws {
        let result = try monitor.measure("test.throwing") {
            return 100
        }
        XCTAssertEqual(result, 100)
    }

    func testMeasureAsyncOperation() async {
        let result = await monitor.measure("test.async") {
            try? await Task.sleep(nanoseconds: 10_000_000)
            return "async_done"
        }
        XCTAssertEqual(result, "async_done")
    }

    // MARK: - Statistics Tracking

    func testGetStatisticsReturnsNilForUnknown() {
        let stats = monitor.getStatistics(for: "nonexistent")
        XCTAssertNil(stats)
    }

    func testStatisticsCountIncreases() {
        for i in 0..<5 {
            _ = monitor.measure("test.count") { i }
        }

        sleep(1)

        let stats = monitor.getStatistics(for: "test.count")
        XCTAssertEqual(stats?.count, 5)
    }

    func testStatisticsAverageCalculation() {
        monitor.measure("test.avg") { Thread.sleep(forTimeInterval: 0.01) }
        monitor.measure("test.avg") { Thread.sleep(forTimeInterval: 0.02) }
        monitor.measure("test.avg") { Thread.sleep(forTimeInterval: 0.03) }

        sleep(1)

        let stats = monitor.getStatistics(for: "test.avg")
        XCTAssertNotNil(stats)
        XCTAssertGreaterThanOrEqual(stats!.average, 0.01)
        XCTAssertLessThan(stats!.average, 0.1)
    }

    func testStatisticsMinAndMax() {
        monitor.measure("test.minmax") { Thread.sleep(forTimeInterval: 0.01) }
        monitor.measure("test.minmax") { Thread.sleep(forTimeInterval: 0.05) }

        sleep(1)

        let stats = monitor.getStatistics(for: "test.minmax")
        XCTAssertNotNil(stats)
        XCTAssertLessThanOrEqual(stats!.min, stats!.max)
    }

    func testStatisticsProperties() {
        _ = monitor.measure("test.props") { return 1 }

        sleep(1)

        let stats = monitor.getStatistics(for: "test.props")
        XCTAssertNotNil(stats)
        XCTAssertGreaterThanOrEqual(stats!.averageMs, 0)
        XCTAssertGreaterThanOrEqual(stats!.minMs, 0)
        XCTAssertGreaterThanOrEqual(stats!.maxMs, 0)
        XCTAssertGreaterThanOrEqual(stats!.totalMs, 0)
    }

    func testGetAllStatistics() {
        _ = monitor.measure("test.a") { 1 }
        _ = monitor.measure("test.b") { 2 }

        sleep(1)

        let allStats = monitor.getAllStatistics()
        XCTAssertGreaterThanOrEqual(allStats.count, 2)
        XCTAssertNotNil(allStats["test.a"])
        XCTAssertNotNil(allStats["test.b"])
    }

    // MARK: - Get Metrics

    func testGetMetricsReturnsEmptyForUnknown() {
        let metrics = monitor.getMetrics(for: "nonexistent")
        XCTAssertTrue(metrics.isEmpty)
    }

    func testGetMetricsReturnsRecords() {
        _ = monitor.measure("test.metrics") { 1 }
        _ = monitor.measure("test.metrics") { 2 }

        sleep(1)

        let metrics = monitor.getMetrics(for: "test.metrics")
        XCTAssertEqual(metrics.count, 2)
    }

    // MARK: - Clear Metrics

    func testClearMetricsForOperation() {
        _ = monitor.measure("test.clear") { 1 }
        _ = monitor.measure("test.keep") { 2 }

        sleep(1)

        monitor.clearMetrics(for: "test.clear")
        sleep(1)

        XCTAssertNil(monitor.getStatistics(for: "test.clear"))
        XCTAssertNotNil(monitor.getStatistics(for: "test.keep"))
    }

    func testClearAllMetrics() {
        _ = monitor.measure("test.a") { 1 }
        _ = monitor.measure("test.b") { 2 }

        sleep(1)

        monitor.clearAllMetrics()
        sleep(1)

        XCTAssertTrue(monitor.getAllStatistics().isEmpty)
    }

    // MARK: - Enable / Disable

    func testDisabledMonitorDoesNotRecord() {
        monitor.isEnabled = false
        _ = monitor.measure("test.disabled") { 1 }

        sleep(1)

        XCTAssertNil(monitor.getStatistics(for: "test.disabled"))
    }

    func testEnabledMonitorRecords() {
        monitor.isEnabled = true
        _ = monitor.measure("test.enabled") { 1 }

        sleep(1)

        XCTAssertNotNil(monitor.getStatistics(for: "test.enabled"))
    }

    // MARK: - Export Metrics

    func testExportMetricsAsJSONReturnsValidJSON() {
        _ = monitor.measure("test.export") { 1 }

        sleep(1)

        let json = monitor.exportMetricsAsJSON()
        XCTAssertFalse(json.isEmpty)
        XCTAssertNotEqual(json, "{}")

        let data = json.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(parsed, "Export should produce valid JSON")
    }

    func testExportEmptyMetricsReturnsEmptyJSON() {
        monitor.clearAllMetrics()
        sleep(1)

        let json = monitor.exportMetricsAsJSON()
        XCTAssertEqual(json, "{\n\n}")
    }

    // MARK: - Slow Threshold

    func testSlowThresholdDefault() {
        XCTAssertEqual(monitor.slowThreshold, 1.0)
    }

    func testSlowThresholdMinimum() {
        monitor.slowThreshold = 0.01
        XCTAssertGreaterThanOrEqual(monitor.slowThreshold, 0.1)
    }

    // MARK: - Metric with Metadata

    func testMeasureWithMetadata() {
        _ = monitor.measure("test.meta", metadata: ["key": "value"]) { 1 }

        sleep(1)

        let metrics = monitor.getMetrics(for: "test.meta")
        XCTAssertEqual(metrics.count, 1)
        XCTAssertNotNil(metrics.first?.metadata)
    }

    // MARK: - Shared Singleton

    func testSharedSingleton() {
        let a = PerformanceMonitor.shared
        let b = PerformanceMonitor.shared
        XCTAssertTrue(a === b)
    }
}
