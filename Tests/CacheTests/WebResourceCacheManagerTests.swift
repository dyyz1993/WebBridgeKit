import XCTest
@testable import WebBridgeKit

final class WebResourceCacheManagerTests: XCTestCase {

    private var manager: WebResourceCacheManager!

    override func setUp() {
        super.setUp()
        manager = WebResourceCacheManager.shared
    }

    override func tearDown() async throws {
        manager.clearAll()
        try await super.tearDown()
    }

    // MARK: - Singleton

    func testSharedInstance() {
        let instance1 = WebResourceCacheManager.shared
        let instance2 = WebResourceCacheManager.shared
        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - Create Cache Space

    func testCreateCacheSpace() {
        let url = URL(string: "https://example.com/page1")!
        let cacheID = manager.createCacheSpace(for: url)

        XCTAssertFalse(cacheID.isEmpty)
        XCTAssertTrue(manager.cacheSpaceExists(cacheID: cacheID))
    }

    func testCreateCacheSpaceReturnsSameIDForSameURL() {
        let url = URL(string: "https://example.com/same")!
        let id1 = manager.createCacheSpace(for: url)
        let id2 = manager.createCacheSpace(for: url)

        XCTAssertEqual(id1, id2)
    }

    func testCreateCacheSpaceDifferentURLsGetDifferentIDs() {
        let url1 = URL(string: "https://example.com/a")!
        let url2 = URL(string: "https://example.com/b")!

        let id1 = manager.createCacheSpace(for: url1)
        let id2 = manager.createCacheSpace(for: url2)

        XCTAssertNotEqual(id1, id2)
    }

    // MARK: - Get Cache ID

    func testGetCacheIDForExistingURL() {
        let url = URL(string: "https://example.com/cached")!
        let createdID = manager.createCacheSpace(for: url)
        let retrievedID = manager.getCacheID(for: url)

        XCTAssertEqual(createdID, retrievedID)
    }

    func testGetCacheIDReturnsNilForUnknownURL() {
        let url = URL(string: "https://unknown.example.com/notfound")!
        let result = manager.getCacheID(for: url)
        XCTAssertNil(result)
    }

    // MARK: - Get URL for Cache ID

    func testGetURLForCacheID() {
        let url = URL(string: "https://example.com/reverse")!
        let cacheID = manager.createCacheSpace(for: url)
        let retrievedURL = manager.getURL(for: cacheID)

        XCTAssertEqual(retrievedURL, url)
    }

    func testGetURLReturnsNilForUnknownCacheID() {
        let result = manager.getURL(for: "nonexistent-id")
        XCTAssertNil(result)
    }

    // MARK: - Cache Space Exists

    func testCacheSpaceExistsForCreatedSpace() {
        let url = URL(string: "https://example.com/exists")!
        let cacheID = manager.createCacheSpace(for: url)

        XCTAssertTrue(manager.cacheSpaceExists(cacheID: cacheID))
    }

    func testCacheSpaceNotExistsForUnknownID() {
        XCTAssertFalse(manager.cacheSpaceExists(cacheID: "definitely-not-a-real-id"))
    }

    // MARK: - Store and Get Resource

    func testStoreAndGetResource() throws {
        let url = URL(string: "https://example.com/resource-test")!
        let cacheID = manager.createCacheSpace(for: url)

        let testData = Data("test content".utf8)
        try manager.storeResource(
            cacheID: cacheID,
            relativePath: "resources/test.txt",
            data: testData,
            mimeType: "text/plain"
        )

        let result = manager.getResource(cacheID: cacheID, relativePath: "resources/test.txt")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.data, testData)
        XCTAssertEqual(result?.mimeType, "text/plain")
    }

    func testGetResourceReturnsNilForNonExistent() {
        let url = URL(string: "https://example.com/no-resource")!
        let cacheID = manager.createCacheSpace(for: url)

        let result = manager.getResource(cacheID: cacheID, relativePath: "nonexistent.txt")
        XCTAssertNil(result)
    }

    func testStoreMultipleResources() throws {
        let url = URL(string: "https://example.com/multi-resource")!
        let cacheID = manager.createCacheSpace(for: url)

        try manager.storeResource(cacheID: cacheID, relativePath: "a.css", data: Data("css".utf8), mimeType: "text/css")
        try manager.storeResource(cacheID: cacheID, relativePath: "b.js", data: Data("js".utf8), mimeType: "application/javascript")
        try manager.storeResource(cacheID: cacheID, relativePath: "c.png", data: Data("png".utf8), mimeType: "image/png")

        XCTAssertNotNil(manager.getResource(cacheID: cacheID, relativePath: "a.css"))
        XCTAssertNotNil(manager.getResource(cacheID: cacheID, relativePath: "b.js"))
        XCTAssertNotNil(manager.getResource(cacheID: cacheID, relativePath: "c.png"))
    }

