//
//  DiagnosticEngine.swift
//  WebBridgeKit
//

import Foundation
import UIKit

/// 健康检查结果
public struct HealthCheckResult {
    public let name: String
    public let isHealthy: Bool
    public let message: String
    public let details: [String: String]?

    public init(name: String, isHealthy: Bool, message: String, details: [String: String]? = nil) {
        self.name = name
        self.isHealthy = isHealthy
        self.message = message
        self.details = details
    }

    var emoji: String { isHealthy ? "✅" : "❌" }
}

/// 诊断引擎 - 一键全检、错误上下文捕获、环境信息
public class DiagnosticEngine {

    public static let shared = DiagnosticEngine()

    private init() {}

    // MARK: - Health Checks

    /// 一键全检
    public func checkAll() -> [HealthCheckResult] {
        return [
            checkLogger(),
            checkMemory(),
            checkDisk(),
            checkNetwork()
        ]
    }

    /// 检查日志系统
    public func checkLogger() -> HealthCheckResult {
        let stats = StructuredLogger.shared.getStats()
        return HealthCheckResult(
            name: "Logger",
            isHealthy: true,
            message: "\(stats.totalEntries) entries, \(stats.errorCount) errors",
            details: ["total": "\(stats.totalEntries)", "errors": "\(stats.errorCount)", "warnings": "\(stats.warningCount)"]
        )
    }

    /// 检查内存
    public func checkMemory() -> HealthCheckResult {
        let env = EnvironmentInfo()
        let usedPercent = Double(env.physicalMemory - env.freeMemory) / Double(env.physicalMemory) * 100
        let isHealthy = usedPercent < 90

        return HealthCheckResult(
            name: "Memory",
            isHealthy: isHealthy,
            message: "Used \(String(format: "%.1f", usedPercent))% (\(formatBytes(env.physicalMemory - env.freeMemory)) / \(formatBytes(env.physicalMemory)))",
            details: ["free": "\(formatBytes(env.freeMemory))", "total": "\(formatBytes(env.physicalMemory))"]
        )
    }

    /// 检查磁盘
    public func checkDisk() -> HealthCheckResult {
        let env = EnvironmentInfo()
        let usedPercent = Double(env.totalDiskSpace - env.freeDiskSpace) / Double(env.totalDiskSpace) * 100
        let isHealthy = usedPercent < 95

        return HealthCheckResult(
            name: "Disk",
            isHealthy: isHealthy,
            message: "Used \(String(format: "%.1f", usedPercent))% (\(formatBytes(env.totalDiskSpace - env.freeDiskSpace)) / \(formatBytes(env.totalDiskSpace)))",
            details: ["free": "\(formatBytes(env.freeDiskSpace))", "total": "\(formatBytes(env.totalDiskSpace))"]
        )
    }

    /// 检查网络
    public func checkNetwork() -> HealthCheckResult {
        let env = EnvironmentInfo()
        return HealthCheckResult(
            name: "Network",
            isHealthy: env.isConnected,
            message: "\(env.networkType) (\(env.isConnected ? "connected" : "disconnected"))",
            details: ["type": env.networkType]
        )
    }

    // MARK: - Error Context

    /// 捕获错误上下文
    public func captureErrorContext(
        _ error: Error,
        action: String? = nil,
        params: [String: Any]? = nil,
        currentURL: String? = nil,
        customContext: [String: String]? = nil
    ) -> ErrorContext {
        let context = ErrorContext(
            error: error,
            action: action,
            params: params,
            currentURL: currentURL,
            customContext: customContext
        )

        // Log the error with context
        StructuredLogger.shared.error(
            "Error captured: \(error.localizedDescription)",
            category: .diagnostic,
            action: action,
            context: customContext
        )

        return context
    }

    // MARK: - Full Report

    /// 生成完整诊断报告
    public func generateReport() -> String {
        let env = EnvironmentInfo()
        let healthChecks = checkAll()
        let logStats = StructuredLogger.shared.getStats()
        let recentErrors = StructuredLogger.shared.query(minLevel: .error, limit: 10)

        var report = [
            "╔══════════════════════════════════════╗",
            "║     WebBridgeKit Diagnostic Report    ║",
            "╚══════════════════════════════════════╝",
            "",
            "Generated: \(ISO8601DateFormatter().string(from: Date()))",
            "",
            "--- Health Checks ---"
        ]

        for check in healthChecks {
            report.append("  \(check.emoji) \(check.name): \(check.message)")
        }

        report.append("")
        report.append("--- Environment ---")
        report.append(env.debugString)

        report.append("")
        report.append("--- Log Statistics ---")
        report.append("  Total: \(logStats.totalEntries)")
        report.append("  Errors: \(logStats.errorCount)")
        report.append("  Warnings: \(logStats.warningCount)")

        if !recentErrors.isEmpty {
            report.append("")
            report.append("--- Recent Errors (\(recentErrors.count)) ---")
            for error in recentErrors {
                report.append("  \(error.consoleString)")
            }
        }

        report.append("")
        report.append("══════════════════════════════════════")

        return report.joined(separator: "\n")
    }

    /// JSON 格式报告
    public func generateReportJSON() -> [String: Any] {
        let env = EnvironmentInfo()
        let healthChecks = checkAll()
        let logStats = StructuredLogger.shared.getStats()

        return [
            "generated_at": ISO8601DateFormatter().string(from: Date()),
            "health_checks": healthChecks.map { [
                "name": $0.name,
                "healthy": $0.isHealthy,
                "message": $0.message,
                "details": $0.details ?? [:]
            ]},
            "environment": env.jsonDict,
            "log_stats": [
                "total": logStats.totalEntries,
                "errors": logStats.errorCount,
                "warnings": logStats.warningCount
            ]
        ]
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
