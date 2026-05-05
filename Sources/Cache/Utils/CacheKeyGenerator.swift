import Foundation
import CommonCrypto

/// Cache key generation utilities
public enum CacheKeyGenerator {
    /// Generate cache key from components
    /// - Parameter components: Components to combine
    /// - Returns: MD5 hash of combined components
    public static func generate(from components: String...) -> String {
        let combined = components.joined(separator: ":")
        return md5(combined)
    }

    /// Generate cache key from array of components
    /// - Parameter components: Array of components to combine
    /// - Returns: MD5 hash of combined components
    public static func generate(from components: [String]) -> String {
        let combined = components.joined(separator: ":")
        return md5(combined)
    }

    /// Generate cache key from dictionary
    /// - Parameter dictionary: Dictionary to hash
    /// - Returns: MD5 hash of dictionary JSON representation
    public static func generate(from dictionary: [String: String]) -> String {
        let sorted = dictionary.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        return md5(sorted)
    }

    /// Generate cache key from URL
    /// - Parameter url: URL to cache
    /// - Returns: Cache key for URL
    public static func generate(from url: URL) -> String {
        generate(from: url.absoluteString)
    }

    /// Generate cache key from request
    /// - Parameters:
    ///   - url: Request URL
    ///   - method: HTTP method
    ///   - body: Request body (optional)
    /// - Returns: Cache key for request
    public static func generate(from url: URL, method: String, body: Data? = nil) -> String {
        var components = [url.absoluteString, method]
        if let body = body {
            components.append(body.base64EncodedString())
        }
        return generate(from: components)
    }

    /// Generate hierarchical cache key
    /// - Parameters:
    ///   - namespace: Namespace for grouping related cache entries
    ///   - identifier: Unique identifier
    /// - Returns: Namespaced cache key
    public static func generate(namespace: String, identifier: String) -> String {
        "\(namespace)/\(identifier)"
    }

    /// Generate versioned cache key
    /// - Parameters:
    ///   - key: Base cache key
    ///   - version: Version number
    /// - Returns: Versioned cache key
    public static func generate(key: String, version: Int) -> String {
        "\(key):v\(version)"
    }

    // MARK: - Private Methods

    private static func md5(_ string: String) -> String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)

        if let data = string.data(using: .utf8) {
            _ = data.withUnsafeBytes { (body: UnsafeRawBufferPointer) in
                CC_MD5(body.baseAddress, CC_LONG(data.count), &digest)
            }
        }

        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Predefined cache key namespaces
public enum CacheNamespace {
    public static let api = "api"
    public static let image = "image"
    public static let manifest = "manifest"
    public static let bridge = "bridge"
    public static let user = "user"
    public static let settings = "settings"

    public static func forKey(_ key: String) -> String {
        CacheKeyGenerator.generate(namespace: self.bridge, identifier: key)
    }
}
