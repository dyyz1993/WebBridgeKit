import XCTest
@testable import WebBridgeKit

final class ManifestStoreIntegrityTests: XCTestCase {

    var store: ManifestStore!

    override func setUp() {
        super.setUp()
        store = ManifestStore.shared
        store.clearAll()
        Thread.sleep(forTimeInterval: 0.1)
    }

    override func tearDown() {
        store.clearAll()
        Thread.sleep(forTimeInterval: 0.1)
        super.tearDown()
    }

    private func makeManifest(appid: String = "com.integrity.test") -> Manifest {
        Manifest(
            resources: ["index.html": "https://cdn.example.com/index.html"],
            appid: appid,
            name: "IntegrityTestApp"
        )
    }

    func testUnmodifiedManifest_passesIntegrityCheck() {
        let key = "intact-\(UUID().uuidString)"
        let manifest = makeManifest()
        store.saveManifestSync(manifest, for: key)

        guard let entry = store.manifestCache[key] else {
            XCTFail("Entry should exist after saveManifestSync")
            return
        }

        let isValid = store.verifyManifestIntegrity(entry)
        XCTAssertTrue(isValid)
    }

    func testModifiedManifest_failsIntegrityCheck() {
        let key = "tampered-\(UUID().uuidString)"
        let manifest = makeManifest()
        store.saveManifestSync(manifest, for: key)

        guard let originalEntry = store.manifestCache[key] else {
            XCTFail("Entry should exist after saveManifestSync")
            return
        }

        let tamperedManifest = makeManifest(appid: "com.tampered.evil")
        let tamperedEntry = ManifestStore.ManifestCacheEntry(
            manifest: tamperedManifest,
            timestamp: originalEntry.timestamp,
            contentHash: originalEntry.contentHash
        )

        let isValid = store.verifyManifestIntegrity(tamperedEntry)
        XCTAssertFalse(isValid)
    }

    func testMultipleUnmodifiedManifests_passIntegrityCheck() {
        let key1 = "batch-ok-1-\(UUID().uuidString)"
        let key2 = "batch-ok-2-\(UUID().uuidString)"
        let key3 = "batch-ok-3-\(UUID().uuidString)"

        store.saveManifestSync(makeManifest(appid: "com.batch.1"), for: key1)
        store.saveManifestSync(makeManifest(appid: "com.batch.2"), for: key2)
        store.saveManifestSync(makeManifest(appid: "com.batch.3"), for: key3)

        let result = store.verifyAllManifestsIntegrity()
        XCTAssertEqual(result.intact, 3)
        XCTAssertEqual(result.tampered, 0)
    }

    func testMixedIntegrityBatch_returnsCorrectCounts() {
        let intactKey = "mix-ok-\(UUID().uuidString)"
        let tamperedKey = "mix-bad-\(UUID().uuidString)"

        store.saveManifestSync(makeManifest(appid: "com.mix.ok"), for: intactKey)
        store.saveManifestSync(makeManifest(appid: "com.mix.original"), for: tamperedKey)

        guard let originalEntry = store.manifestCache[tamperedKey] else {
            XCTFail("Entry should exist")
            return
        }
        let tamperedManifest = makeManifest(appid: "com.mix.tampered")
        store.manifestCache[tamperedKey] = ManifestStore.ManifestCacheEntry(
            manifest: tamperedManifest,
            timestamp: originalEntry.timestamp,
            contentHash: originalEntry.contentHash
        )

        let result = store.verifyAllManifestsIntegrity()
        XCTAssertEqual(result.intact, 1)
        XCTAssertEqual(result.tampered, 1)
    }

    func testTamperedManifests_areAutoRemoved() {
        let intactKey = "auto-rm-ok-\(UUID().uuidString)"
        let tamperedKey = "auto-rm-bad-\(UUID().uuidString)"

        store.saveManifestSync(makeManifest(appid: "com.autorm.ok"), for: intactKey)
        store.saveManifestSync(makeManifest(appid: "com.autorm.original"), for: tamperedKey)

        guard let originalEntry = store.manifestCache[tamperedKey] else {
            XCTFail("Entry should exist")
            return
        }
        let tamperedManifest = makeManifest(appid: "com.autorm.tampered")
        store.manifestCache[tamperedKey] = ManifestStore.ManifestCacheEntry(
            manifest: tamperedManifest,
            timestamp: originalEntry.timestamp,
            contentHash: originalEntry.contentHash
        )

        XCTAssertNotNil(store.manifestCache[tamperedKey])

        _ = store.verifyAllManifestsIntegrity()

        XCTAssertNil(store.manifestCache[tamperedKey], "Tampered manifest should be auto-removed")
        XCTAssertNotNil(store.manifestCache[intactKey], "Intact manifest should remain")
    }

    func testEmptyCache_returnsZeroCounts() {
        let result = store.verifyAllManifestsIntegrity()
        XCTAssertEqual(result.total, 0)
        XCTAssertEqual(result.intact, 0)
        XCTAssertEqual(result.tampered, 0)
    }

    func testSameManifestContent_producesSameHash() {
        let key1 = "hash-a-\(UUID().uuidString)"
        let key2 = "hash-b-\(UUID().uuidString)"
        let manifest = makeManifest(appid: "com.same.content")

        store.saveManifestSync(manifest, for: key1)
        store.saveManifestSync(manifest, for: key2)

        guard let entry1 = store.manifestCache[key1],
              let entry2 = store.manifestCache[key2] else {
            XCTFail("Entries should exist")
            return
        }

        XCTAssertEqual(entry1.contentHash, entry2.contentHash)
    }

    func testDifferentManifestContent_producesDifferentHash() {
        let key1 = "diff-a-\(UUID().uuidString)"
        let key2 = "diff-b-\(UUID().uuidString)"

        store.saveManifestSync(makeManifest(appid: "com.diff.a"), for: key1)
        store.saveManifestSync(makeManifest(appid: "com.diff.b"), for: key2)

        guard let entry1 = store.manifestCache[key1],
              let entry2 = store.manifestCache[key2] else {
            XCTFail("Entries should exist")
            return
        }

        XCTAssertNotEqual(entry1.contentHash, entry2.contentHash)
    }
}
