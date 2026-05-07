import XCTest
@testable import WebBridgeKit

final class WebCompressedCacheStoreTests: XCTestCase {

    func testSharedInstance() {
        let store = WebCompressedCacheStore.shared
        XCTAssertNotNil(store)
    }

    func testWebCacheConfigDefaults() {
        let config = WebCacheConfig()
        XCTAssertTrue(config.enableCompression)
        XCTAssertEqual(config.compressionThreshold, 10_240)
        XCTAssertEqual(config.compressionLevel, 6)
        XCTAssertEqual(config.maxCacheSize, Int64(500 * 1024 * 1024))
        XCTAssertEqual(config.maxFileSize, 50 * 1024 * 1024)
    }

    func testWebCacheConfigCustom() {
        var config = WebCacheConfig()
        config.enableCompression = false
        config.compressionThreshold = 1024
        config.compressionLevel = 9
        XCTAssertFalse(config.enableCompression)
        XCTAssertEqual(config.compressionThreshold, 1024)
        XCTAssertEqual(config.compressionLevel, 9)
    }

    func testCacheErrorDescriptions() {
        let errors: [CacheError] = [.fileTooLarge, .compressionFailed, .decompressionFailed, .notFound]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testCacheErrorFileTooLarge() {
        let error = CacheError.fileTooLarge
        XCTAssertEqual(error.errorDescription, "File size exceeds maximum limit")
    }

    func testCacheErrorCompressionFailed() {
        let error = CacheError.compressionFailed
        XCTAssertEqual(error.errorDescription, "Failed to compress data")
    }

    func testCacheErrorDecompressionFailed() {
        let error = CacheError.decompressionFailed
        XCTAssertEqual(error.errorDescription, "Failed to decompress data")
    }

    func testCacheErrorNotFound() {
        let error = CacheError.notFound
        XCTAssertEqual(error.errorDescription, "Cache entry not found")
    }

    func testExistsNonExistentKey() {
        let store = WebCompressedCacheStore.shared
        XCTAssertFalse(store.exists(key: "nonexistent-\(UUID().uuidString)"))
    }

    func testGetEntryInfoNonExistentKey() {
        let store = WebCompressedCacheStore.shared
        XCTAssertNil(store.getEntryInfo(key: "nonexistent-\(UUID().uuidString)"))
    }

    func testDeleteNonExistentKey() {
        let store = WebCompressedCacheStore.shared
        XCTAssertFalse(store.delete(key: "nonexistent-\(UUID().uuidString)"))
    }

    func testGetAllEntriesInitiallyEmpty() {
        let store = WebCompressedCacheStore.shared
        let entries = store.getAllEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    func testGetEntriesGroupedByDomainEmpty() {
        let store = WebCompressedCacheStore.shared
        let grouped = store.getEntriesGroupedByDomain()
        XCTAssertTrue(grouped.isEmpty)
    }

    func testGetMemoryInfoEmpty() {
        let store = WebCompressedCacheStore.shared
        let info = store.getMemoryInfo()
        XCTAssertEqual(info.totalEntries, 0)
        XCTAssertEqual(info.totalOriginalSize, 0)
        XCTAssertEqual(info.totalCompressedSize, 0)
    }

    func testGetCacheDirectory() {
        let store = WebCompressedCacheStore.shared
        let dir = store.getCacheDirectory()
        XCTAssertTrue(dir.lastPathComponent.contains("WebCompressedCache"))
    }

    func testClearAllNoCrash() {
        let store = WebCompressedCacheStore.shared
        store.clearAll()
    }

    func testConfigDidSet() {
        let store = WebCompressedCacheStore.shared
        let original = store.config.enableCompression
        store.config.enableCompression = !original
        XCTAssertEqual(store.config.enableCompression, !original)
        store.config.enableCompression = original
    }
}
