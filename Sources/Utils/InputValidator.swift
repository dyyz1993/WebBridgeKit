//
//  InputValidator.swift
//  WebBridgeKit
//
//  Created by Claude on 2026-02-10.
//  Copyright © 2026 WebBridgeKit. All rights reserved.
//

import Foundation
import CryptoKit

/// A utility enum providing static methods for validating various input types.
/// Used throughout WebBridgeKit to ensure data integrity and prevent security issues.
public enum InputValidator {

    // MARK: - HTML Name Validation

    /// Validates an HTML page name for security and format constraints.
    ///
    /// - Parameter name: The name to validate
    /// - Returns: The validated name (unchanged if valid)
    /// - Throws: `ValidationError` if validation fails
    ///
    /// # Validation Rules
    /// - Must not be empty
    /// - Maximum length of 255 characters
    /// - Must not contain path traversal characters ("..", "\\", ":")
    ///
    /// # Example
    /// ```swift
    /// do {
    ///     let validName = try InputValidator.validateHTMLName("index.html")
    ///     print(validName) // "index.html"
    /// } catch {
    ///     print("Invalid name: \(error)")
    /// }
    /// ```
    static func validateHTMLName(_ name: String) throws -> String {
        // Check if empty
        guard !name.isEmpty else {
            throw ValidationError.invalidInput("HTML name cannot be empty")
        }

        // Check maximum length
        guard name.count <= 255 else {
            throw ValidationError.invalidInput("HTML name exceeds maximum length of 255 characters")
        }

        // Define prohibited characters for path traversal prevention
        let prohibitedCharacters = CharacterSet(charactersIn: ".\\:")

        // Check for path traversal patterns
        if name.range(of: "..", options: .literal) != nil {
            throw ValidationError.invalidInput("HTML name cannot contain path traversal sequences (\"..\")")
        }

        // Check for prohibited individual characters
        if name.rangeOfCharacter(from: prohibitedCharacters) != nil {
            throw ValidationError.invalidInput("HTML name contains invalid characters (., \\, : are not allowed)")
        }

        return name
    }

    // MARK: - URL Scheme Validation

    /// Validates that a URL uses an allowed scheme.
    ///
    /// - Parameters:
    ///   - url: The URL to validate
    ///   - allowedSchemes: A set of allowed URL schemes (e.g., ["http", "https", "file"])
    /// - Throws: `ValidationError.invalidInput` if the URL scheme is not in the allowed set
    ///
    /// # Validation Rules
    /// - URL must have a valid scheme
    /// - Scheme must be in the provided allowed schemes set
    ///
    /// # Example
    /// ```swift
    /// let url = URL(string: "https://example.com")!
    /// let allowedSchemes: Set<String> = ["http", "https", "data"]
    ///
    /// do {
    ///     try InputValidator.validateURLScheme(url, allowedSchemes: allowedSchemes)
    ///     print("URL scheme is valid")
    /// } catch {
    ///     print("Invalid URL scheme: \(error)")
    /// }
    /// ```
    static func validateURLScheme(_ url: URL, allowedSchemes: Set<String>) throws {
        // Extract the scheme from the URL
        guard let scheme = url.scheme else {
            throw ValidationError.invalidInput("URL must have a valid scheme")
        }

        // Normalize scheme to lowercase for comparison
        let normalizedScheme = scheme.lowercased()

        // Check if the scheme is in the allowed set
        let normalizedAllowedSchemes = Set(allowedSchemes.map { $0.lowercased() })

        guard normalizedAllowedSchemes.contains(normalizedScheme) else {
            throw ValidationError.invalidInput(
                "URL scheme \"\(normalizedScheme)\" is not allowed. Allowed schemes: \(allowedSchemes.joined(separator: ", "))"
            )
        }
    }

    // MARK: - Manifest Resource Validation

