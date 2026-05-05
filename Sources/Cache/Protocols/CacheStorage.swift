import Foundation

/// Type-erased cache storage protocol for implementations that handle any Codable & Sendable type
public protocol AnyCacheStorage: AnyObject, Sendable {
    /// Associated type for cache keys
    associatedtype Key: Hashable & Sendable
    
    /// Retrieve cached value for the given key
    /// - Parameter key: Cache key
    /// - Returns: Cached value if exists and not expired, nil otherwise
    func get(for key: Key) async -> (any Codable & Sendable)?
    
    /// Store value with optional expiration
    /// - Parameters:
    ///   - value: Value to cache
    ///   - key: Cache key
    ///   - expiration: Optional expiration time interval (seconds)
    func set(_ value: any Codable & Sendable, for key: Key, expiration: TimeInterval?) async
    
    /// Remove cached value for the given key
    /// - Parameter key: Cache key
    func remove(for key: Key) async
    
    /// Clear all cached values
    func clearAll() async
    
    /// Check if cache contains value for the given key
    /// - Parameter key: Cache key
    /// - Returns: True if key exists and not expired, false otherwise
    func contains(_ key: Key) async -> Bool
}

/// Generic cache storage protocol defining basic cache operations
public protocol CacheStorage: AnyObject, Sendable {
    /// Associated type for cache keys
    associatedtype Key: Hashable & Sendable
    /// Associated type for cache values
    associatedtype Value: Codable & Sendable
    
    /// Retrieve cached value for the given key
    /// - Parameter key: Cache key
    /// - Returns: Cached value if exists and not expired, nil otherwise
    func get(for key: Key) async -> Value?
    
    /// Store value with optional expiration
    /// - Parameters:
    ///   - value: Value to cache
    ///   - key: Cache key
    ///   - expiration: Optional expiration time interval (seconds)
    func set(_ value: Value, for key: Key, expiration: TimeInterval?) async
    
    /// Remove cached value for the given key
    /// - Parameter key: Cache key
    func remove(for key: Key) async
    
    /// Clear all cached values
    func clearAll() async
    
    /// Check if cache contains value for the given key
    /// - Parameter key: Cache key
    /// - Returns: True if key exists and not expired, false otherwise
    func contains(_ key: Key) async -> Bool
}

// Default implementation of AnyCacheStorage for CacheStorage types
extension CacheStorage {
    public func getAny(for key: Key) async -> (any Codable & Sendable)? {
        return await get(for: key)
    }
    
    public func setAny(_ value: any Codable & Sendable, for key: Key, expiration: TimeInterval?) async {
        guard let typedValue = value as? Value else { return }
        await set(typedValue, for: key, expiration: expiration)
    }
}

/// Cache metadata for tracking cache statistics
public struct CacheMetadata: Codable, Sendable {
    public let createdAt: Date
    public var expiration: Date?
    public var accessCount: Int
    public var lastAccessed: Date?
    
    public init(createdAt: Date, expiration: Date?, accessCount: Int = 0, lastAccessed: Date? = nil) {
        self.createdAt = createdAt
        self.expiration = expiration
        self.accessCount = accessCount
        self.lastAccessed = lastAccessed
    }
    
    public var isExpired: Bool {
        guard let expiration = expiration else { return false }
        return Date() > expiration
    }
}

/// Cache entry combining value and metadata
public struct CacheEntry<T: Codable & Sendable>: Codable, Sendable {
    public let value: T
    public var metadata: CacheMetadata
    
    public init(value: T, metadata: CacheMetadata) {
        self.value = value
        self.metadata = metadata
    }
}
