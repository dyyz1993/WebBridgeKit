import XCTest
@testable import WebBridgeKit

final class WebPermissionManagerTests: XCTestCase {

    // MARK: - Singleton

    func testShared_IsSingleton() {
        let instance1 = WebPermissionManager.shared
        let instance2 = WebPermissionManager.shared
        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - checkLocationPermission

    func testCheckLocationPermission_ReturnsDictWithTypeLocation() {
        let result = WebPermissionManager.shared.checkLocationPermission()
        XCTAssertEqual(result["type"] as? String, "location")
    }

    func testCheckLocationPermission_HasAllRequiredKeys() {
        let result = WebPermissionManager.shared.checkLocationPermission()
        XCTAssertNotNil(result["type"])
        XCTAssertNotNil(result["displayName"])
        XCTAssertNotNil(result["icon"])
        XCTAssertNotNil(result["status"])
        XCTAssertNotNil(result["granted"])
    }

    func testCheckLocationPermission_GrantedIsBool() {
        let result = WebPermissionManager.shared.checkLocationPermission()
        XCTAssertTrue(result["granted"] is Bool)
    }

    func testCheckLocationPermission_DisplayName_IsGeolocation() {
        let result = WebPermissionManager.shared.checkLocationPermission()
        XCTAssertEqual(result["displayName"] as? String, "地理位置")
    }

    // MARK: - checkCameraPermission

    func testCheckCameraPermission_ReturnsTypeCamera() {
        let result = WebPermissionManager.shared.checkCameraPermission()
        XCTAssertEqual(result["type"] as? String, "camera")
    }

    func testCheckCameraPermission_HasAllRequiredKeys() {
        let result = WebPermissionManager.shared.checkCameraPermission()
        XCTAssertNotNil(result["type"])
        XCTAssertNotNil(result["displayName"])
        XCTAssertNotNil(result["icon"])
        XCTAssertNotNil(result["status"])
        XCTAssertNotNil(result["granted"])
    }

    func testCheckCameraPermission_DisplayName_IsCamera() {
        let result = WebPermissionManager.shared.checkCameraPermission()
        XCTAssertEqual(result["displayName"] as? String, "相机权限")
    }

    // MARK: - checkMicrophonePermission

    func testCheckMicrophonePermission_ReturnsTypeMicrophone() {
        let result = WebPermissionManager.shared.checkMicrophonePermission()
        XCTAssertEqual(result["type"] as? String, "microphone")
    }

    func testCheckMicrophonePermission_HasAllRequiredKeys() {
        let result = WebPermissionManager.shared.checkMicrophonePermission()
        XCTAssertNotNil(result["type"])
        XCTAssertNotNil(result["displayName"])
        XCTAssertNotNil(result["icon"])
        XCTAssertNotNil(result["status"])
        XCTAssertNotNil(result["granted"])
    }

    func testCheckMicrophonePermission_DisplayName_IsMicrophone() {
        let result = WebPermissionManager.shared.checkMicrophonePermission()
        XCTAssertEqual(result["displayName"] as? String, "麦克风权限")
    }

    // MARK: - checkSpeechPermission

    func testCheckSpeechPermission_ReturnsTypeSpeech() {
        let result = WebPermissionManager.shared.checkSpeechPermission()
        XCTAssertEqual(result["type"] as? String, "speech")
    }

    func testCheckSpeechPermission_HasAllRequiredKeys() {
        let result = WebPermissionManager.shared.checkSpeechPermission()
        XCTAssertNotNil(result["type"])
        XCTAssertNotNil(result["displayName"])
        XCTAssertNotNil(result["icon"])
        XCTAssertNotNil(result["status"])
        XCTAssertNotNil(result["granted"])
    }

    func testCheckSpeechPermission_DisplayName_IsSpeech() {
        let result = WebPermissionManager.shared.checkSpeechPermission()
        XCTAssertEqual(result["displayName"] as? String, "语音识别")
    }

    // MARK: - checkNotificationPermission (async)

    func testCheckNotificationPermission_CallsCompletion() {
        let expectation = XCTestExpectation(description: "notification permission callback")

        WebPermissionManager.shared.checkNotificationPermission { result in
            XCTAssertNotNil(result["type"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCheckNotificationPermission_ReturnsNotificationType() {
        let expectation = XCTestExpectation(description: "notification type check")

        WebPermissionManager.shared.checkNotificationPermission { result in
            XCTAssertEqual(result["type"] as? String, "notification")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCheckNotificationPermission_HasAllRequiredKeys() {
        let expectation = XCTestExpectation(description: "notification keys check")

        WebPermissionManager.shared.checkNotificationPermission { result in
            XCTAssertNotNil(result["type"])
            XCTAssertNotNil(result["displayName"])
            XCTAssertNotNil(result["icon"])
            XCTAssertNotNil(result["status"])
            XCTAssertNotNil(result["granted"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - checkAllPermissions

    func testCheckAllPermissions_ReturnsFivePermissions() {
        let expectation = XCTestExpectation(description: "all permissions count")

        WebPermissionManager.shared.checkAllPermissions { permissions in
            XCTAssertEqual(permissions.count, 5)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCheckAllPermissions_ContainsAllPermissionTypes() {
        let expectation = XCTestExpectation(description: "all permission types present")

        WebPermissionManager.shared.checkAllPermissions { permissions in
            let types = permissions.compactMap { $0["type"] as? String }
            XCTAssertTrue(types.contains("location"))
            XCTAssertTrue(types.contains("camera"))
            XCTAssertTrue(types.contains("microphone"))
            XCTAssertTrue(types.contains("speech"))
            XCTAssertTrue(types.contains("notification"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCheckAllPermissions_EachEntryHasRequiredKeys() {
        let expectation = XCTestExpectation(description: "all entries have keys")

        WebPermissionManager.shared.checkAllPermissions { permissions in
            for entry in permissions {
                XCTAssertNotNil(entry["type"], "Missing type in \(entry)")
                XCTAssertNotNil(entry["status"], "Missing status in \(entry)")
                XCTAssertNotNil(entry["granted"], "Missing granted in \(entry)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