    /// Validates manifest resources for security and correctness
    ///
    /// - Parameters:
    ///   - resources: Dictionary of resource paths to URLs
    ///   - allowDataScheme: Whether to allow data: URLs (default: true)
    /// - Throws: `ValidationError` if validation fails
    ///
    /// # Validation Rules
    /// - Resource paths must not contain path traversal sequences ("..")
    /// - Resource paths must be relative (not absolute)
    /// - Resource paths must not contain null bytes
    /// - Resource URLs must use allowed schemes (http, https, data)
    /// - Resource URLs must be valid
    ///
    /// # Example
    /// ```swift
    /// let resources = ["index.html": "https://example.com/index.html"]
    /// do {
    ///     try InputValidator.validateManifestResources(resources)
    ///     print("Resources are valid")
    /// } catch {
    ///     print("Invalid resources: \(error)")
    /// }
    /// ```
    static func validateManifestResources(
        _ resources: [String: String],
        allowDataScheme: Bool = true
    ) throws {
        var allowedSchemes: Set<String> = ["http", "https"]
        if allowDataScheme {
            allowedSchemes.insert("data")
        }

        for (path, urlString) in resources {
            // Validate resource path
            try validateResourcePath(path)

            // Validate URL
            guard let url = URL(string: urlString) else {
                throw ValidationError.invalidInput("Malformed URL for resource '\(path)': \(urlString)")
            }

            // Validate URL scheme
            try validateURLScheme(url, allowedSchemes: allowedSchemes)
        }
    }

    /// Validates a single resource path for security issues
    ///
    /// - Parameter path: The resource path to validate
    /// - Throws: `ValidationError` if the path is invalid or unsafe
    ///
    /// # Validation Rules
    /// - Must not be empty
    /// - Must not contain path traversal sequences ("..")
    /// - Must not be an absolute path (start with "/")
    /// - Must not contain null bytes
    /// - Must not exceed 255 characters
    ///
    /// # Example
    /// ```swift
    /// do {
    ///     try InputValidator.validateResourcePath("styles/main.css")
    ///     print("Path is valid")
    /// } catch {
    ///     print("Invalid path: \(error)")
    /// }
    /// ```
    static func validateResourcePath(_ path: String) throws {
        // Check for empty path
        guard !path.isEmpty else {
            throw ValidationError.invalidInput("Resource path cannot be empty")
        }

        // Check for path traversal attempts
        if path.contains("..") {
            throw ValidationError.invalidInput("Resource path cannot contain path traversal sequences (\"..\"): \(path)")
        }

        // Check for absolute paths
        if path.hasPrefix("/") {
            throw ValidationError.invalidInput("Resource path cannot be absolute: \(path)")
        }

        // Check for null bytes
        if path.contains("\0") {
            throw ValidationError.invalidInput("Resource path cannot contain null bytes: \(path)")
        }

        // Check for excessive length
        guard path.count <= 255 else {
            throw ValidationError.invalidInput("Resource path exceeds maximum length of 255 characters: \(path)")
        }
    }

    // MARK: - Manifest Version Validation

    /// Validates a manifest version string
    ///
    /// - Parameter version: The version string to validate
    /// - Returns: True if the version is valid and supported
    ///
    /// # Validation Rules
    /// - Version must follow semantic versioning format (x.y.z)
    /// - Version must be within supported range
    ///
    /// # Example
    /// ```swift
    /// let isValid = InputValidator.validateManifestVersion("1.0.0")
    /// print(isValid) // true
    /// ```
    static func validateManifestVersion(_ version: String) -> Bool {
        // Check if version is empty
        guard !version.isEmpty else {
            return false
        }

        // Check if version follows semantic versioning
        let versionPattern = #"^\d+\.\d+\.\d+$"#
        guard let regex = try? NSRegularExpression(pattern: versionPattern) else {
            return false
        }

        let range = NSRange(version.startIndex..., in: version)
        guard regex.firstMatch(in: version, range: range) != nil else {
            return false
        }

        // Check if version is supported
        return ManifestVersion.isSupported(version)
    }

    // MARK: - Resource Integrity Validation

    /// Validates resource integrity using a checksum
    ///
    /// - Parameters:
    ///   - data: The resource data to validate
    ///   - expectedChecksum: The expected checksum (e.g., SHA-256 hash)
    ///   - algorithm: The hash algorithm used (default: SHA-256)
    /// - Returns: True if the checksum matches
    ///
    /// # Example
    /// ```swift
    /// let data = Data("Hello, World!".utf8)
    /// let checksum = "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f"
    /// let isValid = InputValidator.validateResourceIntegrity(data: data, expectedChecksum: checksum)
    /// ```
    static func validateResourceIntegrity(
        data: Data,
        expectedChecksum: String,
        algorithm: HashAlgorithm = .sha256
    ) -> Bool {
        guard !expectedChecksum.isEmpty else {
            return false
        }

        let computedChecksum = algorithm.hash(data: data)
        return computedChecksum.lowercased() == expectedChecksum.lowercased()
    }

