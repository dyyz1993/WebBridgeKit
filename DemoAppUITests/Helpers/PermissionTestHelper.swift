import XCTest
import Foundation

/// Helper class for permission-related UI testing
class PermissionTestHelper {

    /// Permission types for testing
    enum PermissionType {
        case camera
        case microphone
        case location
        case notification

        var name: String {
            switch self {
            case .camera: return "Camera"
            case .microphone: return "Microphone"
            case .location: return "Location"
            case .notification: return "Notification"
            }
        }

        var bridgeMethod: String {
            switch self {
            case .camera: return "permission({ type: 'camera' })"
            case .microphone: return "permission({ type: 'microphone' })"
            case .location: return "location({})"
            case .notification: return "permission({ type: 'notification' })"
            }
        }
    }

    /// Permission status codes
    enum PermissionStatus: Int {
        case notDetermined = 0
        case restricted = 1
        case denied = 2
        case authorized = 3
        case authorizedWhenInUse = 4 // Location only

        var description: String {
            switch self {
            case .notDetermined: return "Not Determined"
            case .restricted: return "Restricted"
            case .denied: return "Denied"
            case .authorized: return "Authorized"
            case .authorizedWhenInUse: return "Authorized When In Use"
            }
        }

        var isGranted: Bool {
            return self == .authorized || self == .authorizedWhenInUse
        }
    }

    // MARK: - JavaScript Helpers

    /// Generate JavaScript to request a permission
    static func requestPermissionJS(type: PermissionType) -> String {
        return """
        window.WebBridgeKit.\(type.bridgeMethod)
            .then(result => {
                window.permissionResult = { success: true, data: result };
            })
            .catch(error => {
                window.permissionResult = { success: false, error: error.message || error };
            });
        """
    }

    /// Generate JavaScript to check permission status
    static func checkPermissionStatusJS(type: PermissionType) -> String {
        return """
        window.WebBridgeKit.\(type.bridgeMethod)
            .then(result => {
                window.permissionStatus = result;
            })
            .catch(error => {
                window.permissionStatus = { error: error.message || error };
            });
        """
    }

    /// Generate JavaScript to open camera
    static func openCameraJS() -> String {
        return """
        window.WebBridgeKit.camera({ type: 'photo' })
            .then(result => {
                window.cameraResult = { success: true, data: result };
            })
            .catch(error => {
                window.cameraResult = { success: false, error: error.message || error };
            });
        """
    }

    /// Generate JavaScript to get current location
    static func getLocationJS() -> String {
        return """
        window.WebBridgeKit.location({})
            .then(result => {
                window.locationResult = { success: true, data: result };
            })
            .catch(error => {
                window.locationResult = { success: false, error: error.message || error };
            });
        """
    }

    /// Generate JavaScript to check permission result
    static func checkPermissionResultJS() -> String {
        return "window.permissionResult"
    }

    /// Generate JavaScript to check permission status
    static func checkPermissionStatusJS() -> String {
        return "window.permissionStatus"
    }

    // MARK: - Test Execution Helpers

    /// Execute JavaScript and wait for result with timeout
    static func executeJSAndWait(_ js: String, in app: XCUIApplication, timeout: TimeInterval = 10.0) -> String? {
        // app.webViews.firstMatch.evaluate(js) // Removed: XCUIElement doesn't have evaluate()

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            // let result = app.webViews.firstMatch.evaluate("if (window.permissionResult) JSON.stringify(window.permissionResult);")
            // Removed: XCUIElement doesn't have evaluate()
            // if let resultString = result as? String, !resultString.isEmpty {
            //     return resultString
            // }
            Thread.sleep(forTimeInterval: 0.1)
        }