    func testStoreResourceThrowsForNonExistentCacheSpace() {
        XCTAssertThrowsError(
            try manager.storeResource(
                cacheID: "fake-id",
                relativePath: "test.txt",
                data: Data("x".utf8),
                mimeType: "text/plain"
            )
        )
    }

    // MARK: - Manifest Management

    func testSaveAndLoadManifest() {
        let url = URL(string: "https://example.com/manifest-test")!
        let cacheID = manager.createCacheSpace(for: url)

        let manifest = WebResourceCacheManager.WebResourceManifest(
            url: url.absoluteString,
            htmlContent: "<html></html>",
            resources: [
                "style.css": WebResourceCacheManager.ResourceInfo(
                    relativePath: "style.css",
                    originalURL: "https://example.com/style.css",
                    mimeType: "text/css",
                    fileSize: 100
                )
            ]
        )

        manager.saveManifest(cacheID: cacheID, manifest: manifest)

        let loaded = manager.loadManifest(for: cacheID)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.url, url.absoluteString)
        XCTAssertEqual(loaded?.htmlContent, "<html></html>")
        XCTAssertEqual(loaded?.resources["style.css"]?.mimeType, "text/css")
    }

    func testLoadManifestReturnsNilForNonExistent() {
        let loaded = manager.loadManifest(for: "nonexistent-manifest-id")
        XCTAssertNil(loaded)
    }

    // MARK: - Cache Stats

    func testGetCacheStatsReturnsNilForUnknownID() {
        let stats = manager.getCacheStats(cacheID: "nonexistent-stats-id")
        XCTAssertNil(stats)
    }

    func testGetCacheStatsReturnsStatsForCreatedSpace() {
        let url = URL(string: "https://example.com/stats-test")!
        let cacheID = manager.createCacheSpace(for: url)

        let stats = manager.getCacheStats(cacheID: cacheID)
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.cacheID, cacheID)
        XCTAssertEqual(stats?.url, url)
    }

    // MARK: - Remove Cache Space

    func testRemoveCacheSpace() async {
        let url = URL(string: "https://example.com/remove-test")!
        let cacheID = manager.createCacheSpace(for: url)
        XCTAssertTrue(manager.cacheSpaceExists(cacheID: cacheID))

        manager.removeCacheSpace(cacheID: cacheID)

        let removeExpectation = expectation(description: "remove completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            removeExpectation.fulfill()
        }
        await fulfillment(of: [removeExpectation], timeout: 2.0)

        XCTAssertFalse(manager.cacheSpaceExists(cacheID: cacheID))
        XCTAssertNil(manager.getCacheID(for: url))
    }

    // MARK: - Clear All

    func testClearAllRemovesAllSpaces() async {
        let url1 = URL(string: "https://example.com/clear1")!
        let url2 = URL(string: "https://example.com/clear2")!

        let id1 = manager.createCacheSpace(for: url1)
        let id2 = manager.createCacheSpace(for: url2)

        manager.clearAll()

        let clearExpectation = expectation(description: "clear completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            clearExpectation.fulfill()
        }
        await fulfillment(of: [clearExpectation], timeout: 3.0)

        XCTAssertFalse(manager.cacheSpaceExists(cacheID: id1))
        XCTAssertFalse(manager.cacheSpaceExists(cacheID: id2))
    }

    // MARK: - Global Stats

    func testGetGlobalStatsReturnsTuple() {
        let (totalSize, totalFiles) = manager.getGlobalStats()
        XCTAssertGreaterThanOrEqual(totalSize, 0)
        XCTAssertGreaterThanOrEqual(totalFiles, 0)
    }

    func testGetAllCacheStatsReturnsEmptyForNoCaches() async {
        manager.clearAll()

        let clearExpectation = expectation(description: "clear completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            clearExpectation.fulfill()
        }
        await fulfillment(of: [clearExpectation], timeout: 3.0)

        let allStats = manager.getAllCacheStats()
        XCTAssertTrue(allStats.isEmpty)
    }
}
