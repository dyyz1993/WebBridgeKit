import Foundation
import UIKit
import WebBridgeKit

enum DebugCenterAction {
    case openDebugPanel
    case openDiagnostics
    case openNetworkInspector
    case openCacheDashboard
    case openManifestCacheTests
    case openWebCache
    case openBridgeLab
    case openPushTools
    case showCrashScanGuide
}

final class DebugCenterViewModel: ObservableObject {
    @Published var logCount = "0"
    @Published var errorCount = "0"
    @Published var warningCount = "0"
    @Published var networkCount = "0"
    @Published var crashCount = "0"
    @Published var environment = "Unknown"
    @Published var resultState: ResultPanel.State = .idle
    @Published var resultDetail = ""

    init() {
        refresh()
    }

    var serviceItems: [AppShellStatusItem] {
        [
            AppShellStatusItem(title: "Logs", value: logCount, tone: errorCount == "0" ? .success : .warning),
            AppShellStatusItem(title: "Crash", value: crashCount, tone: crashCount == "0" ? .success : .warning),
            AppShellStatusItem(title: "Network", value: networkCount, tone: .neutral)
        ]
    }

    func refresh() {
        let stats = StructuredLogger.shared.getStats()
        logCount = "\(stats.totalEntries)"
        errorCount = "\(stats.errorCount)"
        warningCount = "\(stats.warningCount)"
        crashCount = "\(countCrashLogs())"
        environment = EnvironmentInfo().summary

        #if DEBUG
        networkCount = "\(MockNetworkRequestStore.shared.getRecentRequests().count)"
        #else
        networkCount = "N/A"
        #endif
    }

    func copyCrashScanCommand() {
        let command = "bash scripts/scan-crash-logs.sh --json"
        UIPasteboard.general.string = command
        resultState = .success("崩溃扫描命令已复制")
        resultDetail = command
    }

    func showCrashScanGuide() {
        resultState = .success("崩溃扫描说明")
        resultDetail = "在项目根目录执行 bash scripts/scan-crash-logs.sh --json，要求 total 为 0。"
    }

    func copyDiagnosticSummary() {
        let summary = """
        {
          "logs": \(logCount),
          "errors": \(errorCount),
          "warnings": \(warningCount),
          "networkRequests": "\(networkCount)",
          "crashes": \(crashCount),
          "environment": "\(environment)"
        }
        """
        UIPasteboard.general.string = summary
        resultState = .success("诊断摘要已复制")
        resultDetail = summary
    }

    private func countCrashLogs() -> Int {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return 0 }
        let crashDirectory = docs.appendingPathComponent("crash_logs")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: crashDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return 0
        }
        return files.filter { $0.pathExtension == "json" }.count
    }
}
