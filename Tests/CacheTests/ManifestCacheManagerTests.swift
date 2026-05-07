import XCTest
@testable import WebBridgeKit

final class ManifestCacheManagerTests: XCTestCase {

    private var manager: ManifestCacheManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = ManifestCacheManager.shared
        manager.clearAll()
        let clearExpectation = expectation(description: "clear completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            clearExpectation.fulfill()
        }
        await fulfillment(of: [clearExpectation], timeout: 2.0)
    }

    // MARK: - Register / Unregister Manifest

    func testRegisterManifest() async {
        let manifest = Manifest(resources: ["logo.png": "https://example.com/logo.png"])
        manager.registerManifest(manifest, forPage: "testPage")

        let waitExpectation = expectation(description: "register completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            waitExpectation.fulfill()
        }
        await fulfillment(of: [waitExpectation], timeout: 2.0)

        let cached = manager.getCachedManifest(for: "testPage")
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.resources["logo.png"], "https://example.com/logo.png")
    }

    func testUnregisterManifest() async {
        let manifest = Manifest(resources: ["style.css": "https://example.com/style.css"])
        manager.registerManifest(manifest, forPage: "removePage")

        let waitExpectation = expectation(description: "register completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            waitExpectation.fulfill()
        }
        await fulfillment(of: [waitExpectation], timeout: 2.0)

        manager.unregisterManifest(forPage: "removePage")

        let waitExpectation2 = expectation(description: "unregister completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            waitExpectation2.fulfill()
        }
        await fulfillment(of: [waitExpectation2], timeout: 2.0)

        let cached = manager.getCachedManifest(for: "removePage")
        XCTAssertNil(cached)
    }

    func testRegisterMultipleManifests() async {
        let manifest1 = Manifest(resources: ["a.png": "https://a.com/a.png"])
        let manifest2 = Manifest(resources: ["b.png": "https://b.com/b.png"])

        manager.registerManifest(manifest1, forPage: "page1")
        manager.registerManifest(manifest2, forPage: "page2")

        let waitExpectation = expectation(description: "register completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            waitExpectation.fulfill()
        }
        await fulfillment(of: [waitExpectation], timeout: 2.0)

        XCTAssertNotNil(manager.getCachedManifest(for: "page1"))
        XCTAssertNotNil(manager.getCachedManifest(for: "page2"))
        XCTAssertEqual(manager.getCachedManifest(for: "page1")?.resources["a.png"], "https://a.com/a.png")
        XCTAssertEqual(manager.getCachedManifest(for: "page2")?.resources["b.png"], "https://b.com/b.png")
    }

    // MARK: - Cached Manifest

    func testGetCachedManifestReturnsNilForUnknown() {
        let cached = manager.getCachedManifest(for: "nonexistent")
        XCTAssertNil(cached)
    }

    func testGetCachedHTMLReturnsNilForUnknown() {
        let html = manager.getCachedHTML(for: "nonexistent")
        XCTAssertNil(html)
    }

    // MARK: - Resource Caching

    func testCacheResourceAndGetCachedResource() {
        let resource = ResourceData(
            relativePath: "images/logo.png",
            data: Data("fake image data".utf8),
            mimeType: "image/png"
        )

        manager.cacheResource(resource, for: "testPage")

        let cached = manager.getCachedResource(relativePath: "images/logo.png", for: "testPage")
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.mimeType, "image/png")
        XCTAssertEqual(cached?.data, Data("fake image data".utf8))
    }

    func testGetCachedResourceReturnsNilWhenNotCached() {
        let cached = manager.getCachedResource(relativePath: "nonexistent.png", for: "noPage")
        XCTAssertNil(cached)
    }

    func testCacheMultipleResourcesForSamePage() {
        let resource1 = ResourceData(relativePath: "a.css", data: Data("css".utf8), mimeType: "text/css")
        let resource2 = ResourceData(relativePath: "b.js", data: Data("js".utf8), mimeType: "application/javascript")

        manager.cacheResource(resource1, for: "multiPage")
        manager.cacheResource(resource2, for: "multiPage")

        XCTAssertNotNil(manager.getCachedResource(relativePath: "a.css", for: "multiPage"))
        XCTAssertNotNil(manager.getCachedResource(relativePath: "b.js", for: "multiPage"))
    }

    // MARK: - Cache Stats

    func testGetStatsInitiallyZero() {
        let stats = manager.getStats()
        XCTAssertEqual(stats.totalRequests, 0)
        XCTAssertEqual(stats.cacheHits, 0)
        XCTAssertEqual(stats.cacheMisses, 0)
    }

    // MARK: - Clear All

    func testClearAllRemovesCachedData() async {
        let manifest = Manifest(resources: ["x.png": "https://x.com/x.png"])
        manager.registerManifest(manifest, forPage: "clearPage")

        let waitExpectation = expectation(description: "register completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            waitExpectation.fulfill()
        }
        await fulfillment(of: [waitExpectation], timeout: 2.0)

        XCTAssertNotNil(manager.getCachedManifest(for: "clearPage"))

        manager.clearAll()

        let clearExpectation = expectation(description: "clear completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            clearExpectation.fulfill()
        }
        await fulfillment(of: [clearExpectation], timeout: 2.0)

        XCTAssertNil(manager.getCachedManifest(for: "clearPage"))
    }

    // MARK: - Update Mapping

    func testUpdateMapping() async {
        let manifest = Manifest(resources: [:])
        manager.registerManifest(manifest, forPage: "mappingPage")

        let waitExpectation = expectation(description: "register completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            waitExpectation.fulfill()
        }
        await fulfillment(of: [waitExpectation], timeout: 2.0)

        manager.updateMapping(for: "mappingPage", relativePath: "new.js", url: "https://cdn.example.com/new.js")

        let mapExpectation = expectation(description: "mapping completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            mapExpectation.fulfill()
        }
        await fulfillment(of: [mapExpectation], timeout: 2.0)

        let cached = manager.getCachedManifest(for: "mappingPage")
        XCTAssertEqual(cached?.resources["new.js"], "https://cdn.example.com/new.js")
    }

    func testUpdateMappings() async {
        let manifest = Manifest(resources: [:])
        manager.registerManifest(manifest, forPage: "batchPage")

        let waitExpectation = expectation(description: "register completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            waitExpectation.fulfill()
        }
        await fulfillment(of: [waitExpectation], timeout: 2.0)

        manager.updateMappings(for: "batchPage", mappings: [
            "a.css": "https://cdn.example.com/a.css",
            "b.js": "https://cdn.example.com/b.js"
        ])

        let mapExpectation = expectation(description: "mapping completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            mapExpectation.fulfill()
        }
        await fulfillment(of: [mapExpectation], timeout: 2.0)

        let cached = manager.getCachedManifest(for: "batchPage")
        XCTAssertEqual(cached?.resources["a.css"], "https://cdn.example.com/a.css")
        XCTAssertEqual(cached?.resources["b.js"], "https://cdn.example.com/b.js")
    }

    // MARK: - Singleton

    func testSharedInstance() {
        let instance1 = ManifestCacheManager.shared
        let instance2 = ManifestCacheManager.shared
        XCTAssertTrue(instance1 === instance2)
    }
}
