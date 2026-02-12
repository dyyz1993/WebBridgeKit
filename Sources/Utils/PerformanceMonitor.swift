//
//  PerformanceMonitor.swift
//  WebBridgeKit
//
//  Created by Claude
//  Performance monitoring utility for tracking operation durations and identifying bottlenecks
//

import Foundation

/// Performance monitor for tracking operation durations and statistics
public final class PerformanceMonitor {

    // MARK: - Types

    /// Metric record for a single operation
    public struct Metric {
        let operation: String
        let duration: TimeInterval
        let timestamp: Date
        let metadata: [String: Any]?

        init(operation: String, duration: TimeInterval, timestamp: Date = Date(), metadata: [String: Any]? = nil) {
            self.operation = operation
            self.duration = duration
            self.timestamp = timestamp
            self.metadata = metadata
        }
    }

    /// Statistics for an operation
    public struct Statistics {
        let operation: String
        let count: Int
        let average: TimeInterval
        let min: TimeInterval
        let max: TimeInterval
        let total: TimeInterval
        let lastUpdate: Date

        var averageMs: Double { average * 1000 }
        var minMs: Double { min * 1000 }
        var maxMs: Double { max * 1000 }
        var totalMs: Double { total * 1000 }
    }

    // MARK: - Properties

    public static let shared = PerformanceMonitor()

    private var metrics: [String: [Metric]] = [:]
    private let queue = DispatchQueue(label: "com.webbridgekit.performancemonitor", attributes: .concurrent)
    private let cleanupThreshold: TimeInterval = 3600 // 1 hour

    private var isEnabledValue: Bool = true
    private let lock = NSLock()
    private var slowOperationThreshold: TimeInterval = 1.0 // 1 second

    // MARK: - Configuration

    /// Enable or disable performance monitoring
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

    /// Threshold for logging slow operations (in seconds)
    public var slowThreshold: TimeInterval {
        get { slowOperationThreshold }
        set { slowOperationThreshold = max(0.1, newValue) }
    }

    // MARK: - Initialization

    private init() {
        startCleanupTimer()
    }

    // MARK: - Public Methods - Synchronous

    /// Measure a synchronous operation
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - metadata: Optional metadata dictionary
    ///   - block: The operation to measure
    /// - Returns: The result of the operation
    public func measure<T>(
        _ operation: String,
        metadata: [String: Any]? = nil,
        block: () throws -> T
    ) rethrows -> T {
        guard isEnabled else {
            return try block()
        }

        let start = Date()
        let result = try block()
        let duration = Date().timeIntervalSince(start)

        recordMetric(operation: operation, duration: duration, metadata: metadata)

        if duration > slowOperationThreshold {
            logSlowOperation(operation: operation, duration: duration, metadata: metadata)
        }

        return result
    }

    /// Measure a synchronous operation with error handling
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - metadata: Optional metadata dictionary
    ///   - block: The operation to measure
    /// - Returns: The result of the operation
    public func measure<T>(
        _ operation: String,
        metadata: [String: Any]? = nil,
        block: () -> T
    ) -> T {
        guard isEnabled else {
            return block()
        }

        let start = Date()
        let result = block()
        let duration = Date().timeIntervalSince(start)

        recordMetric(operation: operation, duration: duration, metadata: metadata)

        if duration > slowOperationThreshold {
            logSlowOperation(operation: operation, duration: duration, metadata: metadata)
        }

        return result
    }

    // MARK: - Public Methods - Asynchronous

    /// Measure an asynchronous operation
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - metadata: Optional metadata dictionary
    ///   - block: The async operation to measure
    /// - Returns: The result of the operation
    public func measure<T>(
        _ operation: String,
        metadata: [String: Any]? = nil,
        block: () async throws -> T
    ) async rethrows -> T {
        guard isEnabled else {
            return try await block()
        }

        let start = Date()
        let result = try await block()
        let duration = Date().timeIntervalSince(start)

        recordMetric(operation: operation, duration: duration, metadata: metadata)

        if duration > slowOperationThreshold {
            logSlowOperation(operation: operation, duration: duration, metadata: metadata)
        }

        return result
    }

    // MARK: - Public Methods - Statistics

    /// Get statistics for a specific operation
    /// - Parameter operation: Name of the operation
    /// - Returns: Statistics if available
    public func getStatistics(for operation: String) -> Statistics? {
        queue.sync {
            guard let operationMetrics = metrics[operation], !operationMetrics.isEmpty else {
                return nil
            }

            let count = operationMetrics.count
            let total = operationMetrics.reduce(0) { $0 + $1.duration }
            let average = total / Double(count)
            let min = operationMetrics.map { $0.duration }.min() ?? 0
            let max = operationMetrics.map { $0.duration }.max() ?? 0
            let lastUpdate = operationMetrics.map { $0.timestamp }.max() ?? Date()

            return Statistics(
                operation: operation,
                count: count,
                average: average,
                min: min,
                max: max,
                total: total,
                lastUpdate: lastUpdate
            )
        }
    }

