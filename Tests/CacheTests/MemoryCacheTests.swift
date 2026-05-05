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
        let v1 = await cache.get(for: "key1")
        let v2 = await cache.get(for: "key2")
        XCTAssertNil(v1)
        XCTAssertNil(v2)
    }
    
    func testContainsKey() async throws {
        await cache.set("value1", for: "key1", expiration: nil)
        let hasKey = await cache.contains("key1")
        let hasNonexistent = await cache.contains("nonexistent")
        XCTAssertTrue(hasKey)
        XCTAssertFalse(hasNonexistent)
    }
    
    func testExpiration() async throws {
        await cache.set("value1", for: "key1", expiration: 1.0)
        let before = await cache.get(for: "key1")
        XCTAssertNotNil(before)
        
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        let after = await cache.get(for: "key1")
        XCTAssertNil(after)
    }
    
    func testNoExpiration() async throws {
        await cache.set("value1", for: "key1", expiration: nil)
        try await Task.sleep(nanoseconds: 100_000_000)
        let value = await cache.get(for: "key1")
        XCTAssertNotNil(value)
    }
    
    func testLRUEviction() async throws {
        let config = CacheConfiguration(
            expirationPolicy: .never,
            evictionPolicy: .leastRecentlyUsed,
            maxSize: 3
        )
        cache = MemoryCache<String, String>(configuration: config)
        
        await cache.set("value1", for: "key1", expiration: nil)
        await cache.set("value2", for: "key2", expiration: nil)
        await cache.set("value3", for: "key3", expiration: nil)
        
        _ = await cache.get(for: "key1")
        
        await cache.set("value4", for: "key4", expiration: nil)
        
        let k1 = await cache.get(for: "key1")
        let k2 = await cache.get(for: "key2")
        let k3 = await cache.get(for: "key3")
        let k4 = await cache.get(for: "key4")
        XCTAssertNotNil(k1)
        XCTAssertNil(k2)
        XCTAssertNotNil(k3)
        XCTAssertNotNil(k4)
    }
    
    func testLFUEviction() async throws {
        let config = CacheConfiguration(
            expirationPolicy: .never,
            evictionPolicy: .leastFrequentlyUsed,
            maxSize: 3
        )
        cache = MemoryCache<String, String>(configuration: config)
        
        await cache.set("value1", for: "key1", expiration: nil)
        await cache.set("value2", for: "key2", expiration: nil)
        await cache.set("value3", for: "key3", expiration: nil)
        
        _ = await cache.get(for: "key1")
        _ = await cache.get(for: "key1")
        _ = await cache.get(for: "key2")
        
        await cache.set("value4", for: "key4", expiration: nil)
        
        let k1 = await cache.get(for: "key1")
        let k2 = await cache.get(for: "key2")
        let k3 = await cache.get(for: "key3")
        let k4 = await cache.get(for: "key4")
        XCTAssertNotNil(k1)
        XCTAssertNotNil(k2)
        XCTAssertNil(k3)
        XCTAssertNotNil(k4)
    }
    
    func testStatistics() async throws {
        await cache.set("value1", for: "key1", expiration: nil)
        _ = await cache.get(for: "key1")
        _ = await cache.get(for: "nonexistent")
        
        let stats = await cache.getStatistics()
        XCTAssertEqual(stats.cacheHits, 1)
        XCTAssertEqual(stats.cacheMisses, 1)
        XCTAssertEqual(stats.hitRate, 0.5)
    }
    
    func testStatisticsReset() async throws {
        await cache.set("value1", for: "key1", expiration: nil)
        _ = await cache.get(for: "key1")
        
        await cache.resetStatistics()
        
        let stats = await cache.getStatistics()
        XCTAssertEqual(stats.cacheHits, 0)
        XCTAssertEqual(stats.cacheMisses, 0)
    }
    
    struct User: Codable, Sendable {
        let id: Int
        let name: String
    }
    
    func testComplexTypes() async throws {
        let userCache = MemoryCache<String, User>(configuration: .default)
        let user = User(id: 1, name: "John Doe")
        
        await userCache.set(user, for: "user1", expiration: nil)
        let cachedUser = await userCache.get(for: "user1")
        
        XCTAssertNotNil(cachedUser)
        XCTAssertEqual(cachedUser?.id, 1)
        XCTAssertEqual(cachedUser?.name, "John Doe")
    }
}
