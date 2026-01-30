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

    public enum LogLevel {
        case info
        case error
        case debug
        case warning
    }

    // MARK: - Public Methods

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

    public func info(_ message: String) {
        log(.info, message)
    }

    public func error(_ message: String) {
        log(.error, message)
    }

    public func debug(_ message: String) {
        log(.debug, message)
    }

    public func warning(_ message: String) {
        log(.warning, message)
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
