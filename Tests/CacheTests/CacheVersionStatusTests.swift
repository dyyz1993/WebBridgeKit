import XCTest
@testable import WebBridgeKit

final class CacheVersionStatusTests: XCTestCase {

    // MARK: - CacheUpdateState

    func testAllUpdateStatesExist() {
        let states: [CacheUpdateState] = [
            .upToDate,
            .updateAvailable,
            .updating,
            .updateFailed,
            .notCached,
            .offline
        ]
        XCTAssertEqual(states.count, 6)
    }

    func testUpdateStateRawValues() {
        XCTAssertEqual(CacheUpdateState.upToDate.rawValue, "upToDate")
        XCTAssertEqual(CacheUpdateState.updateAvailable.rawValue, "updateAvailable")
        XCTAssertEqual(CacheUpdateState.updating.rawValue, "updating")
        XCTAssertEqual(CacheUpdateState.updateFailed.rawValue, "updateFailed")
        XCTAssertEqual(CacheUpdateState.notCached.rawValue, "notCached")
        XCTAssertEqual(CacheUpdateState.offline.rawValue, "offline")
    }

    // MARK: - CacheVersionStatus Init

    func testInitWithAllFields() {
        let now = Date()
        let status = CacheVersionStatus(
            cacheID: "com.test.app",
            name: "Test App",
            iconURL: "https://example.com/icon.png",
            currentVersion: "1.0.0",
            latestVersion: "2.0.0",
            updateState: .updateAvailable,
            cacheSize: 1024000,
            lastAccessed: now,
            lastChecked: now
        )
        XCTAssertEqual(status.cacheID, "com.test.app")
        XCTAssertEqual(status.name, "Test App")
        XCTAssertEqual(status.iconURL, "https://example.com/icon.png")
        XCTAssertEqual(status.currentVersion, "1.0.0")
        XCTAssertEqual(status.latestVersion, "2.0.0")
        XCTAssertEqual(status.updateState, .updateAvailable)
        XCTAssertEqual(status.cacheSize, 1024000)
        XCTAssertEqual(status.lastAccessed, now)
        XCTAssertEqual(status.lastChecked, now)
    }

    func testInitMinimal() {
        let status = CacheVersionStatus(
            cacheID: "minimal",
            updateState: .notCached
        )
        XCTAssertEqual(status.cacheID, "minimal")
        XCTAssertNil(status.name)
        XCTAssertNil(status.iconURL)
        XCTAssertNil(status.currentVersion)
        XCTAssertNil(status.latestVersion)
        XCTAssertEqual(status.updateState, .notCached)
        XCTAssertEqual(status.cacheSize, 0)
        XCTAssertNil(status.lastAccessed)
        XCTAssertNil(status.lastChecked)
    }

    // MARK: - Computed Properties

    func testIsOfflineAvailable_WhenCached() {
        let status = CacheVersionStatus(
            cacheID: "test",
            currentVersion: "1.0.0",
            updateState: .upToDate,
            cacheSize: 5000
        )
        XCTAssertTrue(status.isOfflineAvailable)
    }

    func testIsOfflineAvailable_WhenNotCached() {
        let status = CacheVersionStatus(
            cacheID: "test",
            updateState: .notCached,
            cacheSize: 0
        )
        XCTAssertFalse(status.isOfflineAvailable)
    }

    func testIsOfflineAvailable_ZeroSize() {
        let status = CacheVersionStatus(
            cacheID: "test",
            currentVersion: "1.0.0",
            updateState: .upToDate,
            cacheSize: 0
        )
        XCTAssertFalse(status.isOfflineAvailable)
    }

    func testIsOfflineAvailable_NoVersion() {
        let status = CacheVersionStatus(
            cacheID: "test",
            updateState: .upToDate,
            cacheSize: 5000
        )
        XCTAssertFalse(status.isOfflineAvailable)
    }

    func testHasUpdate_WhenUpdateAvailable() {
        let status = CacheVersionStatus(
            cacheID: "test",
            currentVersion: "1.0.0",
            latestVersion: "2.0.0",
            updateState: .updateAvailable
        )
        XCTAssertTrue(status.hasUpdate)
    }

    func testHasUpdate_WhenUpToDate() {
        let status = CacheVersionStatus(
            cacheID: "test",
            currentVersion: "1.0.0",
            updateState: .upToDate
        )
        XCTAssertFalse(status.hasUpdate)
    }

