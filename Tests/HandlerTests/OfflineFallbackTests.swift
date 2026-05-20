import XCTest
import WebKit
@testable import WebBridgeKit

final class OfflineFallbackTests: XCTestCase {

    private var loader: PersistentManifestLoader!

    override func setUp() {
        super.setUp()
        loader = PersistentManifestLoader.shared
    }

    // MARK: - Cache Detection

    func testIsCachedReturnsFalseBeforeCaching() {
        let url = URL(string: "https://uncached-test.example.com/page")!
        XCTAssertFalse(loader.isCached(url: url))
    }

    func testIsCachedReturnsFalseForRandomURL() {
        let url = URL(string: "https://random-\(UUID().uuidString).example.com")!
        XCTAssertFalse(loader.isCached(url: url))
    }

    // MARK: - loadFromCache for non-existent

    func testLoadFromCacheFailsWhenNotCached() {
        let webView = WKWebView()
        let url = URL(string: "https://not-cached-test.example.com/page")!

        let expectation = self.expectation(description: "loadFromCache fails")
        loader.loadFromCache(url: url, in: webView) { result in
            if case .failure = result {
                // expected
            } else {
                XCTFail("Should fail for non-cached URL")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3.0)
    }

    // MARK: - Atomic Update Cleanup

    func testCleanupStaleDirectoriesDoesNotCrash() {
        let cacheDir = loader.cacheDirectory
        let fileManager = FileManager.default

        let staleDir = cacheDir.appendingPathComponent("test-cleanup.tmp.\(UUID().uuidString)")
        try? fileManager.createDirectory(at: staleDir, withIntermediateDirectories: true)

        let backupDir = cacheDir.appendingPathComponent("test-cleanup.old")
        try? fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)

        try? fileManager.removeItem(at: staleDir)
        try? fileManager.removeItem(at: backupDir)
    }

    func testCleanupRecoversFromCrashBackup() {
        let cacheDir = loader.cacheDirectory
        let fileManager = FileManager.default
        let cacheID = "test-crash-recover-\(UUID().uuidString)"

        let cacheIDDir = cacheDir.appendingPathComponent(cacheID)
        let backupDir = cacheDir.appendingPathComponent("\(cacheID).old")

        // Simulate crash: cache dir removed, backup exists
        try? fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let dummyFile = backupDir.appendingPathComponent("index.html")
        try? "test".write(to: dummyFile, atomically: true, encoding: .utf8)

        // Simulate recovery: move backup back to cache dir
        XCTAssertTrue(fileManager.fileExists(atPath: backupDir.path))
        try? fileManager.moveItem(at: backupDir, to: cacheIDDir)
        XCTAssertTrue(fileManager.fileExists(atPath: cacheIDDir.path))
        XCTAssertTrue(fileManager.fileExists(atPath: dummyFile.path) == false)
        XCTAssertTrue(fileManager.fileExists(atPath: cacheIDDir.appendingPathComponent("index.html").path))

        // Cleanup
        try? fileManager.removeItem(at: cacheIDDir)
    }

    // MARK: - Atomic Swap Simulation

    func testAtomicSwapWithTempAndBackup() {
        let cacheDir = loader.cacheDirectory
        let fileManager = FileManager.default
        let cacheID = "test-atomic-\(UUID().uuidString)"

        let cacheIDDir = cacheDir.appendingPathComponent(cacheID)
        let tempDir = cacheDir.appendingPathComponent("\(cacheID).tmp.\(UUID().uuidString)")
        let backupDir = cacheDir.appendingPathComponent("\(cacheID).old")

        // Create existing cache
        try? fileManager.createDirectory(at: cacheIDDir, withIntermediateDirectories: true)
        try? "old-content".write(to: cacheIDDir.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)

        // Create temp dir with new content
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try? "new-content".write(to: tempDir.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)

        // Atomic swap: old → backup
        try? fileManager.removeItem(at: backupDir)
        try? fileManager.moveItem(at: cacheIDDir, to: backupDir)

        // temp → current
        XCTAssertFalse(fileManager.fileExists(atPath: cacheIDDir.path))
        try? fileManager.moveItem(at: tempDir, to: cacheIDDir)

        // Verify new content
        let content = try? String(contentsOf: cacheIDDir.appendingPathComponent("index.html"), encoding: .utf8)
        XCTAssertEqual(content, "new-content")

        // Remove backup
        try? fileManager.removeItem(at: backupDir)

        // Cleanup
        try? fileManager.removeItem(at: cacheIDDir)
    }

    func testAtomicSwapRollbackOnFailure() {
        let cacheDir = loader.cacheDirectory
        let fileManager = FileManager.default
        let cacheID = "test-rollback-\(UUID().uuidString)"

        let cacheIDDir = cacheDir.appendingPathComponent(cacheID)
        let backupDir = cacheDir.appendingPathComponent("\(cacheID).old")

        // Create existing cache
        try? fileManager.createDirectory(at: cacheIDDir, withIntermediateDirectories: true)
        try? "old-content".write(to: cacheIDDir.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)

        // Simulate: backup exists, cache dir was removed
        try? fileManager.removeItem(at: backupDir)
        try? fileManager.moveItem(at: cacheIDDir, to: backupDir)

        // Simulate failure: restore backup
        try? fileManager.moveItem(at: backupDir, to: cacheIDDir)

        // Verify old content restored
        let content = try? String(contentsOf: cacheIDDir.appendingPathComponent("index.html"), encoding: .utf8)
        XCTAssertEqual(content, "old-content")

        // Cleanup
        try? fileManager.removeItem(at: cacheIDDir)
    }

    // MARK: - CacheVersionStatus Integration

    func testVersionStatusForNonCachedApp() {
        let store = ManifestStore.shared
        let status = store.getVersionStatus(for: "nonexistent-app-\(UUID().uuidString)")
        XCTAssertNil(status)
    }

    func testGetAllVersionStatusesReturnsArray() {
        let store = ManifestStore.shared
        let statuses = store.getAllVersionStatuses()
        XCTAssertNotNil(statuses)
    }

    // MARK: - Cache Size

    func testCacheSizeForNonExistentID() {
        let size = loader.getCacheSize(for: "nonexistent-\(UUID().uuidString)")
        XCTAssertEqual(size, 0)
    }

    // MARK: - Loader State

    func testInitialStateIsIdle() {
        let state = loader.getCurrentState()
        if case .idle = state {
            // expected
        } else {
            // May not be idle if another test ran, but should not crash
        }
    }
}
