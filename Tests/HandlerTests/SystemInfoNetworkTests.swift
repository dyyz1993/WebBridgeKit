import XCTest
@testable import WebBridgeKit

extension SimpleHandlerTests {

    // MARK: - WebSystemInfoHandler

    func testSystemInfoHandler_ReturnsSystemName() {
        assertSystemInfoFieldExists("systemName")
    }

    func testSystemInfoHandler_ReturnsSystemVersion() {
        assertSystemInfoFieldExists("systemVersion")
    }

    func testSystemInfoHandler_ReturnsDeviceModel() {
        assertSystemInfoFieldExists("deviceModel")
    }

    func testSystemInfoHandler_ReturnsDeviceName() {
        assertSystemInfoFieldExists("deviceName")
    }

    func testSystemInfoHandler_ReturnsScreenWidth() {
        assertSystemInfoFieldExists("screenWidth")
    }

    func testSystemInfoHandler_ReturnsScreenHeight() {
        assertSystemInfoFieldExists("screenHeight")
    }

    func testSystemInfoHandler_ReturnsScale() {
        assertSystemInfoFieldExists("scale")
    }

    func testSystemInfoHandler_ReturnsAppVersion() {
        assertSystemInfoFieldExists("appVersion")
    }

    func testSystemInfoHandler_ReturnsBuildNumber() {
        assertSystemInfoFieldExists("buildNumber")
    }

    func testSystemInfoHandler_ReturnsAppName() {
        assertSystemInfoFieldExists("appName")
    }

    func testSystemInfoHandler_ReturnsBatteryLevel() {
        assertSystemInfoFieldExists("batteryLevel")
    }

    func testSystemInfoHandler_ReturnsBatteryState() {
        assertSystemInfoFieldExists("batteryState")
    }

    func testSystemInfoHandler_ReturnsPreferredLanguage() {
        assertSystemInfoFieldExists("preferredLanguage")
    }

    func testSystemInfoHandler_ReturnsLocale() {
        assertSystemInfoFieldExists("locale")
    }

    func testSystemInfoHandler_ReturnsTimezone() {
        assertSystemInfoFieldExists("timezone")
    }

    func testSystemInfoHandler_CompleteFields() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info complete")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertFalse((data["systemName"] as? String ?? "").isEmpty)
            XCTAssertFalse((data["systemVersion"] as? String ?? "").isEmpty)
            XCTAssertFalse((data["deviceModel"] as? String ?? "").isEmpty)
            XCTAssertNotNil(data["screenWidth"])
            XCTAssertNotNil(data["screenHeight"])
            XCTAssertNotNil(data["scale"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    private func assertSystemInfoFieldExists(_ field: String) {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info \(field)")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data[field], "Missing field: \(field)")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebNetworkHandler

    func testNetworkHandler_ReturnsIsConnected() {
        let handler = WebNetworkHandler()
        let expectation = XCTestExpectation(description: "network isConnected")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["isConnected"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testNetworkHandler_ReturnsNetworkType() {
        let handler = WebNetworkHandler()
        let expectation = XCTestExpectation(description: "network type")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            let networkType = data["networkType"] as? String
            XCTAssertNotNil(networkType)
            let validTypes = ["wifi", "cellular", "none"]
            XCTAssertTrue(validTypes.contains(networkType ?? ""),
                          "Invalid network type: \(networkType ?? "nil")")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testNetworkHandler_IsConnectedIsBool() {
        let handler = WebNetworkHandler()
        let expectation = XCTestExpectation(description: "network isConnected bool")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertTrue(data["isConnected"] is Bool)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
