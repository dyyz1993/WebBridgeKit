import XCTest
@testable import WebBridgeKit

final class EnvironmentInfoTests: XCTestCase {

    func testCreateInstanceDoesNotCrash() {
        let env = EnvironmentInfo()
        XCTAssertNotNil(env)
    }

    func testAppVersionIsNotEmpty() {
        let env = EnvironmentInfo()
        XCTAssertFalse(env.appVersion.isEmpty)
    }

    func testBuildNumberIsNotEmpty() {
        let env = EnvironmentInfo()
        XCTAssertFalse(env.buildNumber.isEmpty)
    }

    func testBundleIdentifierIsNotEmpty() {
        let env = EnvironmentInfo()
        XCTAssertFalse(env.bundleIdentifier.isEmpty)
    }

    func testAppNameIsNotEmpty() {
        let env = EnvironmentInfo()
        XCTAssertFalse(env.appName.isEmpty)
    }

    func testDeviceModelIsNotEmpty() {
        let env = EnvironmentInfo()
        XCTAssertFalse(env.deviceModel.isEmpty)
    }

    func testDeviceNameIsNotEmpty() {
        let env = EnvironmentInfo()
        XCTAssertFalse(env.deviceName.isEmpty)
    }

    func testSystemNameIsNotEmpty() {
        let env = EnvironmentInfo()
        XCTAssertFalse(env.systemName.isEmpty)
    }

    func testSystemVersionIsNotEmpty() {
        let env = EnvironmentInfo()
        XCTAssertFalse(env.systemVersion.isEmpty)
    }

    func testScreenWidthIsPositive() {
        let env = EnvironmentInfo()
        XCTAssertGreaterThan(env.screenBounds.width, 0)
    }

    func testScreenHeightIsPositive() {
        let env = EnvironmentInfo()
        XCTAssertGreaterThan(env.screenBounds.height, 0)
    }

    func testScreenScaleIsPositive() {
        let env = EnvironmentInfo()
        XCTAssertGreaterThan(env.screenScale, 0)
    }

    func testPhysicalMemoryIsPositive() {
        let env = EnvironmentInfo()
        XCTAssertGreaterThan(env.physicalMemory, 0)
    }

    func testFreeMemoryIsNonNegative() {
        let env = EnvironmentInfo()
        XCTAssertGreaterThanOrEqual(env.freeMemory, 0)
    }

    func testTotalDiskSpaceIsPositive() {
        let env = EnvironmentInfo()
        XCTAssertGreaterThan(env.totalDiskSpace, 0)
    }

    func testFreeDiskSpaceIsNonNegative() {
        let env = EnvironmentInfo()
        XCTAssertGreaterThanOrEqual(env.freeDiskSpace, 0)
    }

    func testNetworkTypeIsNotEmpty() {
        let env = EnvironmentInfo()
        XCTAssertFalse(env.networkType.isEmpty)
        XCTAssertTrue(["WiFi", "Cellular", "Unknown"].contains(env.networkType))
    }

    func testIsConnectedIsTrue() {
        let env = EnvironmentInfo()
        XCTAssertTrue(env.isConnected)
    }

    func testCapturedAtIsRecent() {
        let env = EnvironmentInfo()
        let diff = abs(env.capturedAt.timeIntervalSinceNow)
        XCTAssertLessThan(diff, 10.0)
    }

    func testSummaryContainsAppName() {
        let env = EnvironmentInfo()
        XCTAssertTrue(env.summary.contains(env.appName))
    }

    func testSummaryContainsMemory() {
        let env = EnvironmentInfo()
        XCTAssertTrue(env.summary.contains("Memory:"))
    }

    func testSummaryContainsDisk() {
        let env = EnvironmentInfo()
        XCTAssertTrue(env.summary.contains("Disk:"))
    }

    func testSummaryContainsNetwork() {
        let env = EnvironmentInfo()
        XCTAssertTrue(env.summary.contains("Network:"))
    }

    func testDebugStringContainsEnvironmentInfoHeader() {
        let env = EnvironmentInfo()
        XCTAssertTrue(env.debugString.contains("=== Environment Info ==="))
    }

    func testDebugStringContainsAppInfo() {
        let env = EnvironmentInfo()
        XCTAssertTrue(env.debugString.contains("App: \(env.appName)"))
    }

    func testDebugStringContainsVersion() {
        let env = EnvironmentInfo()
        XCTAssertTrue(env.debugString.contains("Version: \(env.appVersion)"))
    }

    func testDebugStringContainsDeviceModel() {
        let env = EnvironmentInfo()
        XCTAssertTrue(env.debugString.contains("Device: \(env.deviceModel)"))
    }

    func testDebugStringContainsFooter() {
        let env = EnvironmentInfo()
        XCTAssertTrue(env.debugString.contains("========================"))
    }

    func testJsonDictContainsRequiredKeys() {
        let env = EnvironmentInfo()
        let dict = env.jsonDict

        XCTAssertNotNil(dict["app_version"] as? String)
        XCTAssertNotNil(dict["build_number"] as? String)
        XCTAssertNotNil(dict["bundle_id"] as? String)
        XCTAssertNotNil(dict["device_model"] as? String)
        XCTAssertNotNil(dict["os_version"] as? String)
        XCTAssertNotNil(dict["screen"] as? String)
        XCTAssertNotNil(dict["physical_memory"] as? UInt64)
        XCTAssertNotNil(dict["free_memory"] as? UInt64)
        XCTAssertNotNil(dict["total_disk"] as? UInt64)
        XCTAssertNotNil(dict["free_disk"] as? UInt64)
        XCTAssertNotNil(dict["network_type"] as? String)
        XCTAssertNotNil(dict["connected"] as? Bool)
        XCTAssertNotNil(dict["captured_at"] as? String)
    }

    func testJsonDictConnectedIsTrue() {
        let env = EnvironmentInfo()
        XCTAssertEqual(env.jsonDict["connected"] as? Bool, true)
    }

    func testJsonDictHasCorrectKeyCount() {
        let env = EnvironmentInfo()
        XCTAssertGreaterThanOrEqual(env.jsonDict.count, 12)
    }
}
