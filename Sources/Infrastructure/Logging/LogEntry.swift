//
//  LogEntry.swift
//  WebBridgeKit
//

import Foundation

/// 日志级别
public enum LogLevel: Int, Comparable, Codable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var emoji: String {
        switch self {
        case .verbose: return "💬"
        case .debug:   return "🐛"
        case .info:    return "ℹ️"
        case .warning: return "⚠️"
        case .error:   return "❌"
        }
    }

    var tag: String {
        switch self {
        case .verbose: return "VRB"
        case .debug:   return "DBG"
        case .info:    return "INF"
        case .warning: return "WRN"
        case .error:   return "ERR"
        }
    }
}

/// 日志分类
public enum LogCategory: String, Codable, CaseIterable {
    case general     = "general"
    case bridge      = "bridge"
    case cache       = "cache"
    case network     = "network"
    case handler     = "handler"
    case performance = "perf"
    case lifecycle   = "lifecycle"
    case ui          = "ui"
    case permission  = "permission"
    case storage     = "storage"
    case navigation  = "navigation"
    case diagnostic  = "diagnostic"

    var emoji: String {
        switch self {
        case .general:     return "📌"
        case .bridge:      return "🌉"
        case .cache:       return "📦"
        case .network:     return "🌐"
        case .handler:     return "⚙️"
        case .performance: return "⚡"
        case .lifecycle:   return "🔄"
        case .ui:          return "🎨"
        case .permission:  return "🔐"
        case .storage:     return "💾"
        case .navigation:  return "🧭"
        case .diagnostic:  return "🔍"
        }
    }
}

/// 结构化日志条目
public struct LogEntry: Codable {
    /// 唯一 ID
    public let id: UUID

    /// 时间戳
    public let timestamp: Date

    /// 级别
    public let level: LogLevel

    /// 分类
    public let category: LogCategory

    /// 消息
    public let message: String

    /// 文件名
    public let file: String?

    /// 函数名
    public let function: String?

    /// 行号
    public let line: Int?

    /// 附加上下文
    public let context: [String: String]?

    /// 关联的 action（如 Handler 名称）
    public let action: String?

    /// 耗时（毫秒）
    public let durationMs: Double?

    /// 会话 ID
    public let sessionId: String?

    public init(
        level: LogLevel,
        category: LogCategory,
        message: String,
        file: String? = nil,
        function: String? = nil,
        line: Int? = nil,
        context: [String: String]? = nil,
        action: String? = nil,
        durationMs: Double? = nil,
        sessionId: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.file = file
        self.function = function
        self.line = line
        self.context = context
        self.action = action
        self.durationMs = durationMs
        self.sessionId = sessionId
    }

    // MARK: - JSON

    /// 转换为 JSON 字典
    public var jsonDict: [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "ts": ISO8601DateFormatter().string(from: timestamp),
            "level": level.tag,
            "category": category.rawValue,
            "message": message
        ]
        if let file = file { dict["file"] = file }
        if let function = function { dict["function"] = function }
        if let line = line { dict["line"] = line }
        if let context = context { dict["context"] = context }
        if let action = action { dict["action"] = action }
        if let durationMs = durationMs { dict["duration_ms"] = durationMs }
        if let sessionId = sessionId { dict["session_id"] = sessionId }
        return dict
    }

    /// 转换为 JSON 字符串
    public var jsonString: String {
        guard let data = try? JSONSerialization.data(withJSONObject: jsonDict, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{ \"error\": \"failed to serialize\" }"
        }
        return string
    }

    // MARK: - Console Format

    /// 控制台可读格式
    public var consoleString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        let time = dateFormatter.string(from: timestamp)

        var parts = ["\(time) \(level.emoji)[\(level.tag)] [\(category.rawValue)]"]
        if let action = action {
            parts.append("[\(action)]")
        }
        parts.append(message)
        if let duration = durationMs {
            parts.append("( \(String(format: "%.1f", duration))ms )")
        }
        return parts.joined(separator: " ")
    }

    /// 可复制的调试信息
    public var debugString: String {
        var lines = [
            "=== Log Entry ===",
            "Time: \(ISO8601DateFormatter().string(from: timestamp))",
            "Level: \(level.tag)",
            "Category: \(category.rawValue)",
            "Message: \(message)"
        ]
        if let action = action { lines.append("Action: \(action)") }
        if let duration = durationMs { lines.append("Duration: \(String(format: "%.1f", duration))ms") }
        if let file = file, let line = line { lines.append("Location: \(file):\(line)") }
        if let context = context {
            lines.append("Context:")
            for (k, v) in context { lines.append("  \(k): \(v)") }
        }
        lines.append("=== JSON ===")
        lines.append(jsonString)
        return lines.joined(separator: "\n")
    }
}
