//
//  DiagnosticTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class DiagnosticTests: XCTestCase {

    // MARK: - EnvironmentInfo

    func testEnvironmentInfo() {
        let env = EnvironmentInfo()

        XCTAssertFalse(env.appVersion.isEmpty)
        XCTAssertFalse(env.deviceModel.isEmpty)
        XCTAssertFalse(env.systemVersion.isEmpty)
        XCTAssertGreaterThan(env.physicalMemory, 0)
        XCTAssertGreaterThan(env.totalDiskSpace, 0)
    }

    func testEnvironmentInfoSummary() {
        let env = EnvironmentInfo()
        let summary = env.summary

        XCTAssertTrue(summary.contains("Memory:"))
        XCTAssertTrue(summary.contains("Disk:"))
        XCTAssertTrue(summary.contains("Network:"))
    }

    func testEnvironmentInfoJSON() {
        let env = EnvironmentInfo()
        let json = env.jsonDict

        XCTAssertNotNil(json["app_version"])
        XCTAssertNotNil(json["device_model"])
        XCTAssertNotNil(json["os_version"])
        XCTAssertNotNil(json["free_memory"])
        XCTAssertNotNil(json["free_disk"])
    }

    func testEnvironmentInfoDebugString() {
        let env = EnvironmentInfo()
        let debug = env.debugString

        XCTAssertTrue(debug.contains("=== Environment Info ==="))
        XCTAssertTrue(debug.contains("========================"))
    }

    // MARK: - ErrorContext

    func testErrorContextCapture() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test error message" }
        }

        let context = ErrorContext(
            error: TestError(),
            action: "camera",
            params: ["mode": "photo"],
            currentURL: "https://example.com",
            customContext: ["retry_count": "3"]
        )

        XCTAssertEqual(context.action, "camera")
        XCTAssertNotNil(context.params)
        XCTAssertEqual(context.currentURL, "https://example.com")
        XCTAssertEqual(context.customContext?["retry_count"], "3")
    }

    func testErrorContextDebugString() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Something went wrong" }
        }

        let context = ErrorContext(error: TestError(), action: "test")
        let debug = context.debugString

        XCTAssertTrue(debug.contains("ERROR CONTEXT"))
        XCTAssertTrue(debug.contains("Something went wrong"))
        XCTAssertTrue(debug.contains("test"))
    }

    func testErrorContextJSON() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "JSON test error" }
        }

        let context = ErrorContext(error: TestError())
        let json = context.jsonDict

        XCTAssertNotNil(json["timestamp"])
        XCTAssertNotNil(json["error"])
        XCTAssertNotNil(json["environment"])
    }

    // MARK: - DiagnosticEngine

    func testHealthChecks() {
        let engine = DiagnosticEngine()
        let results = engine.checkAll()

        XCTAssertFalse(results.isEmpty)
        for result in results {
            XCTAssertFalse(result.name.isEmpty)
            XCTAssertFalse(result.message.isEmpty)
        }
    }

    func testMemoryCheck() {
        let engine = DiagnosticEngine()
        let result = engine.checkMemory()

        XCTAssertTrue(result.message.contains("Used"))
    }

    func testDiskCheck() {
        let engine = DiagnosticEngine()
        let result = engine.checkDisk()

        XCTAssertTrue(result.message.contains("Used"))
    }

    func testNetworkCheck() {
        let engine = DiagnosticEngine()
        let result = engine.checkNetwork()

        XCTAssertTrue(result.message.contains("WiFi") || result.message.contains("Cellular") || result.message.contains("Unknown"))
    }

    func testDiagnosticReport() {
        let engine = DiagnosticEngine()
        let report = engine.generateReport()

        XCTAssertTrue(report.contains("Diagnostic Report"))
        XCTAssertTrue(report.contains("Health Checks"))
        XCTAssertTrue(report.contains("Environment"))
    }

    func testDiagnosticReportJSON() {
        let engine = DiagnosticEngine()
        let json = engine.generateReportJSON()

        XCTAssertNotNil(json["generated_at"])
        XCTAssertNotNil(json["health_checks"])
        XCTAssertNotNil(json["environment"])
        XCTAssertNotNil(json["log_stats"])
    }
}