    func testHasUpdate_WhenOffline() {
        let status = CacheVersionStatus(
            cacheID: "test",
            currentVersion: "1.0.0",
            updateState: .offline
        )
        XCTAssertFalse(status.hasUpdate)
    }

    func testHasUpdate_WhenUpdating() {
        let status = CacheVersionStatus(
            cacheID: "test",
            updateState: .updating
        )
        XCTAssertFalse(status.hasUpdate)
    }

    // MARK: - Version Description

    func testVersionDescription_UpToDate() {
        let status = CacheVersionStatus(
            cacheID: "test",
            currentVersion: "1.0.0",
            updateState: .upToDate
        )
        XCTAssertTrue(status.versionDescription.contains("1.0.0"))
        XCTAssertTrue(status.versionDescription.contains("已是最新"))
    }

    func testVersionDescription_UpdateAvailable() {
        let status = CacheVersionStatus(
            cacheID: "test",
            currentVersion: "1.0.0",
            latestVersion: "2.0.0",
            updateState: .updateAvailable
        )
        XCTAssertTrue(status.versionDescription.contains("1.0.0"))
        XCTAssertTrue(status.versionDescription.contains("2.0.0"))
        XCTAssertTrue(status.versionDescription.contains("→"))
    }

    func testVersionDescription_Offline() {
        let status = CacheVersionStatus(
            cacheID: "test",
            currentVersion: "1.5.0",
            updateState: .offline
        )
        XCTAssertTrue(status.versionDescription.contains("1.5.0"))
        XCTAssertTrue(status.versionDescription.contains("离线"))
    }

    func testVersionDescription_NotCached() {
        let status = CacheVersionStatus(
            cacheID: "test",
            updateState: .notCached
        )
        XCTAssertTrue(status.versionDescription.contains("未缓存"))
    }

    func testVersionDescription_Updating() {
        let status = CacheVersionStatus(
            cacheID: "test",
            updateState: .updating
        )
        XCTAssertTrue(status.versionDescription.contains("正在更新"))
    }

    func testVersionDescription_UpdateFailed() {
        let status = CacheVersionStatus(
            cacheID: "test",
            currentVersion: "1.0.0",
            updateState: .updateFailed
        )
        XCTAssertTrue(status.versionDescription.contains("1.0.0"))
        XCTAssertTrue(status.versionDescription.contains("更新失败"))
    }

    func testVersionDescription_MissingVersionShowsPlaceholder() {
        let status = CacheVersionStatus(
            cacheID: "test",
            updateState: .upToDate
        )
        XCTAssertTrue(status.versionDescription.contains("?"))
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let now = Date()
        let original = CacheVersionStatus(
            cacheID: "com.test.app",
            name: "Test",
            iconURL: "https://example.com/icon.png",
            currentVersion: "1.0.0",
            latestVersion: "2.0.0",
            updateState: .updateAvailable,
            cacheSize: 9999,
            lastAccessed: now,
            lastChecked: now
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CacheVersionStatus.self, from: data)
        XCTAssertEqual(decoded.cacheID, original.cacheID)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.iconURL, original.iconURL)
        XCTAssertEqual(decoded.currentVersion, original.currentVersion)
        XCTAssertEqual(decoded.latestVersion, original.latestVersion)
        XCTAssertEqual(decoded.updateState, original.updateState)
        XCTAssertEqual(decoded.cacheSize, original.cacheSize)
    }

    func testCodableRoundTrip_Minimal() throws {
        let original = CacheVersionStatus(
            cacheID: "minimal",
            updateState: .notCached
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CacheVersionStatus.self, from: data)
        XCTAssertEqual(decoded.cacheID, "minimal")
        XCTAssertNil(decoded.name)
        XCTAssertNil(decoded.currentVersion)
        XCTAssertNil(decoded.latestVersion)
        XCTAssertEqual(decoded.updateState, .notCached)
        XCTAssertEqual(decoded.cacheSize, 0)
    }

    func testCodableJSONKeys() throws {
        let status = CacheVersionStatus(
            cacheID: "com.test.app",
            name: "Test",
            updateState: .upToDate,
            cacheSize: 1234
        )
        let data = try JSONEncoder().encode(status)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["cacheID"] as? String, "com.test.app")
        XCTAssertEqual(json?["name"] as? String, "Test")
        XCTAssertEqual(json?["cacheSize"] as? Int64, 1234)
        XCTAssertEqual(json?["updateState"] as? String, "upToDate")
    }
}
