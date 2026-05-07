//
//  DiagnosticEngineAdvancedTests.swift
//  InfrastructureTests
//

import XCTest
@testable import WebBridgeKit

final class DiagnosticEngineAdvancedTests: XCTestCase {

    private var sut: DiagnosticEngine!

    override func setUp() {
        super.setUp()
        sut = DiagnosticEngine.shared
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testSharedSingleton() {
        XCTAssertTrue(DiagnosticEngine.shared === DiagnosticEngine.shared)
    }

    func testCheckAllReturnsResults() {
        let results = sut.checkAll()
        XCTAssertGreaterThanOrEqual(results.count, 4)
    }

    func testCheckLoggerReturnsHealthyResult() {
        let result = sut.checkLogger()
        XCTAssertTrue(result.isHealthy)
        XCTAssertEqual(result.name, "Logger")
        XCTAssertFalse(result.message.isEmpty)
    }

    func testCheckLoggerContainsDetails() {
        let result = sut.checkLogger()
        XCTAssertNotNil(result.details)
        XCTAssertNotNil(result.details?["total"])
        XCTAssertNotNil(result.details?["errors"])
    }

    func testCheckMemoryReturnsResult() {
        let result = sut.checkMemory()
        XCTAssertEqual(result.name, "Memory")
        XCTAssertFalse(result.message.isEmpty)
    }

    func testCheckMemoryContainsDetails() {
        let result = sut.checkMemory()
        XCTAssertNotNil(result.details?["free"])
        XCTAssertNotNil(result.details?["total"])
    }

    func testCheckDiskReturnsResult() {
        let result = sut.checkDisk()
        XCTAssertEqual(result.name, "Disk")
        XCTAssertFalse(result.message.isEmpty)
    }

    func testCheckDiskContainsDetails() {
        let result = sut.checkDisk()
        XCTAssertNotNil(result.details?["free"])
        XCTAssertNotNil(result.details?["total"])
    }

    func testCheckNetworkReturnsResult() {
        let result = sut.checkNetwork()
        XCTAssertEqual(result.name, "Network")
        XCTAssertFalse(result.message.isEmpty)
    }

    func testCaptureErrorContextReturnsContext() {
        let error = NSError(domain: "Test", code: 0, userInfo: [NSLocalizedDescriptionKey: "test error"])
        let context = sut.captureErrorContext(error, action: "testAction")

        XCTAssertEqual(context.error.localizedDescription, "test error")
        XCTAssertEqual(context.action, "testAction")
    }

    func testCaptureErrorContextWithAllParameters() {
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let context = sut.captureErrorContext(
            error,
            action: "fetch",
            params: ["key": "value"],
            currentURL: "https://example.com",
            customContext: ["debug": "info"]
        )

        XCTAssertEqual(context.action, "fetch")
        XCTAssertEqual(context.currentURL, "https://example.com")
        XCTAssertEqual(context.customContext?["debug"], "info")
    }

    func testGenerateReportContainsHeader() {
        let report = sut.generateReport()
        XCTAssertTrue(report.contains("WebBridgeKit Diagnostic Report"))
    }

    func testGenerateReportContainsHealthChecks() {
        let report = sut.generateReport()
        XCTAssertTrue(report.contains("Health Checks"))
        XCTAssertTrue(report.contains("Logger"))
        XCTAssertTrue(report.contains("Memory"))
        XCTAssertTrue(report.contains("Disk"))
        XCTAssertTrue(report.contains("Network"))
    }

    func testGenerateReportContainsEnvironment() {
        let report = sut.generateReport()
        XCTAssertTrue(report.contains("Environment"))
    }

    func testGenerateReportContainsLogStatistics() {
        let report = sut.generateReport()
        XCTAssertTrue(report.contains("Log Statistics"))
    }

    func testGenerateReportJSONContainsRequiredKeys() {
        let report = sut.generateReportJSON()

        XCTAssertNotNil(report["generated_at"])
        XCTAssertNotNil(report["health_checks"])
        XCTAssertNotNil(report["environment"])
        XCTAssertNotNil(report["log_stats"])
    }

    func testGenerateReportJSONHealthChecksAreArray() {
        let report = sut.generateReportJSON()
        let checks = report["health_checks"] as? [[String: Any]]
        XCTAssertNotNil(checks)
        XCTAssertGreaterThanOrEqual(checks?.count ?? 0, 4)
    }

    func testGenerateReportJSONLogStats() {
        let report = sut.generateReportJSON()
        let stats = report["log_stats"] as? [String: Any]
        XCTAssertNotNil(stats)
        XCTAssertNotNil(stats?["total"])
        XCTAssertNotNil(stats?["errors"])
        XCTAssertNotNil(stats?["warnings"])
    }

    func testHealthCheckResultInit() {
        let result = HealthCheckResult(name: "Test", isHealthy: true, message: "All good")
        XCTAssertEqual(result.name, "Test")
        XCTAssertTrue(result.isHealthy)
        XCTAssertEqual(result.message, "All good")
        XCTAssertNil(result.details)
    }

    func testHealthCheckResultInitWithDetails() {
        let result = HealthCheckResult(
            name: "Test",
            isHealthy: false,
            message: "Failed",
            details: ["code": "500"]
        )
        XCTAssertFalse(result.isHealthy)
        XCTAssertEqual(result.details?["code"], "500")
    }

    func testHealthCheckResultEmoji() {
        let healthy = HealthCheckResult(name: "T", isHealthy: true, message: "")
        XCTAssertEqual(healthy.emoji, "✅")

        let unhealthy = HealthCheckResult(name: "T", isHealthy: false, message: "")
        XCTAssertEqual(unhealthy.emoji, "❌")
    }
}
