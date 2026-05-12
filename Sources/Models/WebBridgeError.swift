//
//  WebBridgeError.swift
//  WebBridgeKit
//
//  Created on 2026-02-10.
//

import Foundation

/// Unified error types for the WebBridgeKit framework.
/// Provides a comprehensive set of error cases that can occur during
/// web bridge operations, including network requests, caching, and database operations.
public enum WebBridgeError: Error, LocalizedError, CustomStringConvertible {

    /// Invalid user input provided to a WebBridge operation.
    /// - Parameter message: Description of the invalid input.
    case invalidInput(String)

    /// Network request failed during execution.
    /// - Parameter reason: Description of why the network request failed.
    case networkRequestFailed(reason: String)

    /// Cache loading operation failed.
    /// - Parameter reason: Description of why cache loading failed.
    case cacheLoadFailed(reason: String)

    /// Cache saving operation failed.
    /// - Parameter underlying: The underlying error that caused the save failure.
    case cacheSaveFailed(underlying: Error)

    /// Database operation failed.
    /// - Parameter underlying: The underlying error that caused the database operation to fail.
    case databaseOperationFailed(underlying: Error)

    /// Operation timed out.
    /// - Parameter operation: Description of the operation that timed out.
    case timeout(operation: String)

    /// Network is unavailable.
    /// - Parameter reason: Description of why network is unavailable.
    case networkUnavailable(reason: String)

    /// Browser open operation failed.
    /// - Parameter reason: Description of why browser opening failed.
    case browserOpenFailed(reason: String)

    // MARK: - LocalizedError Conformance

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"

        case .networkRequestFailed(let reason):
            return "Network request failed: \(reason)"

        case .cacheLoadFailed(let reason):
            return "Cache load failed: \(reason)"

        case .cacheSaveFailed(let underlying):
            return "Cache save failed: \(underlying.localizedDescription)"

        case .databaseOperationFailed(let underlying):
            return "Database operation failed: \(underlying.localizedDescription)"

        case .timeout(let operation):
            return "Operation timed out: \(operation)"

        case .networkUnavailable(let reason):
            return "Network unavailable: \(reason)"

        case .browserOpenFailed(let reason):
            return "Browser open failed: \(reason)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .invalidInput(let message):
            return message

        case .networkRequestFailed(let reason):
            return reason

        case .cacheLoadFailed(let reason):
            return reason

        case .cacheSaveFailed(let underlying):
            return underlying.localizedDescription

        case .databaseOperationFailed(let underlying):
            return underlying.localizedDescription

        case .timeout(let operation):
            return "The operation '\(operation)' took longer than the allowed time limit."

        case .networkUnavailable(let reason):
            return reason

        case .browserOpenFailed(let reason):
            return reason
        }
    }

    // MARK: - CustomStringConvertible Conformance

    public var description: String {
        return errorDescription ?? "Unknown WebBridge error"
    }
}

// MARK: - Error Wrapping

extension WebBridgeError {

    /// Wraps an async throwing closure, re-throwing WebBridgeError as-is
    /// and wrapping other errors as `.databaseOperationFailed`.
    ///
    /// Usage:
    /// ```swift
    /// return try await WebBridgeError.wrap {
    ///     try await databaseActor.getAll()
    /// }
    /// ```
    public static func wrap<T>(_ block: () async throws -> T) async throws -> T {
        do {
            return try await block()
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw Self.databaseOperationFailed(underlying: error)
        }
    }

    /// Synchronous version for non-async contexts
    public static func wrapSync<T>(_ block: () throws -> T) throws -> T {
        do {
            return try block()
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw Self.databaseOperationFailed(underlying: error)
        }
    }
}
