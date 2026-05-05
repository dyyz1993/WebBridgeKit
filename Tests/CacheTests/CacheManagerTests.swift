import XCTest
@testable import WebBridgeKit

final class CacheManagerTests: XCTestCase {
    
    func testSharedInstance() {
        let manager1 = CacheManager.shared
        let manager2 = CacheManager.shared
        
        XCTAssertTrue(manager1 === manager2, "CacheManager should be a singleton")
    }
    
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
        
        let v1: String? = await CacheManager.shared.get(for: "key1", as: String.self)
        let v2: String? = await CacheManager.shared.get(for: "key2", as: String.self)
        XCTAssertNil(v1)
        XCTAssertNil(v2)
    }
    
    func testNamespacedKeys() async throws {
        await CacheManager.shared.set("value1", for: "key1", namespace: "api")
        await CacheManager.shared.set("value2", for: "key1", namespace: "user")
        
        let apiValue: String? = await CacheManager.shared.get(for: "key1", as: String.self, namespace: "api")
        let userValue: String? = await CacheManager.shared.get(for: "key1", as: String.self, namespace: "user")
        
        XCTAssertEqual(apiValue, "value1")
        XCTAssertEqual(userValue, "value2")
    }
    
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
    
    func testGetOrSet() async throws {
        var callCount = 0
        
        let value1 = try await CacheManager.shared.getOrSet(for: "key1_gos", expiration: 3600) {
            callCount += 1
            return "computed value"
        }
        
        XCTAssertEqual(value1, "computed value")
        XCTAssertEqual(callCount, 1)
        
        let value2 = try await CacheManager.shared.getOrSet(for: "key1_gos", expiration: 3600) {
            callCount += 1
            return "computed value"
        }
        
        XCTAssertEqual(value2, "computed value")
        XCTAssertEqual(callCount, 1, "Factory should not be called again")
    }
    
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
        XCTAssertEqual(stats.cacheHits, 0)
        XCTAssertEqual(stats.cacheMisses, 0)
    }
    
    func testPolicyBasedCaching() async throws {
        await CacheManager.shared.set("value1", for: "key1_policy", policy: .seconds(1))
        
        let before = await CacheManager.shared.get(for: "key1_policy", as: String.self)
        XCTAssertNotNil(before)
        
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        let after = await CacheManager.shared.get(for: "key1_policy", as: String.self)
        XCTAssertNil(after)
    }
}
