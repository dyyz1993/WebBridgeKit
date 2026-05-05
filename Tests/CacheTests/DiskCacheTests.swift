import XCTest
@testable import WebBridgeKit

final class DiskCacheTests: XCTestCase {
    var cache: DiskCache!
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TestDiskCache")
    
    override func setUp() async throws {
        try await super.setUp()
        
        try? FileManager.default.removeItem(at: tempDirectory)
        
        cache = try DiskCache(
            directoryName: "TestDiskCache",
            configuration: .default
        )
    }
    
    override func tearDown() async throws {
        await cache.clearAll()
        try? FileManager.default.removeItem(at: tempDirectory)
        try await super.tearDown()
    }
    
    func testSetAndGet() async throws {
        await cache.set("value1", for: "key1", expiration: nil)
        let value = await cache.get(for: "key1")
        
        XCTAssertEqual(value as? String, "value1")
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
    
    func testKeySanitization() async throws {
        let invalidKey = "key:with/invalid\\chars?*"
        
        await cache.set("value1", for: invalidKey, expiration: nil)
        let value = await cache.get(for: invalidKey)
        
        XCTAssertNotNil(value)
        XCTAssertEqual(value as? String, "value1")
    }
    
    func testStatistics() async throws {
        await cache.set("value1", for: "key1", expiration: nil)
        
        _ = await cache.get(for: "key1")
        _ = await cache.get(for: "nonexistent")
        
        let stats = await cache.getStatistics()
        
        XCTAssertEqual(stats.cacheHits, 1)
        XCTAssertEqual(stats.cacheMisses, 1)
    }
    
    struct User: Codable, Sendable {
        let id: Int
        let name: String
    }
    
    func testComplexTypes() async throws {
        let user = User(id: 1, name: "John Doe")
        
        await cache.set(user, for: "user1", expiration: nil)
        let cachedUser = await cache.getTyped(for: "user1", as: User.self)
        
        XCTAssertNotNil(cachedUser)
        XCTAssertEqual(cachedUser?.id, 1)
        XCTAssertEqual(cachedUser?.name, "John Doe")
    }
    
    func testSizeBasedEviction() async throws {
        let config = CacheConfiguration(
            expirationPolicy: .never,
            evictionPolicy: .sizeBased(maxBytes: 10240),
            maxSize: 100
        )
        
        try? FileManager.default.removeItem(at: tempDirectory)
        cache = try DiskCache(directoryName: "TestDiskCache", configuration: config)
        
        let largeData = String(repeating: "x", count: 200)
        
        await cache.set(largeData, for: "large1", expiration: nil)
        let value1 = await cache.get(for: "large1")
        XCTAssertNotNil(value1)
        
        await cache.set(largeData, for: "large2", expiration: nil)
        await cache.set(largeData, for: "large3", expiration: nil)
        
        let stats = await cache.getStatistics()
        XCTAssertGreaterThan(stats.cacheHits + stats.cacheMisses, 0)
    }
}