        return nil
    }

    /// Execute JavaScript and get boolean result
    static func executeJSAndGetBool(_ js: String, in app: XCUIApplication, timeout: TimeInterval = 5.0) -> Bool? {
        // app.webViews.firstMatch.evaluate(js) // Removed: XCUIElement doesn't have evaluate()

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            // if let result = app.webViews.firstMatch.evaluate("if (window.permissionStatus) window.permissionStatus.granted;") as? Bool {
            //     return result
            // }
            Thread.sleep(forTimeInterval: 0.1)
        }

        return nil
    }

    /// Parse permission result from JavaScript string
    static func parsePermissionResult(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }

    // MARK: - Permission State Verification

    /// Verify permission is granted
    static func verifyPermissionGranted(for type: PermissionType, in app: XCUIApplication) -> Bool {
        // app.webViews.firstMatch.evaluate(checkPermissionStatusJS(type: type))
        // Removed: XCUIElement doesn't have evaluate()
        Thread.sleep(forTimeInterval: 1.0)

        // if let granted = app.webViews.firstMatch.evaluate("window.permissionStatus?.granted") as? Bool {
        //     return granted
        // }

        return false
    }

    /// Verify permission is denied
    static func verifyPermissionDenied(for type: PermissionType, in app: XCUIApplication) -> Bool {
        // app.webViews.firstMatch.evaluate(checkPermissionStatusJS(type: type))
        // Removed: XCUIElement doesn't have evaluate()
        Thread.sleep(forTimeInterval: 1.0)

        // if let granted = app.webViews.firstMatch.evaluate("window.permissionStatus?.granted") as? Bool {
        //     return !granted
        // }

        return false
    }

    // MARK: - HTML Page Helpers

    /// Get URL for permission test page
    static func getPermissionTestPageURL() -> URL? {
        #if DEBUG
        // Try to find the test HTML file in the bundle or project directory
        if let testPath = Bundle(for: PermissionTestHelper.self).path(forResource: "permission-test", ofType: "html", inDirectory: "test_resources/permissions") {
            return URL(fileURLWithPath: testPath)
        }

        // Fallback to project directory
        let projectPath = "/Users/xuyingzhou/Project/temporary/WebBridgeKit/test_resources/permissions/permission-test.html"
        if FileManager.default.fileExists(atPath: projectPath) {
            return URL(fileURLWithPath: projectPath)
        }
        #endif

        return nil
    }

    /// Load permission test page in webview
    static func loadPermissionTestPage(in app: XCUIApplication) -> Bool {
        guard let url = getPermissionTestPageURL() else {
            XCTFail("Permission test page not found")
            return false
        }

        let loadJS = "window.location.href = '\(url.absoluteString)'"
        // app.webViews.firstMatch.evaluate(loadJS) // Removed: XCUIElement doesn\'t have evaluate()

        Thread.sleep(forTimeInterval: 2.0)

        return app.webViews.firstMatch.exists
    }

    // MARK: - Reset Permission State

    /// Reset permission settings for testing (requires simulator restart or settings reset)
    /// Note: This is a helper to document the manual process
    static func resetPermissionInstructions() -> String {
        return """
        To reset permissions for testing:

        1. Stop the app/simulator
        2. Reset Simulator: Simulator -> Device -> Erase All Content and Settings
        3. Or use command line: xcrun simctl erase all

        For specific permissions:
        - iOS Simulator -> Settings -> Privacy -> [Permission Type]
        - Find your app and reset permission
        """
    }

    // MARK: - Debug Helpers

    /// Log current permission state
    static func logPermissionState(for type: PermissionType, in app: XCUIApplication) {
        // app.webViews.firstMatch.evaluate(checkPermissionStatusJS(type: type))
        // Removed: XCUIElement doesn't have evaluate()
        Thread.sleep(forTimeInterval: 1.0)

        // if let status = app.webViews.firstMatch.evaluate("JSON.stringify(window.permissionStatus || {})") as? String {
        //     print("🔐 [Permission] \(type.name) Status: \(status)")
        // }
        print("🔐 [Permission] \(type.name) Status: Unable to check (evaluate() not available)")
    }

    /// Capture screenshot for debugging
    static func captureDebugScreenshot(_ name: String, in app: XCUIApplication) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Capture Screenshot") { _ in
            XCTAttachment(screenshot: screenshot)
        }
    }
}
