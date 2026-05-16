import XCTest
@testable import WebBridgeKit

final class WebSystemInfoHandlerTests: XCTestCase {

    // MARK: - Handler Name

    func testSystemInfoHandler_HandlerName() {
        let handler = WebSystemInfoHandler()
        XCTAssertEqual(handler.handlerName, "SystemInfo")
    }

    // MARK: - Handle Returns Success

    func testSystemInfoHandler_Handle_ReturnsSuccess() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info handle")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Contains System Info Keys

    func testSystemInfoHandler_ContainsSystemInfoKeys() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info keys")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }

            let expectedKeys = ["appVersion", "buildNumber", "systemName", "systemVersion",
                                "deviceModel", "deviceName", "screenWidth", "screenHeight",
                                "scale", "batteryLevel", "batteryState",
                                "preferredLanguage", "locale", "timezone"]

            for key in expectedKeys {
                XCTAssertNotNil(data[key], "Missing key: \(key)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - System Version Is Non-Empty

    func testSystemInfoHandler_SystemVersionIsNonEmpty() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info version")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any],
                  let systemVersion = data["systemVersion"] as? String else {
                XCTFail("Missing systemVersion")
                return
            }
            XCTAssertFalse(systemVersion.isEmpty, "systemVersion should not be empty")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Screen Dimensions Are Positive

    func testSystemInfoHandler_ScreenDimensionsArePositive() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info screen dimensions")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }

            let screenWidth = data["screenWidth"] as? Int ?? 0
            let screenHeight = data["screenHeight"] as? Int ?? 0
            let scale = data["scale"] as? CGFloat ?? 0

            XCTAssertGreaterThan(screenWidth, 0, "screenWidth should be positive")
            XCTAssertGreaterThan(screenHeight, 0, "screenHeight should be positive")
            XCTAssertGreaterThanOrEqual(scale, 1.0, "scale should be >= 1.0")

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Battery State Is Valid

    func testSystemInfoHandler_BatteryStateIsValid() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info battery state")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any],
                  let batteryState = data["batteryState"] as? String else {
                XCTFail("Missing batteryState")
                return
            }
            let validStates = ["charging", "full", "unplugged", "unknown"]
            XCTAssertTrue(validStates.contains(batteryState), "Invalid battery state: \(batteryState)")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Battery Level Is In Range

    func testSystemInfoHandler_BatteryLevelIsInRange() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info battery level")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any],
                  let batteryLevel = data["batteryLevel"] as? Int else {
                XCTFail("Missing batteryLevel")
                return
            }
            XCTAssertGreaterThanOrEqual(batteryLevel, 0, "batteryLevel should be >= 0")
            XCTAssertLessThanOrEqual(batteryLevel, 100, "batteryLevel should be <= 100")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Locale And Timezone Are Non-Empty

    func testSystemInfoHandler_LocaleAndTimezoneAreNonEmpty() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info locale timezone")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any],
                  let locale = data["locale"] as? String,
                  let timezone = data["timezone"] as? String else {
                XCTFail("Missing locale or timezone")
                return
            }
            XCTAssertFalse(locale.isEmpty, "locale should not be empty")
            XCTAssertFalse(timezone.isEmpty, "timezone should not be empty")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Ignores Body Parameters

    func testSystemInfoHandler_IgnoresBodyParams() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info ignores body")

        handler.handle(body: ["foo": "bar", "detail": true]) { result in
            let dict = assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
