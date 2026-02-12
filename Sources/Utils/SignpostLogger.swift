//
//  SignpostLogger.swift
//  WebBridgeKit
//
//  Signpost logging for Instruments integration
//

import Foundation
import os.signpost

/// Logger for os_signpost integration with Instruments
@available(macOS 10.14, iOS 12.0, *)
public final class SignpostLogger {

    // MARK: - Types

    public enum Category: String {
        case networking = "Networking"
        case cache = "Cache"
        case database = "Database"
        case javascript = "JavaScript"
        case rendering = "Rendering"
        case performance = "Performance"
    }

    // MARK: - Properties

    public static let shared = SignpostLogger()

    private var loggers: [Category: OSLog] = [:]
    private var isEnabledValue: Bool = true
    private let lock = NSLock()

    // MARK: - Configuration

    /// Enable or disable signpost logging
    public var isEnabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return isEnabledValue
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            isEnabledValue = newValue
        }
    }

    // MARK: - Initialization

    private init() {
        setupLoggers()
    }

    private func setupLoggers() {
        for category in Category.allCases {
            loggers[category] = OSLog(subsystem: "com.webbridgekit", category: category.rawValue)
        }
    }

    // MARK: - Public Methods - Interval

    /// Begin a signpost interval
    /// - Parameters:
    ///   - name: Name of the interval
    ///   - category: Category of the interval
    public func beginInterval(
        _ name: StaticString,
        category: Category = .performance
    ) {
        guard isEnabled, let logger = loggers[category] else { return }
        let signpostID = OSSignpostID(log: logger)
        os_signpost(.begin, log: logger, name: name, signpostID: signpostID)
    }

    /// End a signpost interval
    /// - Parameters:
    ///   - name: Name of the interval
    ///   - category: Category of the interval
    public func endInterval(
        _ name: StaticString,
        category: Category = .performance
    ) {
        guard isEnabled, let logger = loggers[category] else { return }
        let signpostID = OSSignpostID(log: logger)
        os_signpost(.end, log: logger, name: name, signpostID: signpostID)
    }

    // MARK: - Public Methods - Event

    /// Log a signpost event
    /// - Parameters:
    ///   - name: Name of the event
    ///   - category: Category of the event
    public func logEvent(
        _ name: StaticString,
        category: Category = .performance
    ) {
        guard isEnabled, let logger = loggers[category] else { return }
        os_signpost(.event, log: logger, name: name)
    }
}

// MARK: - Category Extensions

@available(macOS 10.14, iOS 12.0, *)
extension SignpostLogger.Category {
    static var allCases: [SignpostLogger.Category] {
        return [.networking, .cache, .database, .javascript, .rendering, .performance]
    }
}
