import XCTest
@testable import WebBridgeKit

final class DiskCacheTests: XCTestCase {
    var cache: DiskCache!
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TestDiskCache")
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Clean up any existing cache
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
    
    // MARK: - Basic Operations
    
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
    
    // MARK: - Key Sanitization
    
    func testKeySanitization() async throws {
        let invalidKey = "key:with/invalid\\chars?*"
        
        await cache.set("value1", for: invalidKey, expiration: nil)
        let value = await cache.get(for: invalidKey)
        
        XCTAssertNotNil(value)
        XCTAssertEqual(value as? String, "value1")
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
    }
    
    // MARK: - Complex Types
    
    struct User: Codable, Sendable {
        let id: Int
        let name: String
    }
    
    func testComplexTypes() async throws {
        let user = User(id: 1, name: "John Doe")
        
        await cache.set(user, for: "user1", expiration: nil)
        let cachedUser = await cache.get(for: "user1")
        
        XCTAssertNotNil(cachedUser)
        
        if let user = cachedUser as? User {
            XCTAssertEqual(user.id, 1)
            XCTAssertEqual(user.name, "John Doe")
        } else {
            XCTFail("Expected User type")
        }
    }
    
    // MARK: - Size-based Eviction
    
    func testSizeBasedEviction() async throws {
        let config = CacheConfiguration(
            expirationPolicy: .never,
            evictionPolicy: .sizeBased(maxBytes: 1024),  // 1KB limit
            maxSize: 100
        )
        
        try? FileManager.default.removeItem(at: tempDirectory)
        cache = try DiskCache(directoryName: "TestDiskCache", configuration: config)
        
        // Create large data
        let largeData = String(repeating: "x", count: 2000)
        
        await cache.set(largeData, for: "large1", expiration: nil)
        let value1 = await cache.get(for: "large1")
        XCTAssertNotNil(value1)
        
        // Add more large data - should trigger eviction
        await cache.set(largeData, for: "large2", expiration: nil)
        await cache.set(largeData, for: "large3", expiration: nil)
        
        // At least one item should be evicted
        let stats = cache.getStatistics()
        XCTAssertGreaterThan(stats.evictionCount, 0)
    }
}
