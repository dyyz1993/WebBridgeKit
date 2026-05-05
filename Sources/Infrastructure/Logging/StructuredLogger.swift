//
//  StructuredLogger.swift
//  WebBridgeKit
//

import Foundation

/// 结构化日志引擎
/// 所有模块共用的日志基础设施，支持多管道输出和结构化查询
public class StructuredLogger {

    public static let shared = StructuredLogger()

    // MARK: - Configuration

    /// 最低输出级别（低于此级别的日志不输出）
    public var minLevel: LogLevel = .debug

    /// 当前会话 ID
    public let sessionId: String

    /// 是否包含文件位置信息
    public var includeFileLocation: Bool = true

    // MARK: - Outputs

    private var outputs: [LogOutput] = []
    private let lock = NSLock()

    /// 内存缓冲（可直接查询）
    public let memoryBuffer: MemoryLogOutput

    init() {
        self.sessionId = UUID().uuidString.prefix(8).lowercased()
        self.memoryBuffer = MemoryLogOutput(maxCapacity: 1000)

        // 默认输出：控制台 + 内存
        self.outputs = [
            ConsoleLogOutput(),
            memoryBuffer
        ]
    }

    // MARK: - Output Management

    /// 添加输出管道
    public func addOutput(_ output: LogOutput) {
        lock.lock()
        defer { lock.unlock() }
        outputs.append(output)
    }

    /// 移除输出管道
    public func removeOutput(_ output: LogOutput) {
        lock.lock()
        defer { lock.unlock() }
        outputs.removeAll { ObjectIdentifier($0) == ObjectIdentifier(output) }
    }

    /// 替换所有输出管道
    public func setOutputs(_ outputs: [LogOutput]) {
        lock.lock()
        defer { lock.unlock() }
        self.outputs = outputs
    }

    // MARK: - Core Logging

    private func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        file: String? = nil,
        function: String? = nil,
        line: Int? = nil,
        context: [String: String]? = nil,
        action: String? = nil,
        durationMs: Double? = nil
    ) {
        guard level >= minLevel else { return }

        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            file: includeFileLocation ? file?.components(separatedBy: "/").last : nil,
            function: function,
            line: line,
            context: context,
            action: action,
            durationMs: durationMs,
            sessionId: sessionId
        )

        lock.lock()
        let currentOutputs = outputs
        lock.unlock()

        for output in currentOutputs {
            output.write(entry)
        }
    }

    // MARK: - Convenience Methods

    public func verbose(_ message: String, category: LogCategory = .general, action: String? = nil,
                        file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .verbose, category: category, message: message, file: file, function: function, line: line, action: action)
    }

    public func debug(_ message: String, category: LogCategory = .general, action: String? = nil,
                      context: [String: String]? = nil,
                      file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, category: category, message: message, file: file, function: function, line: line, context: context, action: action)
    }

    public func info(_ message: String, category: LogCategory = .general, action: String? = nil,
                     context: [String: String]? = nil,
                     file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, category: category, message: message, file: file, function: function, line: line, context: context, action: action)
    }

    public func warning(_ message: String, category: LogCategory = .general, action: String? = nil,
                        context: [String: String]? = nil,
                        file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, category: category, message: message, file: file, function: function, line: line, context: context, action: action)
    }

    public func error(_ message: String, category: LogCategory = .general, action: String? = nil,
                      context: [String: String]? = nil,
                      file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, category: category, message: message, file: file, function: function, line: line, context: context, action: action)
    }

    /// 带耗时的日志（用于性能追踪）
    public func measure<T>(category: LogCategory = .performance, action: String,
                           file: String = #file, function: String = #function, line: Int = #line,
                           block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        log(level: .info, category: category, message: "\(action) completed",
            file: file, function: function, line: line, action: action, durationMs: duration)

        return result
    }

    // MARK: - Query

    /// 查询日志（快捷方式，直接查内存缓冲）
    public func query(
        category: LogCategory? = nil,
        minLevel: LogLevel? = nil,
        action: String? = nil,
        search: String? = nil,
        limit: Int = 100,
        since: Date? = nil
    ) -> [LogEntry] {
        return memoryBuffer.query(
            category: category,
            minLevel: minLevel,
            action: action,
            search: search,
            limit: limit,
            since: since
        )
    }

    /// 导出日志为 JSON
    public func exportJSON() -> String {
        return memoryBuffer.exportJSON()
    }

    /// 清除所有内存缓冲日志
    public func clearBuffer() {
        memoryBuffer.clear()
    }

    /// 获取统计信息
    public func getStats() -> LogStats {
        let entries = memoryBuffer.entries
        return LogStats(
            totalEntries: entries.count,
            errorCount: entries.filter { $0.level == .error }.count,
            warningCount: entries.filter { $0.level == .warning }.count,
            categories: Dictionary(grouping: entries, by: { $0.category })
                .mapValues { $0.count }
        )
    }
}

/// 日志统计
public struct LogStats {
    public let totalEntries: Int
    public let errorCount: Int
    public let warningCount: Int
    public let categories: [LogCategory: Int]
}
