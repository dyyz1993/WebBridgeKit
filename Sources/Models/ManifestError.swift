//
//  ManifestError.swift
//  WebBridgeKit
//
//  Created by Claude on 2026-02-10.
//  Copyright © 2026 WebBridgeKit. All rights reserved.
//

import Foundation

// MARK: - ManifestError

/// Detailed error types for Manifest parsing and validation
/// These errors provide specific information about what went wrong during manifest processing
public enum ManifestError: Error, LocalizedError, CustomStringConvertible {

    // MARK: - Error Cases

    /// Invalid manifest format (e.g., malformed JSON, wrong structure)
    case invalidFormat(String)

    /// Missing required field in manifest
    case missingRequiredField(String)

    /// Unsupported manifest version
    case unsupportedVersion(String)

    /// Invalid or unsafe resource path (potential path traversal)
    case invalidResourcePath(String)

    /// Invalid resource type
    case invalidResourceType(String)

    /// Corrupted or incomplete data
    case corruptedData

    // MARK: - LocalizedError

    public var errorDescription: String? {
        return description
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .invalidFormat(let details):
            return "Invalid manifest format: \(details)"

        case .missingRequiredField(let field):
            return "Missing required field: \(field)"

        case .unsupportedVersion(let version):
            return "Unsupported manifest version: \(version)"

        case .invalidResourcePath(let path):
            return "Invalid or unsafe resource path: \(path)"

        case .invalidResourceType(let type):
            return "Invalid resource type: \(type)"

        case .corruptedData:
            return "Manifest data is corrupted or incomplete"
        }
    }

    // MARK: - Recovery Suggestions

    public var recoverySuggestion: String? {
        switch self {
        case .invalidFormat:
            return "Ensure the manifest JSON is properly formatted and follows the expected structure"

        case .missingRequiredField(let field):
            return "Add the required '\(field)' field to the manifest"

        case .unsupportedVersion(let version):
            return "Update the manifest to a supported version, or update the app to support version \(version)"

        case .invalidResourcePath(let path):
            return "Remove any path traversal sequences (../) or special characters from the resource path: \(path)"

        case .invalidResourceType(let type):
            return "Use a valid resource type (image, stylesheet, script, font, document, audio, video, data, other) instead of: \(type)"

        case .corruptedData:
            return "Re-download the manifest to ensure data integrity"
        }
    }

    // MARK: - Failure Reason

    public var failureReason: String? {
        switch self {
        case .invalidFormat:
            return "The manifest structure does not match the expected format"

        case .missingRequiredField:
            return "A required field is missing from the manifest"

        case .unsupportedVersion:
            return "The manifest version is not supported by this version of WebBridgeKit"

        case .invalidResourcePath:
            return "A resource path contains unsafe characters or path traversal sequences"

        case .invalidResourceType:
            return "A resource type is not recognized"

        case .corruptedData:
            return "The manifest data could not be parsed due to corruption"
        }
    }

    // MARK: - Convenience Factory Methods

    /// Create an error for path traversal attempts
    static func pathTraversalDetected(in path: String) -> ManifestError {
        return .invalidResourcePath("Path traversal detected in: \(path)")
    }

    /// Create an error for missing resources
    static func missingResource(at path: String) -> ManifestError {
        return .invalidResourcePath("Missing required resource at: \(path)")
    }

    /// Create an error for version incompatibility
    static func versionIncompatibility(current: String, required: String) -> ManifestError {
        return .unsupportedVersion("Current: \(current), Required: \(required)")
    }
}

// MARK: - ManifestValidationResult

/// Result of manifest validation
public struct ManifestValidationResult {

    /// Whether validation passed
    public let isValid: Bool

    /// Validation errors (if any)
    public let errors: [ManifestError]

    /// Validation warnings (non-critical issues)
    public let warnings: [String]

    /// Create a successful validation result
    public static func valid() -> ManifestValidationResult {
        return ManifestValidationResult(isValid: true, errors: [], warnings: [])
    }

    /// Create a failed validation result with errors
    public static func invalid(_ errors: [ManifestError], warnings: [String] = []) -> ManifestValidationResult {
        return ManifestValidationResult(isValid: false, errors: errors, warnings: warnings)
    }

    /// Create a validation result with warnings only
    public static func validWithWarnings(_ warnings: [String]) -> ManifestValidationResult {
        return ManifestValidationResult(isValid: true, errors: [], warnings: warnings)
    }
}

// MARK: - ManifestVersion

/// Manifest version compatibility utilities
public enum ManifestVersion {

    /// Minimum supported manifest version
    public static let minimumSupported = "1.0.0"

    /// Maximum supported manifest version
    public static let maximumSupported = "2.0.0"

    /// Current manifest version format
    public static let currentFormat = "2.0"

    /// Check if a version is supported
    /// - Parameter version: Version string to check
    /// - Returns: True if the version is supported
    public static func isSupported(_ version: String) -> Bool {
        return compareVersions(version, minimumSupported) != .orderedAscending &&
               compareVersions(version, maximumSupported) != .orderedDescending
    }

    /// Compare two version strings
    /// - Parameters:
    ///   - version1: First version string
    ///   - version2: Second version string
    /// - Returns: Comparison result
    private static func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(v1Components.count, v2Components.count)

        for i in 0..<maxLength {
            let v1 = i < v1Components.count ? v1Components[i] : 0
            let v2 = i < v2Components.count ? v2Components[i] : 0

            if v1 < v2 {
                return .orderedAscending
            } else if v1 > v2 {
                return .orderedDescending
            }
        }

        return .orderedSame
    }
}
