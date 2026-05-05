//
//  LogPipeline.swift
//  WebBridgeKit
//

import Foundation

/// 日志输出管道协议
public protocol LogOutput: AnyObject {
    func write(_ entry: LogEntry)
    func flush()
}

/// 控制台输出
public class ConsoleLogOutput: LogOutput {

    public init() {}

    public func write(_ entry: LogEntry) {
        #if DEBUG
        print(entry.consoleString)
        #endif
    }

    public func flush() {
        fflush(stdout)
    }
}

/// 内存环形缓冲输出（可查询最近 N 条日志）
public class MemoryLogOutput: LogOutput {

    public private(set) var entries: [LogEntry] = []
    public let maxCapacity: Int

    private let lock = NSLock()

    public init(maxCapacity: Int = 1000) {
        self.maxCapacity = maxCapacity
    }

    public func write(_ entry: LogEntry) {
        lock.lock()
        defer { lock.unlock() }

        entries.append(entry)
        if entries.count > maxCapacity {
            entries.removeFirst(entries.count - maxCapacity)
        }
    }

    public func flush() {
        // Memory buffer doesn't need flushing
    }

    /// 查询日志
    public func query(
        category: LogCategory? = nil,
        minLevel: LogLevel? = nil,
        action: String? = nil,
        search: String? = nil,
        limit: Int? = nil,
        since: Date? = nil
    ) -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }

        var results = entries

        if let category = category {
            results = results.filter { $0.category == category }
        }
        if let minLevel = minLevel {
            results = results.filter { $0.level >= minLevel }
        }
        if let action = action {
            results = results.filter { $0.action == action }
        }
        if let search = search {
            let keyword = search.lowercased()
            results = results.filter {
                $0.message.lowercased().contains(keyword) ||
                    ($0.context?.values.contains(where: { $0.lowercased().contains(keyword) }) ?? false)
            }
        }
        if let since = since {
            results = results.filter { $0.timestamp >= since }
        }

        // Return most recent first
        results.reverse()

        if let limit = limit {
            results = Array(results.prefix(limit))
        }

        return results
    }

    /// 清除所有缓冲日志
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }

    /// 导出为 JSON
    public func exportJSON() -> String {
        lock.lock()
        let entries = self.entries
        lock.unlock()

        let jsonArray = entries.map { $0.jsonDict }
        guard let data = try? JSONSerialization.data(withJSONObject: jsonArray, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}

/// 文件输出（自动轮转）
public class FileLogOutput: LogOutput {

    public let filePath: String
    public let maxFileSize: Int // bytes

    private let writeQueue = DispatchQueue(label: "com.webbridgekit.logfile", qos: .utility)
    private let fileHandle: FileHandle?

    public init(filePath: String? = nil, maxFileSize: Int = 10 * 1024 * 1024) {
        self.maxFileSize = maxFileSize

        let path = filePath ?? (NSTemporaryDirectory() + "webbridgekit.log")
        self.filePath = path

        // Create file if not exists
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }

        self.fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path))

        // Rotate if file too large
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attrs[.size] as? Int, size > maxFileSize {
            self.rotate()
        }
    }

    public func write(_ entry: LogEntry) {
        writeQueue.async { [weak self] in
            guard let self = self else { return }

            let line = entry.jsonString + "\n"
            guard let data = line.data(using: .utf8) else { return }

            self.fileHandle?.seekToEndOfFile()
            self.fileHandle?.write(data)

            // Check size and rotate if needed
            if let attrs = try? FileManager.default.attributesOfItem(atPath: self.filePath),
               let size = attrs[.size] as? Int, size > self.maxFileSize {
                self.rotate()
            }
        }
    }

    public func flush() {
        writeQueue.sync { [weak self] in
            self?.fileHandle?.synchronizeFile()
        }
    }

    private func rotate() {
        fileHandle?.truncateFile(atOffset: 0)
        fileHandle?.seek(toFileOffset: 0)
    }
}

/// 自定义回调输出
public class CallbackLogOutput: LogOutput {

    public var onLog: ((LogEntry) -> Void)?

    public init(onLog: ((LogEntry) -> Void)? = nil) {
        self.onLog = onLog
    }

    public func write(_ entry: LogEntry) {
        onLog?(entry)
    }

    public func flush() {}
}
