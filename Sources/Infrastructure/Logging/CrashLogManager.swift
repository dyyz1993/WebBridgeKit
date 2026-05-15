//
//  CrashLogManager.swift
//  WebBridgeKit
//

import Foundation
import MachO
import UIKit
import os

public struct CrashReport: Codable {
    public let type: String
    public let timestamp: String
    public let name: String
    public let reason: String
    public let callStack: [String]
    public let appVersion: String
    public let buildNumber: String
    public let deviceModel: String
    public let systemVersion: String
    public let memoryFootprintMB: Double
    public let sessionId: String
}

private func wbk_crashSignalHandler(_ sig: Int32) {
    CrashLogManager.shared._handleSignal(sig)
}

public class CrashLogManager {

    public static let shared = CrashLogManager()

    private let crashDirectory: URL
    private let fileManager = FileManager.default
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private var previousExceptionHandler: NSUncaughtExceptionHandler?
    private var savedPreviousSignalHandlers: [Int32: (@convention(c) (Int32) -> Void)] = [:]

    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        crashDirectory = docs.appendingPathComponent("crash_logs", isDirectory: true)
    }

    public func initialize() {
        createCrashDirectoryIfNeeded()
        installHandlers()
        checkForPreviousCrash()
    }

    public var hasUnresolvedCrash: Bool {
        return !crashLogFiles().isEmpty
    }

    public func getCrashLogs() -> [CrashReport] {
        return crashLogFiles().compactMap { url -> CrashReport? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(CrashReport.self, from: data)
        }
    }

    public func clearCrashLogs() {
        for url in crashLogFiles() {
            try? fileManager.removeItem(at: url)
        }
    }

    public func getLastCrashSummary() -> String? {
        guard let last = getCrashLogFilesSorted().last,
              let data = try? Data(contentsOf: last),
              let report = try? JSONDecoder().decode(CrashReport.self, from: data) else {
            return nil
        }
        return "\(report.type): \(report.name) — \(report.reason) (session: \(report.sessionId))"
    }

    // MARK: - Internal (called from top-level C function)

    fileprivate func _handleSignal(_ sig: Int32) {
        let name = signalNameString(sig)
        let callStack = Thread.callStackSymbols

        let report = CrashReport(
            type: "signal",
            timestamp: isoFormatter.string(from: Date()),
            name: name,
            reason: "Signal \(sig) (\(name)) received",
            callStack: callStack,
            appVersion: appVersion,
            buildNumber: buildNumber,
            deviceModel: deviceModel,
            systemVersion: systemVersion,
            memoryFootprintMB: memoryFootprintMB,
            sessionId: StructuredLogger.shared.sessionId
        )
        writeCrashReport(report)

        if let prev = savedPreviousSignalHandlers[sig] {
            prev(sig)
        }

        raise(SIGKILL)
    }

    // MARK: - Private

    private func createCrashDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: crashDirectory.path) {
            try? fileManager.createDirectory(at: crashDirectory, withIntermediateDirectories: true)
        }
    }

    private func installHandlers() {
        previousExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { exception in
            CrashLogManager.shared.handleException(exception)
            CrashLogManager.shared.previousExceptionHandler?(exception)
        }

        let signals: [Int32] = [SIGABRT, SIGSEGV, SIGBUS, SIGFPE, SIGILL, SIGTRAP]
        for sig in signals {
            var old = sigaction()
            sigaction(sig, nil, &old)
            let oldHandler = old.__sigaction_u.__sa_handler
            if let oldHandler = oldHandler {
                savedPreviousSignalHandlers[sig] = oldHandler
            }

            var newAction = sigaction()
            newAction.__sigaction_u.__sa_handler = wbk_crashSignalHandler
            sigemptyset(&newAction.sa_mask)
            newAction.sa_flags = 0
            sigaction(sig, &newAction, nil)
        }
    }

    private func checkForPreviousCrash() {
        let files = crashLogFiles()
        guard !files.isEmpty else { return }

        let reports = getCrashLogs()
        let count = reports.count
        let lastSummary = reports.last.map { "\($0.type): \($0.name)" } ?? "unknown"

        StructuredLogger.shared.error(
            "Previous session crash detected (\(count) crash log(s), latest: \(lastSummary))",
            category: .diagnostic,
            context: ["crashCount": "\(count)", "latestType": reports.last?.type ?? ""]
        )
    }

    private func handleException(_ exception: NSException) {
        let report = CrashReport(
            type: "exception",
            timestamp: isoFormatter.string(from: Date()),
            name: exception.name.rawValue,
            reason: exception.reason ?? "Unknown exception",
            callStack: exception.callStackSymbols ?? [],
            appVersion: appVersion,
            buildNumber: buildNumber,
            deviceModel: deviceModel,
            systemVersion: systemVersion,
            memoryFootprintMB: memoryFootprintMB,
            sessionId: StructuredLogger.shared.sessionId
        )
        writeCrashReport(report)
    }

    private func writeCrashReport(_ report: CrashReport) {
        guard let data = try? JSONEncoder().encode(report) else { return }

        let filename = "crash_\(Int(Date().timeIntervalSince1970)).json"
        let url = crashDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
    }

    private func crashLogFiles() -> [URL] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: crashDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }
        return urls.filter { $0.pathExtension == "json" }
    }

    private func getCrashLogFilesSorted() -> [URL] {
        return crashLogFiles().sorted { a, b in
            a.lastPathComponent < b.lastPathComponent
        }
    }

    // MARK: - Device Info

    private var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }

    private var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    private var systemVersion: String {
        return UIDevice.current.systemVersion
    }

    private var memoryFootprintMB: Double {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let bytes = taskInfo.phys_footprint
            return Double(bytes) / (1024.0 * 1024.0)
        }

        let available = os_proc_available_memory()
        if available > 0 {
            let total = ProcessInfo.processInfo.physicalMemory
            let used = total > available ? total - UInt64(available) : 0
            return Double(used) / (1024.0 * 1024.0)
        }

        return 0
    }

    private func signalNameString(_ sig: Int32) -> String {
        switch sig {
        case SIGABRT: return "SIGABRT"
        case SIGSEGV: return "SIGSEGV"
        case SIGBUS:  return "SIGBUS"
        case SIGFPE:  return "SIGFPE"
        case SIGILL:  return "SIGILL"
        case SIGTRAP: return "SIGTRAP"
        default:      return "SIG\(sig)"
        }
    }
}
