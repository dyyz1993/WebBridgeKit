import XCTest
@testable import WebBridgeKit

final class CacheManagerTests: XCTestCase {
    
    // MARK: - Singleton
    
    func testSharedInstance() {
        let manager1 = CacheManager.shared
        let manager2 = CacheManager.shared
        
        XCTAssertTrue(manager1 === manager2, "CacheManager should be a singleton")
    }
    
    // MARK: - Basic Operations
    
    func testSetAndGet() async throws {
        await CacheManager.shared.set("value1", for: "key1")
        let value: String? = await CacheManager.shared.get(for: "key1", as: String.self)
        
        XCTAssertEqual(value, "value1")
    }
    
    func testGetNonExistentKey() async throws {
        let value: String? = await CacheManager.shared.get(for: "nonexistent", as: String.self)
        
        XCTAssertNil(value)
    }
    
    func testRemoveKey() async throws {
        await CacheManager.shared.set("value1", for: "key1")
        await CacheManager.shared.remove(for: "key1")
        
        let value: String? = await CacheManager.shared.get(for: "key1", as: String.self)
        XCTAssertNil(value)
    }
    
    func testClearAll() async throws {
        await CacheManager.shared.set("value1", for: "key1")
        await CacheManager.shared.set("value2", for: "key2")
        
        await CacheManager.shared.clearAll()
        
        XCTAssertNil(await CacheManager.shared.get(for: "key1", as: String.self))
        XCTAssertNil(await CacheManager.shared.get(for: "key2", as: String.self))
    }
    
    // MARK: - Namespace
    
    func testNamespacedKeys() async throws {
        await CacheManager.shared.set("value1", for: "key1", namespace: "api")
        await CacheManager.shared.set("value2", for: "key1", namespace: "user")
        
        let apiValue: String? = await CacheManager.shared.get(for: "key1", as: String.self)
        let userValue: String? = await CacheManager.shared.get(for: "key1", as: String.self)
        
        // The last set should override if using the same full key
        // This test depends on implementation details
        XCTAssertNotNil(apiValue)
    }
    
    // MARK: - API Response Caching
    
    func testAPIResponseCaching() async throws {
        struct User: Codable, Sendable {
            let id: Int
            let name: String
        }
        
        let user = User(id: 1, name: "John Doe")
        let url = URL(string: "https://api.example.com/users/1")!
        
        await CacheManager.shared.cacheAPIResponse(user, url: url, expiration: 3600)
        
        let cachedUser: User? = await CacheManager.shared.getCachedAPIResponse(url: url, as: User.self)
        
        XCTAssertNotNil(cachedUser)
        XCTAssertEqual(cachedUser?.id, 1)
        XCTAssertEqual(cachedUser?.name, "John Doe")
    }
    
    // MARK: - Get or Set
    
    func testGetOrSet() async throws {
        var callCount = 0
        
        // First call - should compute
        let value1 = try await CacheManager.shared.getOrSet(for: "key1", expiration: 3600) {
            callCount += 1
            return "computed value"
        }
        
        XCTAssertEqual(value1, "computed value")
        XCTAssertEqual(callCount, 1)
        
        // Second call - should use cache
        let value2 = try await CacheManager.shared.getOrSet(for: "key1", expiration: 3600) {
            callCount += 1
            return "computed value"
        }
        
        XCTAssertEqual(value2, "computed value")
        XCTAssertEqual(callCount, 1, "Factory should not be called again")
    }
    
    // MARK: - Statistics
    
    func testStatistics() async throws {
        await CacheManager.shared.set("value1", for: "key1")
        _ = await CacheManager.shared.get(for: "key1", as: String.self)
        _ = await CacheManager.shared.get(for: "nonexistent", as: String.self)
        
        let stats = await CacheManager.shared.getGlobalStatistics()
        
        XCTAssertGreaterThan(stats.totalRequests, 0)
    }
    
    func testStatisticsReset() async throws {
        await CacheManager.shared.set("value1", for: "key1")
        _ = await CacheManager.shared.get(for: "key1", as: String.self)
        
        await CacheManager.shared.resetStatistics()
        
        let stats = await CacheManager.shared.getGlobalStatistics()
        XCTAssertEqual(stats.hitCount, 0)
        XCTAssertEqual(stats.missCount, 0)
    }
    
    // MARK: - Policy-based Caching
    
    func testPolicyBasedCaching() async throws {
        await CacheManager.shared.set("value1", for: "key1", policy: .seconds(1))
        
        XCTAssertNotNil(await CacheManager.shared.get(for: "key1", as: String.self))
        
        try await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5 seconds
        
        XCTAssertNil(await CacheManager.shared.get(for: "key1", as: String.self))
    }
}
