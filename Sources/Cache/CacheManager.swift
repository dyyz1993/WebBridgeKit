import Foundation

/// Central cache manager providing unified cache interface
public actor CacheManager {
    /// Shared singleton instance
    public static let shared = CacheManager()

    private let memoryCache: MemoryCache<String, Data>
    private let diskCache: DiskCache
    private var configuration: CacheConfiguration
    // private var specializedCaches: [String: any CacheStorage] = [:]

    /// Cache statistics
    public private(set) var globalStatistics: SystemCacheStatistics

    private init() {
        do {
            self.memoryCache = MemoryCache<String, Data>(configuration: .default)
            self.diskCache = try DiskCache(directoryName: "CacheManager", configuration: .persistent)
            self.configuration = .default
            self.globalStatistics = SystemCacheStatistics(
                totalRequests: 0,
                cacheHits: 0,
                cacheMisses: 0,
                hitRate: 0.0,
                totalCacheSize: 0
            )
        } catch {
            fatalError("Failed to initialize CacheManager: \(error)")
        }
    }

    // MARK: - Generic Cache Operations

    public func get<T: Codable & Sendable>(for key: String, as type: T.Type, namespace: String? = nil) async -> T? {
        let fullKey = namespace.map { CacheKeyGenerator.generate(namespace: $0, identifier: key) } ?? key

        if let data = await memoryCache.get(for: fullKey) {
            return try? JSONDecoder().decode(T.self, from: data)
        }

        if let data = await diskCache.getTypedData(for: fullKey) {
            if let value = try? JSONDecoder().decode(T.self, from: data) {
                if let encoded = try? JSONEncoder().encode(value) {
                    await memoryCache.set(encoded, for: fullKey, expiration: configuration.expirationPolicy.timeInterval)
                }
                return value
            }
        }

        return nil
    }

    /// Store value in cache
    /// - Parameters:
    ///   - value: Value to cache
    ///   - key: Cache key
    ///   - expiration: Expiration time in seconds (optional)
    ///   - namespace: Optional namespace for key
    public func set<T: Codable & Sendable>(
        _ value: T,
        for key: String,
        expiration: TimeInterval? = nil,
        namespace: String? = nil
    ) async {
        let fullKey = namespace.map { CacheKeyGenerator.generate(namespace: $0, identifier: key) } ?? key

        let exp = expiration ?? configuration.expirationPolicy.timeInterval

        if let encoded = try? JSONEncoder().encode(value) {
            await memoryCache.set(encoded, for: fullKey, expiration: exp)
        }
        await diskCache.set(value, for: fullKey, expiration: expiration)
    }

    /// Remove cached value
    /// - Parameter key: Cache key
    public func remove(for key: String) async {
        await memoryCache.remove(for: key)
        await diskCache.remove(for: key)
    }

    /// Clear all caches
    public func clearAll() async {
        await memoryCache.clearAll()
        await diskCache.clearAll()
        // for (_, _) in specializedCaches {
        //     // Note: We can't directly clear generic caches, so this is limited
        //     // In production, you'd need to track and clear appropriately
        // }
    }

    // MARK: - Specialized Cache Operations

    // Register specialized cache for specific type
    // - Parameters:
    //   - cache: Cache implementation
    //   - name: Cache name
    // public func register<T: CacheStorage>(cache: T, forName name: String) async {
    //     specializedCaches[name] = cache
    // }

    // Get specialized cache by name
    // - Parameter name: Cache name
    // - Returns: Cache if exists
    // public func getCache(forName name: String) -> (any CacheStorage)? {
    //     specializedCaches[name]
    // }

    // MARK: - API Response Caching

    /// Cache API response
    /// - Parameters:
    ///   - response: Response data
    ///   - url: Request URL
    ///   - method: HTTP method
    ///   - expiration: Expiration time
    public func cacheAPIResponse<T: Codable & Sendable>(
        _ response: T,
        url: URL,
        method: String = "GET",
        expiration: TimeInterval? = nil
    ) async {
        let key = CacheKeyGenerator.generate(from: url, method: method)
        await set(response, for: key, expiration: expiration, namespace: CacheNamespace.api)
    }

    /// Get cached API response
    /// - Parameters:
    ///   - url: Request URL
    ///   - method: HTTP method
    ///   - type: Response type
    /// - Returns: Cached response if exists
    public func getCachedAPIResponse<T: Codable & Sendable>(
        url: URL,
        method: String = "GET",
        as type: T.Type
    ) async -> T? {
        let key = CacheKeyGenerator.generate(from: url, method: method)
        return await get(for: key, as: type, namespace: CacheNamespace.api)
    }

    // MARK: - Statistics

    /// Get cache statistics
    /// - Returns: Combined cache statistics
    public func getStatistics() async -> (memory: SystemCacheStatistics, disk: SystemCacheStatistics) {
        async let memStats = memoryCache.getStatistics()
        async let diskStats = diskCache.getStatistics()
        return (await memStats, await diskStats)
    }

    /// Get global statistics summary
    /// - Returns: Global statistics across all caches
    public func getGlobalStatistics() async -> SystemCacheStatistics {
        let stats = await getStatistics()
        let totalHits = stats.memory.cacheHits + stats.disk.cacheHits
        let totalMisses = stats.memory.cacheMisses + stats.disk.cacheMisses
        let totalRequests = totalHits + totalMisses
        let hitRate = totalRequests > 0 ? Double(totalHits) / Double(totalRequests) : 0.0
        let totalCacheSize = stats.memory.totalCacheSize + stats.disk.totalCacheSize

        return SystemCacheStatistics(
            totalRequests: totalRequests,
            cacheHits: totalHits,
            cacheMisses: totalMisses,
            hitRate: hitRate,
            totalCacheSize: totalCacheSize
        )
    }

    /// Reset all statistics
    public func resetStatistics() async {
        await memoryCache.resetStatistics()
        await diskCache.resetStatistics()
        globalStatistics = SystemCacheStatistics(
            totalRequests: 0,
            cacheHits: 0,
            cacheMisses: 0,
            hitRate: 0.0,
            totalCacheSize: 0
        )
    }

    /// Print cache statistics to console
    public func printStatistics() async {
        let stats = await getStatistics()
        let global = await getGlobalStatistics()

        print("=== Cache Statistics ===")
        print("Memory Cache:")
        print("  Hits: \(stats.memory.cacheHits), Misses: \(stats.memory.cacheMisses)")
        print("  Hit Rate: \(String(format: "%.2f%%", stats.memory.hitRate * 100))")
        print("  Total Size: \(ByteCountFormatter.string(fromByteCount: stats.memory.totalCacheSize, countStyle: .file))")
        print("")
        print("Disk Cache:")
        print("  Hits: \(stats.disk.cacheHits), Misses: \(stats.disk.cacheMisses)")
        print("  Hit Rate: \(String(format: "%.2f%%", stats.disk.hitRate * 100))")
        print("  Total Size: \(ByteCountFormatter.string(fromByteCount: stats.disk.totalCacheSize, countStyle: .file))")
        print("")
        print("Global:")
        print("  Total Requests: \(global.totalRequests)")
        print("  Overall Hit Rate: \(String(format: "%.2f%%", global.hitRate * 100))")
        print("  Total Cache Size: \(ByteCountFormatter.string(fromByteCount: global.totalCacheSize, countStyle: .file))")
    }
}

// MARK: - Convenience Extensions

extension CacheManager {
    /// Cache with automatic expiration based on policy
    /// - Parameters:
    ///   - value: Value to cache
    ///   - key: Cache key
    ///   - policy: Cache expiration policy
    public func set<T: Codable & Sendable>(
        _ value: T,
        for key: String,
        policy: CacheExpirationPolicy
    ) async {
        await set(value, for: key, expiration: policy.timeInterval)
    }

    /// Get or compute cached value
    /// - Parameters:
    ///   - key: Cache key
    ///   - expiration: Expiration time
    ///   - factory: Factory function to compute value if not cached
    /// - Returns: Cached or newly computed value
    public func getOrSet<T: Codable & Sendable>(
        for key: String,
        expiration: TimeInterval?,
        factory: @Sendable () async throws -> T
    ) async throws -> T {
        if let cached = await get(for: key, as: T.self) {
            return cached
        }

        let value = try await factory()
        await set(value, for: key, expiration: expiration)
        return value
    }
}
