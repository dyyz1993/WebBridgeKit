//
//  WebBridgeLogger.swift
//  WebBridgeKit
//
//  Created by WebBridgeKit
//

import Foundation
import os.log

/// WebBridgeKit 日志系统
public class WebBridgeLogger {

    // MARK: - Singleton

    public static let shared = WebBridgeLogger()

    private init() {}

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.webbridgekit", category: "WebBridge")

    public var isEnabled: Bool = true

    // MARK: - Log Levels

    public enum LogLevel: Int {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3

        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }

        var prefix: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARN"
            case .error: return "ERROR"
            }
        }
    }

    // MARK: - Log Categories

    public enum LogCategory: String {
        case general = "General"
        case cache = "Cache"
        case network = "Network"
        case browser = "Browser"
        case manifest = "Manifest"
        case realm = "Realm"
        case ui = "UI"
        case performance = "Performance"
    }

    // MARK: - Configuration

    // Minimum log level, defaults to info
    public var minLogLevel: LogLevel = .info

    // Whether to include file name and line number, disabled by default (production environment)
    public var includeFileLocation: Bool = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private let logQueue = DispatchQueue(label: "com.webbridgekit.logger")

    // MARK: - Public Methods

    public func log(
        _ level: LogLevel,
        category: LogCategory = .general,
        message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled && level.rawValue >= minLogLevel.rawValue else { return }

        logQueue.async { [weak self] in
            guard let self = self else { return }

            var logMessage = "\(level.emoji) [\(category.rawValue)] \(message)"

            if self.includeFileLocation {
                let fileName = (file as NSString).lastPathComponent
                logMessage += " [\(fileName):\(line) \(function)]"
            }

            print(logMessage)

            // Also use os.log to record to system logs
            let osLogType: OSLogType
            switch level {
            case .debug: osLogType = .debug
            case .info: osLogType = .info
            case .warning: osLogType = .default
            case .error: osLogType = .error
            }

            let osLog = OSLog(subsystem: "com.webbridgekit", category: category.rawValue)
            os_log("%{public}@", log: osLog, type: osLogType, message)
        }
    }

    // Convenience methods
    public func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, category: category, message: message, file: file, function: function, line: line)
    }

    public func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, category: category, message: message, file: file, function: function, line: line)
    }

    public func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, category: category, message: message, file: file, function: function, line: line)
    }

    public func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, category: category, message: message, file: file, function: function, line: line)
    }

    // MARK: - Backward Compatible Methods

    public func log(_ level: LogLevel = .info, _ message: String) {
        guard isEnabled else { return }

        switch level {
        case .info:
            logger.info("\(message)")
        case .error:
            logger.error("\(message)")
        case .debug:
            logger.debug("\(message)")
        case .warning:
            logger.warning("\(message)")
        }
    }

    // MARK: - Specialized Log Methods

    /// 记录请求日志（创建并返回 Token）
    public func logRequest(action: String, params: [String: Any], module: String) -> WebBridgeLogToken {
        let token = WebBridgeLogToken(action: action, input: params, module: module)
        guard isEnabled else { return token }
        logger.info("📤 [\(module)] Request: \(action)")
        return token
    }

    /// 记录请求日志（使用已有 Token）
    public func logRequest(token: WebBridgeLogToken) {
        guard isEnabled else { return }
        logger.info("📤 [\(token.module)] Request: \(token.action)")
    }

    /// 记录响应日志
    public func logResponse(token: WebBridgeLogToken, result: Any?, error: Error?) {
        guard isEnabled else { return }
        if let error = error {
            logger.error("❌ [\(token.module)] Response Error: \(error.localizedDescription)")
        } else {
            logger.info("✅ [\(token.module)] Response Success")
        }
    }

    /// 记录事件日志
    public func logEvent(event: String, data: Any, module: String) {
        guard isEnabled else { return }
        logger.info("📡 [\(module)] Event: \(event)")
    }
}

// MARK: - Log Token

/// 日志 Token，用于关联请求和响应
public struct WebBridgeLogToken {
    public let action: String
    public let input: [String: Any]
    public let module: String
    public let timestamp = Date()
}

// MARK: - Global Convenience Access

/// Global convenience access to the logger
public let Log = WebBridgeLogger.shared
