import XCTest
@testable import WebBridgeKit

final class CacheStorageTests: XCTestCase {

    func testCacheMetadataNotExpiredWithFutureDate() {
        let metadata = CacheMetadata(
            createdAt: Date(),
            expiration: Date().addingTimeInterval(3600),
            accessCount: 0
        )
        XCTAssertFalse(metadata.isExpired)
    }

    func testCacheMetadataExpiredWithPastDate() {
        let metadata = CacheMetadata(
            createdAt: Date().addingTimeInterval(-7200),
            expiration: Date().addingTimeInterval(-3600),
            accessCount: 0
        )
        XCTAssertTrue(metadata.isExpired)
    }

    func testCacheMetadataNotExpiredWithNilExpiration() {
        let metadata = CacheMetadata(
            createdAt: Date(),
            expiration: nil,
            accessCount: 0
        )
        XCTAssertFalse(metadata.isExpired)
    }

    func testCacheMetadataJustExpired() {
        let metadata = CacheMetadata(
            createdAt: Date().addingTimeInterval(-10),
            expiration: Date().addingTimeInterval(-1),
            accessCount: 0
        )
        XCTAssertTrue(metadata.isExpired)
    }

    func testCacheMetadataJustNotExpired() {
        let metadata = CacheMetadata(
            createdAt: Date(),
            expiration: Date().addingTimeInterval(0.001),
            accessCount: 0
        )
        XCTAssertFalse(metadata.isExpired)
    }

    func testCacheMetadataDefaultAccessCount() {
        let metadata = CacheMetadata(createdAt: Date(), expiration: nil)
        XCTAssertEqual(metadata.accessCount, 0)
    }

    func testCacheMetadataCustomAccessCount() {
        let metadata = CacheMetadata(createdAt: Date(), expiration: nil, accessCount: 42)
        XCTAssertEqual(metadata.accessCount, 42)
    }

    func testCacheMetadataLastAccessed() {
        let date = Date()
        let metadata = CacheMetadata(createdAt: date, expiration: nil, lastAccessed: date)
        XCTAssertEqual(metadata.lastAccessed, date)
    }

    func testCacheMetadataCodableRoundTrip() throws {
        let metadata = CacheMetadata(
            createdAt: Date(),
            expiration: Date().addingTimeInterval(3600),
            accessCount: 5,
            lastAccessed: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CacheMetadata.self, from: data)

        XCTAssertEqual(decoded.accessCount, 5)
        XCTAssertEqual(decoded.isExpired, metadata.isExpired)
    }

    func testCacheEntryCreation() {
        let metadata = CacheMetadata(createdAt: Date(), expiration: nil)
        let entry = CacheEntry(value: "test", metadata: metadata)
        XCTAssertEqual(entry.value, "test")
        XCTAssertEqual(entry.metadata.accessCount, metadata.accessCount)
    }

    func testCacheEntryCodableString() throws {
        let metadata = CacheMetadata(createdAt: Date(), expiration: nil)
        let entry = CacheEntry(value: "hello", metadata: metadata)

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(CacheEntry<String>.self, from: data)

        XCTAssertEqual(decoded.value, "hello")
    }

    func testCacheEntryCodableInt() throws {
        let metadata = CacheMetadata(createdAt: Date(), expiration: nil)
        let entry = CacheEntry(value: 42, metadata: metadata)

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(CacheEntry<Int>.self, from: data)

        XCTAssertEqual(decoded.value, 42)
    }

    func testCacheEntryCodableStringArray() throws {
        let metadata = CacheMetadata(createdAt: Date(), expiration: nil)
        let entry = CacheEntry(value: ["a", "b", "c"], metadata: metadata)

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(CacheEntry<[String]>.self, from: data)

        XCTAssertEqual(decoded.value, ["a", "b", "c"])
    }

    func testCacheEntryMetadataMutation() {
        var metadata = CacheMetadata(createdAt: Date(), expiration: nil, accessCount: 1)
        let entry = CacheEntry(value: "test", metadata: metadata)
        XCTAssertEqual(entry.metadata.accessCount, 1)
        metadata.accessCount = 10
        XCTAssertEqual(entry.metadata.accessCount, 1)
    }
}