    /// Validates multiple resources and their integrity checksums
    ///
    /// - Parameters:
    ///   - resources: Dictionary of resource paths to (data, checksum) tuples
    ///   - algorithm: The hash algorithm used (default: SHA-256)
    /// - Returns: Dictionary of validation results (path -> isValid)
    /// - Throws: `ValidationError` if resource paths are invalid
    ///
    /// # Example
    /// ```swift
    /// let resources = [
    ///     "index.html": (data: htmlData, checksum: htmlChecksum),
    ///     "style.css": (data: cssData, checksum: cssChecksum)
    /// ]
    /// let results = try InputValidator.validateResourceIntegrity(resources: resources)
    /// ```
    static func validateResourceIntegrity(
        resources: [String: (data: Data, checksum: String)],
        algorithm: HashAlgorithm = .sha256
    ) throws -> [String: Bool] {
        var results: [String: Bool] = [:]

        for (path, resource) in resources {
            // Validate path
            try validateResourcePath(path)

            // Validate integrity
            let isValid = validateResourceIntegrity(
                data: resource.data,
                expectedChecksum: resource.checksum,
                algorithm: algorithm
            )

            results[path] = isValid
        }

        return results
    }
}

// MARK: - HashAlgorithm

/// Hash algorithms for resource integrity validation
public enum HashAlgorithm {
    case sha256
    case sha384
    case sha512
    case md5

    /// Compute hash of data
    func hash(data: Data) -> String {
        switch self {
        case .sha256:
            return data.sha256()
        case .sha384:
            return data.sha384()
        case .sha512:
            return data.sha512()
        case .md5:
            return data.md5()
        }
    }
}

// MARK: - Data Hashing Extensions

private extension Data {
    /// Compute SHA-256 hash using CryptoKit
    func sha256() -> String {
        let digest = SHA256.hash(data: self)
        return Data(digest).map { String(format: "%02x", $0) }.joined()
    }

    /// Compute SHA-384 hash using CryptoKit
    func sha384() -> String {
        let digest = SHA384.hash(data: self)
        return Data(digest).map { String(format: "%02x", $0) }.joined()
    }

    /// Compute SHA-512 hash using CryptoKit
    func sha512() -> String {
        let digest = SHA512.hash(data: self)
        return Data(digest).map { String(format: "%02x", $0) }.joined()
    }

    /// Compute MD5 hash using CryptoKit
    /// WARNING: MD5 is cryptographically broken and should only be used for legacy compatibility
    func md5() -> String {
        let digest = Insecure.MD5.hash(data: self)
        return Data(digest).map { String(format: "%02x", $0) }.joined()
    }
}


// MARK: - ValidationError

/// Simple validation error for input validation failures
public enum ValidationError: Error, LocalizedError {
    case invalidInput(String)

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        }
    }
}

// MARK: - Weak Script Message Handler

import WebKit

/// A weak wrapper for WKScriptMessageHandler to prevent memory leaks
///
/// WKUserContentController.add(_:name:) creates a strong reference to the handler.
/// This wrapper uses a weak reference to break the retain cycle and allow proper cleanup.
public final class WeakScriptMessageHandler: NSObject {

    // MARK: - Properties

    /// Weak reference to the actual message handler
    private weak var target: WKScriptMessageHandler?

    // MARK: - Initialization

    /// Initialize with a target handler (stored as weak reference)
    /// - Parameter target: The actual WKScriptMessageHandler implementation
    public init(target: WKScriptMessageHandler) {
        self.target = target
        super.init()
    }

    // MARK: - Public Methods

    /// Check if the target is still alive
    public var isTargetAlive: Bool {
        return target != nil
    }
}

// MARK: - WKScriptMessageHandler

extension WeakScriptMessageHandler: WKScriptMessageHandler {

    /// Forward script messages to the target if it's still alive
    /// - Parameters:
    ///   - userContentController: The user content controller
    ///   - message: The script message received
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Only forward if target is still alive
        target?.userContentController(userContentController, didReceive: message)
    }
}
