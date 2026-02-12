//
//  RequestDeduplicator.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-10.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// Request deduplication utility to prevent duplicate network requests
/// Uses Task-based pattern with thread-safe operations
public class RequestDeduplicator {

    // MARK: - Singleton

    public static let shared = RequestDeduplicator()

    // MARK: - Properties

    /// Pending requests tracked by key (URL or pageName)
    private var pendingTasks: [String: Task<Any, Error>] = [:]

    /// Thread safety lock
    private let lock = NSLock()

    /// Maximum age for pending tasks (seconds)
    private let maxTaskAge: TimeInterval = 30.0

    /// Task creation timestamps for cleanup
    private var taskTimestamps: [String: Date] = [:]

    // MARK: - Initialization

    private init() {
        // Start periodic cleanup task
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(maxTaskAge * 1_000_000_000))
                cleanupStaleTasks()
            }
        }

        NSLog("✅ [RequestDeduplicator] Initialized")
    }

    // MARK: - Public Methods

    /// Execute a request with deduplication
    /// - Parameters:
    ///   - key: Unique identifier for the request (URL or pageName)
    ///   - priority: Task priority (default: .userInitiated)
    ///   - operation: The async operation to perform
    /// - Returns: The result of the operation
    /// - Throws: The error from the operation
    public func execute<T: Any>(
        key: String,
        priority: TaskPriority = .userInitiated,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        // Check if a task with this key is already running
        lock.lock()
        if let existingTask = pendingTasks[key] {
            lock.unlock()

            NSLog( "♻️ [RequestDeduplicator] Reusing existing task for key: \(key)")

            do {
                // Wait for the existing task to complete
                let result = try await existingTask.value

                // Attempt to cast to the expected type
                guard let typedResult = result as? T else {
                    throw WebBridgeError.cacheLoadFailed(
                        reason: "Type mismatch in deduplicated request for key: \(key)"
                    )
                }

                return typedResult
            } catch {
                // If the existing task fails, we might want to retry
                // For now, we'll propagate the error
                throw error
            }
        }

        // No existing task, create a new one
        NSLog( "🚀 [RequestDeduplicator] Creating new task for key: \(key)")

        let task = Task(priority: priority) {
            return try await operation() as Any
        }

        // Store the task
        pendingTasks[key] = task
        taskTimestamps[key] = Date()
        lock.unlock()

        // Wait for the task to complete
        do {
            let result = try await task.value

            // Clean up on success
            cleanup(key: key)

            guard let typedResult = result as? T else {
                throw WebBridgeError.cacheLoadFailed(
                    reason: "Type mismatch in deduplicated request result for key: \(key)"
                )
            }

            return typedResult
        } catch {
            // Clean up on error
            cleanup(key: key)
            throw error
        }
    }

    /// Check if a request with the given key is pending
    /// - Parameter key: Unique identifier for the request
    /// - Returns: True if a request is pending
    public func isPending(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingTasks[key] != nil
    }

    /// Cancel a pending request
    /// - Parameter key: Unique identifier for the request
    public func cancel(key: String) {
        lock.lock()
        defer { lock.unlock() }

        if let task = pendingTasks[key] {
            task.cancel()
            pendingTasks.removeValue(forKey: key)
            taskTimestamps.removeValue(forKey: key)
            NSLog( "🚫 [RequestDeduplicator] Cancelled task for key: \(key)")
        }
    }

    /// Cancel all pending requests
    public func cancelAll() {
        lock.lock()
        defer { lock.unlock() }

        let count = pendingTasks.count
        for (_, task) in pendingTasks {
            task.cancel()
        }

        pendingTasks.removeAll()
        taskTimestamps.removeAll()

        NSLog( "🚫 [RequestDeduplicator] Cancelled all \(count) pending tasks")
    }

    /// Get statistics about pending requests
    /// - Returns: Dictionary with stats
    public func getStats() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        return [
            "pendingCount": pendingTasks.count,
            "keys": Array(pendingTasks.keys)
        ]
    }

    // MARK: - Private Methods

    /// Clean up a completed task
    /// - Parameter key: Unique identifier for the request
    private func cleanup(key: String) {
        lock.lock()
        defer { lock.unlock() }

        pendingTasks.removeValue(forKey: key)
        taskTimestamps.removeValue(forKey: key)
    }

    /// Clean up stale tasks that have exceeded the maximum age
    private func cleanupStaleTasks() {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        let staleThreshold = now.addingTimeInterval(-maxTaskAge)

        var staleKeys: [String] = []

        for (key, timestamp) in taskTimestamps {
            if timestamp < staleThreshold {
                staleKeys.append(key)
            }
        }

        for key in staleKeys {
            if let task = pendingTasks[key] {
                task.cancel()
            }
            pendingTasks.removeValue(forKey: key)
            taskTimestamps.removeValue(forKey: key)
        }

        if !staleKeys.isEmpty {
            NSLog("🧹 [RequestDeduplicator] Cleaned up \(staleKeys.count) stale tasks")
        }
    }
}

// MARK: - Convenience Extensions

extension RequestDeduplicator {

    /// Execute a page preload request with deduplication
    /// - Parameters:
    ///   - pageName: Page name to preload
    ///   - operation: The async preload operation
    /// - Returns: Boolean indicating success
    public func executePagePreload(
        pageName: String,
        operation: @escaping () async throws -> Bool
    ) async throws -> Bool {
        let key = "page:\(pageName)"
        return try await execute(key: key, priority: .userInitiated, operation: operation)
    }

    /// Execute a resource download request with deduplication
    /// - Parameters:
    ///   - urlString: URL to download
    ///   - relativePath: Relative path for logging
    ///   - operation: The async download operation
    /// - Returns: ResourceData result
    public func executeResourceDownload(
        urlString: String,
        relativePath: String,
        operation: @escaping () async throws -> Any
    ) async throws -> Any {
        let key = "resource:\(urlString)"
        return try await execute(key: key, priority: .utility, operation: operation)
    }
}
