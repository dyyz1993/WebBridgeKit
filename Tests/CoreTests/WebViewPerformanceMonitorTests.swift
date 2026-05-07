//
//  WebViewPerformanceMonitorTests.swift
//  CoreTests
//

import XCTest
@testable import WebBridgeKit

final class WebViewPerformanceMonitorTests: XCTestCase {

    private var monitor: WebViewPerformanceMonitor!

    override func setUp() {
        super.setUp()
        monitor = WebViewPerformanceMonitor.shared
    }

    override func tearDown() {
        monitor = nil
        super.tearDown()
    }

    // MARK: - Singleton

    func testSharedIsSameInstance() {
        let a = WebViewPerformanceMonitor.shared
        let b = WebViewPerformanceMonitor.shared
        XCTAssertTrue(a === b)
    }

    // MARK: - measureDuration

    func testMeasureDurationReturnsPositiveValue() {
        let duration = monitor.measureDuration {
            Thread.sleep(forTimeInterval: 0.01)
        }
        XCTAssertGreaterThan(duration, 0)
    }

    func testMeasureDurationForInstantOperation() {
        let duration = monitor.measureDuration {
            let _ = 1 + 1
        }
        XCTAssertGreaterThanOrEqual(duration, 0)
    }

    func testMeasureDurationForLongerOperation() {
        let duration = monitor.measureDuration {
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTAssertGreaterThan(duration, 30)
    }

    func testMeasureDurationReturnsMilliseconds() {
        let duration = monitor.measureDuration {
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertGreaterThan(duration, 80)
        XCTAssertLessThan(duration, 500)
    }

    // MARK: - measureOpenBrowser

    func testMeasureOpenBrowserCompletesWithoutCrash() {
        monitor.measureOpenBrowser(label: "TestOpen") {
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    func testMeasureOpenBrowserWithCustomLabel() {
        monitor.measureOpenBrowser(label: "CustomLabel") {
            let _ = "test"
        }
    }

    func testMeasureOpenBrowserWithDefaultLabel() {
        monitor.measureOpenBrowser {
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    // MARK: - measureMemory

    func testMeasureMemoryReturnsNonZeroValue() {
        let memory = monitor.measureMemory()
        XCTAssertGreaterThan(memory, 0)
    }

    func testMeasureMemoryIsReasonable() {
        let memory = monitor.measureMemory()
        let memoryMB = Double(memory) / 1024 / 1024
        XCTAssertGreaterThan(memoryMB, 0)
        XCTAssertLessThan(memoryMB, 1024)
    }

    func testMeasureMemoryMultipleCallsAreConsistent() {
        let mem1 = monitor.measureMemory()
        let mem2 = monitor.measureMemory()
        let diff = abs(Int64(mem1) - Int64(mem2))
        let maxDiff: Int64 = 100 * 1024 * 1024
        XCTAssertLessThan(diff, maxDiff)
    }

    // MARK: - comparePerformance

    func testComparePerformanceCompletesWithoutCrash() {
        monitor.comparePerformance(
            label: "TestCompare",
            before: {
                Thread.sleep(forTimeInterval: 0.01)
            },
            after: {
                Thread.sleep(forTimeInterval: 0.01)
            }
        )
    }

    func testComparePerformanceWithDefaultLabel() {
        monitor.comparePerformance(
            before: {
                let _ = Array(1...100).map { $0 * 2 }
            },
            after: {
                let _ = 1 + 1
            }
        )
    }

    func testComparePerformanceBeforeSlowerThanAfter() {
        monitor.comparePerformance(
            label: "ImprovementTest",
            before: {
                Thread.sleep(forTimeInterval: 0.05)
            },
            after: {
                Thread.sleep(forTimeInterval: 0.01)
            }
        )
    }

    func testComparePerformanceAfterSlowerThanBefore() {
        monitor.comparePerformance(
            label: "RegressionTest",
            before: {
                Thread.sleep(forTimeInterval: 0.01)
            },
            after: {
                Thread.sleep(forTimeInterval: 0.05)
            }
        )
    }

    // MARK: - printPoolStatus

    func testPrintPoolStatusDoesNotCrash() {
        monitor.printPoolStatus()
    }

    func testPrintPoolStatusAfterMemoryWarning() {
        WebViewPool.shared.didReceiveMemoryWarning()
        monitor.printPoolStatus()
    }

    // MARK: - generateReport

    func testGenerateReportReturnsNonEmptyString() {
        let report = monitor.generateReport()
        XCTAssertFalse(report.isEmpty)
    }

    func testGenerateReportContainsMemoryUsage() {
        let report = monitor.generateReport()
        XCTAssertTrue(report.contains("Memory Usage"))
    }

    func testGenerateReportContainsPoolStatus() {
        let report = monitor.generateReport()
        XCTAssertTrue(report.contains("Pool Size"))
        XCTAssertTrue(report.contains("Hit Rate"))
        XCTAssertTrue(report.contains("Warmed Up"))
    }

    func testGenerateReportContainsHeader() {
        let report = monitor.generateReport()
        XCTAssertTrue(report.contains("WebView Performance Report"))
    }
}
