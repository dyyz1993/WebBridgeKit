import XCTest
@testable import WebBridgeKit

final class ManifestStoreTests: XCTestCase {

    var store: ManifestStore!

    override func setUp() {
        super.setUp()
        store = ManifestStore()
        store.clearAll()
        Thread.sleep(forTimeInterval: 0.1)
    }

    override func tearDown() {
        store.clearAll()
        Thread.sleep(forTimeInterval: 0.1)
        super.tearDown()
    }

    func testSharedIsSingleton() {
        let s1 = ManifestStore.shared
        let s2 = ManifestStore.shared
        XCTAssertTrue(s1 === s2)
    }

    func testSharedIsNotNil() {
        XCTAssertNotNil(ManifestStore.shared)
    }

    func testSaveAndGetHTMLRoundTrip() {
        let key = "test-html-\(UUID().uuidString)"
        let html = "<html><body>Hello</body></html>"
        store.saveHTML(html, for: key)

        Thread.sleep(forTimeInterval: 0.15)

        let result = store.getHTML(for: key)
        XCTAssertEqual(result, html)
    }

    func testGetHTMLNonExistentKeyReturnsNil() {
        let result = store.getHTML(for: "nonexistent-\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    func testRemoveHTMLThenGetReturnsNil() {
        let key = "remove-html-\(UUID().uuidString)"
        store.saveHTML("content", for: key)
        Thread.sleep(forTimeInterval: 0.15)
        store.removeHTML(for: key)
        Thread.sleep(forTimeInterval: 0.15)

        let result = store.getHTML(for: key)
        XCTAssertNil(result)
    }

    func testSaveAndGetManifestRoundTrip() {
        let key = "test-manifest-\(UUID().uuidString)"
        let manifest = Manifest(resources: ["style.css": "https://cdn.example.com/style.css"], appid: "com.test.app", name: "TestApp")

        store.saveManifest(manifest, for: key)
        Thread.sleep(forTimeInterval: 0.15)

        let result = store.getManifest(for: key)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.appid, "com.test.app")
        XCTAssertEqual(result?.name, "TestApp")
    }

    func testGetManifestNonExistentKeyReturnsNil() {
        let result = store.getManifest(for: "nonexistent-\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    func testRemoveManifestThenGetReturnsNil() {
        let key = "remove-manifest-\(UUID().uuidString)"
        let manifest = Manifest(resources: [:], appid: "com.remove.test")
        store.saveManifest(manifest, for: key)
        Thread.sleep(forTimeInterval: 0.15)
        store.removeManifest(for: key)
        Thread.sleep(forTimeInterval: 0.15)

        let result = store.getManifest(for: key)
        XCTAssertNil(result)
    }

    func testClearAllEmptiesCaches() {
        let htmlKey = "clear-html-\(UUID().uuidString)"
        let manifestKey = "clear-manifest-\(UUID().uuidString)"

        store.saveHTML("data", for: htmlKey)
        store.saveManifest(Manifest(resources: [:], appid: "com.clear"), for: manifestKey)
        Thread.sleep(forTimeInterval: 0.15)

        store.clearAll()
        Thread.sleep(forTimeInterval: 0.15)

        XCTAssertNil(store.getHTML(for: htmlKey))
        XCTAssertNil(store.getManifest(for: manifestKey))
    }

    func testGetAllPageKeysReturnsManifestKeys() {
        let key1 = "pagekey-1-\(UUID().uuidString)"
        let key2 = "pagekey-2-\(UUID().uuidString)"

        store.saveManifest(Manifest(resources: [:], appid: "a"), for: key1)
        store.saveManifest(Manifest(resources: [:], appid: "b"), for: key2)
        Thread.sleep(forTimeInterval: 0.15)

        let keys = store.getAllPageKeys()
        XCTAssertTrue(keys.contains(key1))
        XCTAssertTrue(keys.contains(key2))
    }

    func testSaveHTMLSyncAndGetRoundTrip() {
        let key = "sync-html-\(UUID().uuidString)"
        let html = "<div>sync</div>"
        store.saveHTMLSync(html, for: key)

        let result = store.getHTML(for: key)
        XCTAssertEqual(result, html)
    }

    func testSaveManifestSyncAndGetRoundTrip() {
        let key = "sync-mf-\(UUID().uuidString)"
        let manifest = Manifest(resources: ["a": "b"], appid: "com.sync.test")
        store.saveManifestSync(manifest, for: key)

        let result = store.getManifest(for: key)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.appid, "com.sync.test")
    }

    func testGetCurrentAndSetCurrentManifestRoundTrip() {
        let key = "current-mf-\(UUID().uuidString)"
        let manifest = Manifest(resources: [:], appid: "com.current.test", name: "CurrentApp")
        store.setCurrentManifest(manifest, for: key)
        Thread.sleep(forTimeInterval: 0.15)

        let result = store.getCurrentManifest(for: key)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "CurrentApp")
    }

    func testGetCurrentManifestNonExistentReturnsNil() {
        let result = store.getCurrentManifest(for: "no-current-\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    func testGetManifestByAppIdMatch() {
        let key = "appid-key-\(UUID().uuidString)"
        let manifest = Manifest(resources: [:], appid: "com.appid.lookup")
        store.saveManifest(manifest, for: key)
        Thread.sleep(forTimeInterval: 0.15)

        let result = store.getManifestByAppId("com.appid.lookup")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.key, key)
        XCTAssertEqual(result?.manifest.appid, "com.appid.lookup")
    }

    func testGetManifestByAppIdNoMatchReturnsNil() {
        let result = store.getManifestByAppId("com.nonexistent.\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    func testConformsToManifestCacheManaging() {
        let s: any ManifestCacheManaging = store
        XCTAssertTrue(s is ManifestCacheManaging)
    }
}
