import XCTest
@testable import WebBridgeKit

final class MemoryCacheTests: XCTestCase {
    var cache: MemoryCache<String, String>!
    
    override func setUp() async throws {
        try await super.setUp()
        cache = MemoryCache<String, String>(configuration: .default)
    }
    
    override func tearDown() async throws {
        await cache.clearAll()
        try await super.tearDown()
    }
    
    // MARK: - Basic Operations
    
    func testSetAndGet() async throws {
        await cache.set("value1", for: "key1", expiration: nil)
        let value = await cache.get(for: "key1")
        
        XCTAssertEqual(value, "value1")
    }
    
    func testGetNonExistentKey() async throws {
        let value = await cache.get(for: "nonexistent")
        
        XCTAssertNil(value)
    }
    
    func testRemoveKey() async throws {
        await cache.set("value1", for: "key1", expiration: nil)
        await cache.remove(for: "key1")
        
        let value = await cache.get(for: "key1")
        XCTAssertNil(value)
    }
    
    func testClearAll() async throws {
        await cache.set("value1", for: "key1", expiration: nil)
        await cache.set("value2", for: "key2", expiration: nil)
        
        await cache.clearAll()
        
        XCTAssertNil(await cache.get(for: "key1"))
        XCTAssertNil(await cache.get(for: "key2"))
    }
    
    func testContainsKey() async throws {
        await cache.set("value1", for: "key1", expiration: nil)
        
        XCTAssertTrue(await cache.contains("key1"))
        XCTAssertFalse(await cache.contains("nonexistent"))
    }
    
    // MARK: - Expiration
    
    func testExpiration() async throws {
        await cache.set("value1", for: "key1", expiration: 1.0)
        
        // Should exist immediately
        XCTAssertNotNil(await cache.get(for: "key1"))
        
        // Wait for expiration
        try await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5 seconds
        
        // Should be expired
        XCTAssertNil(await cache.get(for: "key1"))
    }
    
    func testNoExpiration() async throws {
        await cache.set("value1", for: "key1", expiration: nil)
        
        // Should still exist after delay
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
        XCTAssertNotNil(await cache.get(for: "key1"))
    }
    
    // MARK: - Eviction
    
    func testLRUEviction() async throws {
        let config = CacheConfiguration(
            expirationPolicy: .never,
            evictionPolicy: .leastRecentlyUsed,
            maxSize: 3
        )
        cache = MemoryCache<String, String>(configuration: config)
        
        // Fill cache
        await cache.set("value1", for: "key1", expiration: nil)
        await cache.set("value2", for: "key2", expiration: nil)
        await cache.set("value3", for: "key3", expiration: nil)
        
        // Access key1 to make it recently used
        _ = await cache.get(for: "key1")
        
        // Add one more item - should evict key2 (least recently used)
        await cache.set("value4", for: "key4", expiration: nil)
        
        XCTAssertNotNil(await cache.get(for: "key1"))
        XCTAssertNil(await cache.get(for: "key2"))
        XCTAssertNotNil(await cache.get(for: "key3"))
        XCTAssertNotNil(await cache.get(for: "key4"))
    }
    
    func testLFUEviction() async throws {
        let config = CacheConfiguration(
            expirationPolicy: .never,
            evictionPolicy: .leastFrequentlyUsed,
            maxSize: 3
        )
        cache = MemoryCache<String, String>(configuration: config)
        
        // Fill cache
        await cache.set("value1", for: "key1", expiration: nil)
        await cache.set("value2", for: "key2", expiration: nil)
        await cache.set("value3", for: "key3", expiration: nil)
        
        // Access key1 twice, key2 once, key3 not at all
        _ = await cache.get(for: "key1")
        _ = await cache.get(for: "key1")
        _ = await cache.get(for: "key2")
        
        // Add one more item - should evict key3 (least frequently used)
        await cache.set("value4", for: "key4", expiration: nil)
        
        XCTAssertNotNil(await cache.get(for: "key1"))
        XCTAssertNotNil(await cache.get(for: "key2"))
        XCTAssertNil(await cache.get(for: "key3"))
        XCTAssertNotNil(await cache.get(for: "key4"))
    }
    
    // MARK: - Statistics
    
    func testStatistics() async throws {
        await cache.set("value1", for: "key1", expiration: nil)
        
        // Hit
        _ = await cache.get(for: "key1")
        
        // Miss
        _ = await cache.get(for: "nonexistent")
        
        let stats = cache.getStatistics()
        
        XCTAssertEqual(stats.hitCount, 1)
        XCTAssertEqual(stats.missCount, 1)
        XCTAssertEqual(stats.hitRate, 0.5)
    }
    
    func testStatisticsReset() async throws {
        await cache.set("value1", for: "key1", expiration: nil)
        _ = await cache.get(for: "key1")
        
        cache.resetStatistics()
        
        let stats = cache.getStatistics()
        
        XCTAssertEqual(stats.hitCount, 0)
        XCTAssertEqual(stats.missCount, 0)
    }
    
    // MARK: - Complex Types
    
    struct User: Codable, Sendable {
        let id: Int
        let name: String
    }
    
    func testComplexTypes() async throws {
        let user = User(id: 1, name: "John Doe")
        
        await cache.set(user, for: "user1", expiration: nil)
        let cachedUser: User? = await cache.get(for: "user1")
        
        XCTAssertNotNil(cachedUser)
        XCTAssertEqual(cachedUser?.id, 1)
        XCTAssertEqual(cachedUser?.name, "John Doe")
    }
}