    /// Get all statistics
    /// - Returns: Dictionary of operation names to statistics
    public func getAllStatistics() -> [String: Statistics] {
        queue.sync {
            var result: [String: Statistics] = [:]

            for (operation, operationMetrics) in metrics {
                guard !operationMetrics.isEmpty else { continue }

                let count = operationMetrics.count
                let total = operationMetrics.reduce(0) { $0 + $1.duration }
                let average = total / Double(count)
                let min = operationMetrics.map { $0.duration }.min() ?? 0
                let max = operationMetrics.map { $0.duration }.max() ?? 0
                let lastUpdate = operationMetrics.map { $0.timestamp }.max() ?? Date()

                result[operation] = Statistics(
                    operation: operation,
                    count: count,
                    average: average,
                    min: min,
                    max: max,
                    total: total,
                    lastUpdate: lastUpdate
                )
            }

            return result
        }
    }

    /// Get all metric records for a specific operation
    /// - Parameter operation: Name of the operation
    /// - Returns: Array of metrics
    public func getMetrics(for operation: String) -> [Metric] {
        queue.sync {
            metrics[operation] ?? []
        }
    }

    // MARK: - Public Methods - Management

    /// Clear all metrics for a specific operation
    /// - Parameter operation: Name of the operation
    public func clearMetrics(for operation: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.metrics.removeValue(forKey: operation)
        }
    }

    /// Clear all metrics
    public func clearAllMetrics() {
        queue.async(flags: .barrier) { [weak self] in
            self?.metrics.removeAll()
        }
    }

    /// Export metrics as JSON string
    /// - Returns: JSON string representation of all metrics
    public func exportMetricsAsJSON() -> String {
        let stats = getAllStatistics()
        var result: [String: [String: Any]] = [:]

        for (operation, stat) in stats {
            result[operation] = [
                "count": stat.count,
                "average_ms": stat.averageMs,
                "min_ms": stat.minMs,
                "max_ms": stat.maxMs,
                "total_ms": stat.totalMs,
                "last_update": ISO8601DateFormatter().string(from: stat.lastUpdate)
            ]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return string
    }

    // MARK: - Private Methods

    private func recordMetric(operation: String, duration: TimeInterval, metadata: [String: Any]?) {
        queue.async(flags: .barrier) {
            let metric = Metric(operation: operation, duration: duration, metadata: metadata)

            if self.metrics[operation] == nil {
                self.metrics[operation] = []
            }

            self.metrics[operation]?.append(metric)
        }
    }

    private func logSlowOperation(operation: String, duration: TimeInterval, metadata: [String: Any]?) {
        var message = "⚠️ SLOW OPERATION: \(operation) took \(String(format: "%.2f", duration))s"

        if let metadata = metadata {
            let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            message += " [\(metadataString)]"
        }

        WebBridgeLogger.shared.log(.warning, category: .performance, message: message)
    }

    private func startCleanupTimer() {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + cleanupThreshold) { [weak self] in
            self?.cleanupOldMetrics()
            self?.startCleanupTimer()
        }
    }

    private func cleanupOldMetrics() {
        let threshold = Date().addingTimeInterval(-cleanupThreshold)

        queue.async(flags: .barrier) {
            for operation in self.metrics.keys {
                self.metrics[operation]?.removeAll { $0.timestamp < threshold }
            }

            // Remove empty operation entries
            self.metrics = self.metrics.filter { !$0.value.isEmpty }
        }
    }
}

// MARK: - Atomic Helper

private class Atomic<T> {
    private let queue = DispatchQueue(label: "com.webbridgekit.atomic")
    private var storage: T

    init(value: T) {
        self.storage = value
    }

    var value: T {
        get { queue.sync { storage } }
        set { queue.sync { storage = newValue } }
    }
}

// MARK: - Convenience Extensions

public extension PerformanceMonitor {

    /// Measure a URL session request
    func measureURLRequest<T>(
        _ operation: String,
        request: URLRequest,
        metadata: [String: Any]? = nil,
        block: (URLRequest) async throws -> T
    ) async rethrows -> T {
        var requestMetadata = metadata ?? [:]
        requestMetadata["url"] = request.url?.absoluteString ?? "unknown"
        requestMetadata["method"] = request.httpMethod ?? "GET"

        return try await measure(operation, metadata: requestMetadata, block: {
            try await block(request)
        })
    }

    /// Measure a database operation
    func measureDatabaseOperation<T>(
        _ operation: String,
        tableName: String? = nil,
        block: () throws -> T
    ) rethrows -> T {
        var metadata: [String: Any] = [:]
        if let tableName = tableName {
            metadata["table"] = tableName
        }

        return try measure(operation, metadata: metadata, block: block)
    }

    /// Measure a file I/O operation
    func measureFileOperation<T>(
        _ operation: String,
        filePath: String,
        block: () throws -> T
    ) rethrows -> T {
        return try measure(operation, metadata: ["path": filePath], block: block)
    }
}
