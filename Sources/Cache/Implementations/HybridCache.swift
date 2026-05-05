import Foundation

/// Hybrid cache that combines memory and disk caches
public actor HybridCache<Value: Codable & Sendable>: CacheStorage {
    public typealias Key = String
    
    private let memoryCache: MemoryCache<String, Value>
    private let diskCache: DiskCache
    private var configuration: CacheConfiguration
    
    public init(
        memoryConfig: CacheConfiguration = .default,
        diskConfig: CacheConfiguration = .persistent,
        diskDirectoryName: String = "HybridCache"
    ) throws {
        self.memoryCache = MemoryCache(configuration: memoryConfig)
        self.diskCache = try DiskCache(directoryName: diskDirectoryName, configuration: diskConfig)
        self.configuration = memoryConfig
    }
    
    public func get(for key: Key) async -> Value? {
        if let value = await memoryCache.get(for: key) {
            return value
        }
        
        if let diskValue = await diskCache.get(for: key) {
            guard let value = diskValue as? Value else {
                return nil
            }
            await memoryCache.set(value, for: key, expiration: configuration.expirationPolicy.timeInterval)
            return value
        }
        
        return nil
    }
    
    public func set(_ value: Value, for key: Key, expiration: TimeInterval?) async {
        await memoryCache.set(value, for: key, expiration: expiration ?? configuration.expirationPolicy.timeInterval)
        await diskCache.set(value, for: key, expiration: expiration)
    }
    
    public func remove(for key: Key) async {
        await memoryCache.remove(for: key)
        await diskCache.remove(for: key)
    }
    
    public func clearAll() async {
        await memoryCache.clearAll()
        await diskCache.clearAll()
    }
    
    public func contains(_ key: Key) async -> Bool {
        let inMemory = await memoryCache.contains(key)
        if inMemory { return true }
        return await diskCache.contains(key)
    }
    
    // MARK: - Statistics
    
    public func getStatistics() async -> (memory: SystemCacheStatistics, disk: SystemCacheStatistics) {
        async let memStats = memoryCache.getStatistics()
        async let diskStats = diskCache.getStatistics()
        return (await memStats, await diskStats)
    }
    
    public func resetStatistics() async {
        await memoryCache.resetStatistics()
        await diskCache.resetStatistics()
    }
    
    // MARK: - Advanced Operations
    
    /// Preload data into memory cache from disk cache
    public func preload(intoMemory count: Int = 100) async {
        
    }
    
    /// Flush memory cache to disk cache
    public func flushToDisk() async {
        
    }
}
