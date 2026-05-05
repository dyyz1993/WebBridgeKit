//
//  LogCompatibility.swift
//  WebBridgeKit
//
//  Backward-compatible wrapper that redirects WebBridgeLogger API to StructuredLogger.
//  Existing code using WebBridgeLogger.shared / Log continues to work without changes.
//

import Foundation

// MARK: - Type Conversion (file-private, outside extension to avoid shadowing)

private func _convertLevel(_ old: WebBridgeLogger.LogLevel) -> LogLevel {
    switch old {
    case .debug:   return .debug
    case .info:    return .info
    case .warning: return .warning
    case .error:   return .error
    }
}

private func _convertCategory(_ old: WebBridgeLogger.LogCategory) -> LogCategory {
    switch old {
    case .general:     return .general
    case .cache:       return .cache
    case .network:     return .network
    case .browser:     return .bridge
    case .manifest:    return .storage
    case .realm:       return .storage
    case .ui:          return .ui
    case .performance: return .performance
    }
}

// MARK: - LegacyLogAdapter

/// Thin adapter that exposes the old WebBridgeLogger API shape but forwards
/// all calls to `StructuredLogger.shared`.
///
/// Usage (opt-in, gradual migration):
///   ```swift
///   // Before
///   Log.info("hello", category: .general)
///
///   // After — just switch the global
///   Log.useStructuredLogger = true   // now goes through StructuredLogger
///   Log.info("hello", category: .general)  // same call-site, new backend
///   ```
///
/// The adapter lives as an extension on `WebBridgeLogger` so that existing
/// call-sites (`Log.info(...)`, `WebBridgeLogger.shared.debug(...)`) keep
/// compiling unchanged.
extension WebBridgeLogger {

    // MARK: - Bridge Flag

    private static var _bridgeEnabled: Bool = false

    /// When `true`, the bridge convenience methods forward to StructuredLogger.
    /// When `false` (default), they fall through to the original implementation.
    public var useStructuredLogger: Bool {
        get { Self._bridgeEnabled }
        set { Self._bridgeEnabled = newValue }
    }

    // MARK: - Enable / Disable

    public static func enableStructuredBridge() {
        _bridgeEnabled = true
    }

    public static func disableStructuredBridge() {
        _bridgeEnabled = false
    }

    // MARK: - Bridged Convenience Methods

    public func bridgedInfo(_ message: String, category: WebBridgeLogger.LogCategory = .general,
                            file: String = #file, function: String = #function, line: Int = #line) {
        guard useStructuredLogger else {
            info(message, category: category, file: file, function: function, line: line)
            return
        }
        StructuredLogger.shared.info(message, category: _convertCategory(category),
                                     file: file, function: function, line: line)
    }

    public func bridgedDebug(_ message: String, category: WebBridgeLogger.LogCategory = .general,
                             file: String = #file, function: String = #function, line: Int = #line) {
        guard useStructuredLogger else {
            debug(message, category: category, file: file, function: function, line: line)
            return
        }
        StructuredLogger.shared.debug(message, category: _convertCategory(category),
                                      file: file, function: function, line: line)
    }

    public func bridgedWarning(_ message: String, category: WebBridgeLogger.LogCategory = .general,
                               file: String = #file, function: String = #function, line: Int = #line) {
        guard useStructuredLogger else {
            warning(message, category: category, file: file, function: function, line: line)
            return
        }
        StructuredLogger.shared.warning(message, category: _convertCategory(category),
                                        file: file, function: function, line: line)
    }

    public func bridgedError(_ message: String, category: WebBridgeLogger.LogCategory = .general,
                             file: String = #file, function: String = #function, line: Int = #line) {
        guard useStructuredLogger else {
            error(message, category: category, file: file, function: function, line: line)
            return
        }
        StructuredLogger.shared.error(message, category: _convertCategory(category),
                                      file: file, function: function, line: line)
    }

    public func bridgedLog(_ level: WebBridgeLogger.LogLevel,
                           category: WebBridgeLogger.LogCategory = .general,
                           message: String,
                           file: String = #file, function: String = #function, line: Int = #line) {
        guard useStructuredLogger else {
            log(level, category: category, message: message, file: file, function: function, line: line)
            return
        }
        let mapped = _convertLevel(level)
        let cat = _convertCategory(category)
        switch mapped {
        case .verbose: StructuredLogger.shared.verbose(message, category: cat, file: file, function: function, line: line)
        case .debug:   StructuredLogger.shared.debug(message, category: cat, file: file, function: function, line: line)
        case .info:    StructuredLogger.shared.info(message, category: cat, file: file, function: function, line: line)
        case .warning: StructuredLogger.shared.warning(message, category: cat, file: file, function: function, line: line)
        case .error:   StructuredLogger.shared.error(message, category: cat, file: file, function: function, line: line)
        }
    }

    // MARK: - Request / Response / Event Bridges

    public func bridgedLogRequest(action: String, params: [String: Any], module: String) -> WebBridgeLogToken {
        let token = logRequest(action: action, params: params, module: module)
        guard useStructuredLogger else { return token }
        StructuredLogger.shared.info("Request: \(action)", category: .handler,
                                     action: action, context: params.mapValues { String(describing: $0) })
        return token
    }

    public func bridgedLogResponse(token: WebBridgeLogToken, result: Any?, error: Error?) {
        logResponse(token: token, result: result, error: error)
        guard useStructuredLogger else { return }
        if let error = error {
            StructuredLogger.shared.error("Response Error: \(error.localizedDescription)",
                                          category: .handler, action: token.action)
        } else {
            StructuredLogger.shared.info("Response Success", category: .handler, action: token.action)
        }
    }

    public func bridgedLogEvent(event: String, data: Any, module: String) {
        logEvent(event: event, data: data, module: module)
        guard useStructuredLogger else { return }
        StructuredLogger.shared.info("Event: \(event)", category: .bridge,
                                     action: event, context: ["module": module])
    }
}
