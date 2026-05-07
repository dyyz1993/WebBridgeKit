import XCTest
@testable import WebBridgeKit

final class HybridCacheTests: XCTestCase {
    var cache: HybridCache<String>!

    override func setUp() async throws {
        try await super.setUp()
        cache = try HybridCache<String>(
            memoryConfig: CacheConfiguration(maxSize: 100),
            diskConfig: CacheConfiguration(maxSize: 200),
            diskDirectoryName: "HybridCacheTest-\(UUID().uuidString)"
        )
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

    func testGetNonExistentKey() async {
        let value = await cache.get(for: "nonexistent")
        XCTAssertNil(value)
    }

    func testRemoveKey() async {
        await cache.set("value1", for: "key1", expiration: nil)
        await cache.remove(for: "key1")
        let value = await cache.get(for: "key1")
        XCTAssertNil(value)
    }

    func testClearAll() async {
        await cache.set("value1", for: "key1", expiration: nil)
        await cache.set("value2", for: "key2", expiration: nil)
        await cache.clearAll()
        let v1 = await cache.get(for: "key1")
        let v2 = await cache.get(for: "key2")
        XCTAssertNil(v1)
        XCTAssertNil(v2)
    }

    func testContainsTrue() async {
        await cache.set("value1", for: "key1", expiration: nil)
        let result = await cache.contains("key1")
        XCTAssertTrue(result)
    }

    func testContainsFalse() async {
        let result = await cache.contains("nonexistent")
        XCTAssertFalse(result)
    }

    func testMultipleValues() async {
        await cache.set("a", for: "k1", expiration: nil)
        await cache.set("b", for: "k2", expiration: nil)
        await cache.set("c", for: "k3", expiration: nil)
        let v1 = await cache.get(for: "k1")
        let v2 = await cache.get(for: "k2")
        let v3 = await cache.get(for: "k3")
        XCTAssertEqual(v1, "a")
        XCTAssertEqual(v2, "b")
        XCTAssertEqual(v3, "c")
    }

    func testOverwriteValue() async {
        await cache.set("old", for: "key1", expiration: nil)
        await cache.set("new", for: "key1", expiration: nil)
        let updated = await cache.get(for: "key1")
        XCTAssertEqual(updated, "new")
    }

    func testGetStatistics() async {
        await cache.set("value1", for: "key1", expiration: nil)
        let stats = await cache.getStatistics()
        XCTAssertGreaterThanOrEqual(stats.memory.totalRequests, 0)
    }

    func testResetStatistics() async {
        await cache.set("value1", for: "key1", expiration: nil)
        await cache.resetStatistics()
        let stats = await cache.getStatistics()
        XCTAssertEqual(stats.memory.totalRequests, 0)
    }

    func testPreloadNoCrash() async {
        await cache.set("value1", for: "key1", expiration: nil)
        await cache.preload(intoMemory: 100)
    }

    func testFlushToDiskNoCrash() async {
        await cache.set("value1", for: "key1", expiration: nil)
        await cache.flushToDisk()
    }

    func testRemoveNonExistentKeyNoCrash() async {
        await cache.remove(for: "nonexistent")
    }

    func testDiskFallbackOnMemoryMiss() async throws {
        await cache.set("diskValue", for: "diskKey", expiration: nil)
        let value = await cache.get(for: "diskKey")
        XCTAssertEqual(value, "diskValue")
    }

    func testSetWithExpiration() async {
        await cache.set("value", for: "key", expiration: 60.0)
        let value = await cache.get(for: "key")
        XCTAssertEqual(value, "value")
    }
}
