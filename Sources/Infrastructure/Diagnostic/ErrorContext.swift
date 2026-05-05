//
//  ErrorContext.swift
//  WebBridgeKit
//

import Foundation

/// 错误上下文 - 错误发生时自动捕获的完整调试信息
public struct ErrorContext {
    
    /// 错误本身
    public let error: Error
    
    /// 发生时间
    public let timestamp: Date
    
    /// 关联的 Handler action
    public let action: String?
    
    /// Handler 参数
    public let params: [String: Any]?
    
    /// 当前 WebView URL
    public let currentURL: String?
    
    /// 最近的日志条目（最多 20 条）
    public let recentLogs: [LogEntry]
    
    /// 环境快照
    public let environment: EnvironmentInfo
    
    /// 自定义上下文
    public let customContext: [String: String]?
    
    public init(
        error: Error,
        action: String? = nil,
        params: [String: Any]? = nil,
        currentURL: String? = nil,
        customContext: [String: String]? = nil
    ) {
        self.error = error
        self.timestamp = Date()
        self.action = action
        self.params = params
        self.currentURL = currentURL
        self.customContext = customContext
        self.recentLogs = StructuredLogger.shared.memoryBuffer.query(minLevel: .debug, limit: 20)
        self.environment = EnvironmentInfo()
    }
    
    // MARK: - Formatted Output
    
    /// 可复制的完整调试信息
    public var debugString: String {
        var lines = [
            "============ ERROR CONTEXT ============",
            "Time: \(ISO8601DateFormatter().string(from: timestamp))",
            "",
            "--- Error ---",
            "Description: \(error.localizedDescription)"
        ]
        
        if let action = action {
            lines.append("Action: \(action)")
        }
        if let currentURL = currentURL {
            lines.append("URL: \(currentURL)")
        }
        if let params = params {
            lines.append("Params: \(String(describing: params))")
        }
        if let customContext = customContext {
            lines.append("")
            lines.append("--- Custom Context ---")
            for (k, v) in customContext {
                lines.append("  \(k): \(v)")
            }
        }
        
        lines.append("")
        lines.append("--- Environment ---")
        lines.append(environment.summary)
        
        if !recentLogs.isEmpty {
            lines.append("")
            lines.append("--- Recent Logs (\(recentLogs.count) entries) ---")
            for log in recentLogs {
                lines.append("  \(log.consoleString)")
            }
        }
        
        lines.append("========================================")
        return lines.joined(separator: "\n")
    }
    
    /// JSON 格式
    public var jsonDict: [String: Any] {
        var dict: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "error": error.localizedDescription,
            "environment": environment.jsonDict
        ]
        if let action = action { dict["action"] = action }
        if let currentURL = currentURL { dict["url"] = currentURL }
        if let params = params {
            // Convert params to JSON-safe types
            if let data = try? JSONSerialization.data(withJSONObject: params, options: []),
               let jsonString = String(data: data, encoding: .utf8) {
                dict["params"] = jsonString
            }
        }
        if let customContext = customContext { dict["custom_context"] = customContext }
        dict["recent_logs"] = recentLogs.map { $0.jsonDict }
        return dict
    }
    
    /// JSON 字符串
    public var jsonString: String {
        guard let data = try? JSONSerialization.data(withJSONObject: jsonDict, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{ \"error\": \"serialization failed\" }"
        }
        return string
    }
}
