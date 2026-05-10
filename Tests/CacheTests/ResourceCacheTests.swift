import XCTest
@testable import WebBridgeKit

final class ResourceCacheTests: XCTestCase {

    var cache: ResourceCache!

    override func setUp() {
        super.setUp()
        cache = ResourceCache()
        cache.removeAll()
        Thread.sleep(forTimeInterval: 0.1)
    }

    override func tearDown() {
        cache.removeAll()
        Thread.sleep(forTimeInterval: 0.1)
        super.tearDown()
    }

    func testSharedIsSingleton() {
        let c1 = ResourceCache.shared
        let c2 = ResourceCache.shared
        XCTAssertTrue(c1 === c2)
    }

    func testSharedIsNotNil() {
        XCTAssertNotNil(ResourceCache.shared)
    }

    func testSetAndGetRoundTrip() {
        let pageKey = "page-\(UUID().uuidString)"
        let resource = ResourceData(
            relativePath: "style.css",
            data: Data("body{}".utf8),
            mimeType: "text/css"
        )

        cache.set(resource, for: pageKey)
        Thread.sleep(forTimeInterval: 0.15)

        let result = cache.get("style.css", for: pageKey)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.relativePath, "style.css")
        XCTAssertEqual(result?.mimeType, "text/css")
    }

    func testGetNonExistentKeyReturnsNil() {
        let result = cache.get("missing.js", for: "page-\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    func testRemoveAllClearsCache() {
        let pageKey = "page-clear-\(UUID().uuidString)"
        let resource = ResourceData(relativePath: "app.js", data: Data("var a=1".utf8), mimeType: "application/javascript")
        cache.set(resource, for: pageKey)
        Thread.sleep(forTimeInterval: 0.15)

        cache.removeAll()
        Thread.sleep(forTimeInterval: 0.15)

        let result = cache.get("app.js", for: pageKey)
        XCTAssertNil(result)
    }

    func testRemoveAllForPageKey() async throws {
        let cache = ResourceCache.shared
        let pageKey = "test-page-\(UUID().uuidString)"
        let r1 = ResourceData(relativePath: "a.js", data: Data("script".utf8), mimeType: "application/javascript")
        let r2 = ResourceData(relativePath: "b.css", data: Data("style".utf8), mimeType: "text/css")

        cache.set(r1, for: pageKey)
        cache.set(r2, for: pageKey)
        try await Task.sleep(nanoseconds: 500_000_000)

        cache.removeAll(for: pageKey)
        try await Task.sleep(nanoseconds: 500_000_000)

        let result1 = cache.get("a.js", for: pageKey)
        let result2 = cache.get("b.css", for: pageKey)
        XCTAssertNil(result1, "a.js should be removed after removeAll")
        XCTAssertNil(result2, "b.css should be removed after removeAll")
    }

    func testTotalSizeIsNonNegative() {
        let size = cache.totalSize()
        XCTAssertGreaterThanOrEqual(size, 0)
    }

    func testDifferentPageKeysAreIndependent() {
        let pk1 = "page-a-\(UUID().uuidString)"
        let pk2 = "page-b-\(UUID().uuidString)"
        let r1 = ResourceData(relativePath: "data.json", data: Data("{\"a\":1}".utf8), mimeType: "application/json")
        let r2 = ResourceData(relativePath: "data.json", data: Data("{\"b\":2}".utf8), mimeType: "application/json")

        cache.set(r1, for: pk1)
        cache.set(r2, for: pk2)
        Thread.sleep(forTimeInterval: 0.15)

        let result1 = cache.get("data.json", for: pk1)
        let result2 = cache.get("data.json", for: pk2)

        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertEqual(result1?.data, Data("{\"a\":1}".utf8))
        XCTAssertEqual(result2?.data, Data("{\"b\":2}".utf8))
    }

    func testResourceDataInit() {
        let data = Data(repeating: 0xAB, count: 100)
        let resource = ResourceData(relativePath: "image.png", data: data, mimeType: "image/png")

        XCTAssertEqual(resource.relativePath, "image.png")
        XCTAssertEqual(resource.data.count, 100)
        XCTAssertEqual(resource.mimeType, "image/png")
    }
}
