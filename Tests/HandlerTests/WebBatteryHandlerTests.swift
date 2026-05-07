import XCTest
@testable import WebBridgeKit

final class WebBatteryAndSystemInfoHandlerTests: XCTestCase {

    private func assertSuccess(_ result: Any) -> [String: Any] {
        guard let dict = result as? [String: Any] else {
            XCTFail("Result is not a dictionary")
            return [:]
        }
        XCTAssertEqual(dict["success"] as? Bool, true)
        return dict
    }

    // MARK: - WebSystemInfoHandler Fields

    func testSystemInfoHandler_AllFields() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info all fields")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }

            let requiredFields = [
                "systemName", "systemVersion", "deviceModel", "deviceName",
                "screenWidth", "screenHeight", "scale",
                "appVersion", "buildNumber", "appName",
                "batteryLevel", "batteryState",
                "preferredLanguage", "locale", "timezone"
            ]

            for field in requiredFields {
                XCTAssertNotNil(data[field], "Missing field: \(field)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSystemInfoHandler_ScreenDimensionsAreInt() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info screen int")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertTrue(data["screenWidth"] is Int)
            XCTAssertTrue(data["screenHeight"] is Int)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSystemInfoHandler_ScaleIsFloatOrDouble() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info scale type")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            let scale = data["scale"]
            XCTAssertTrue(scale is Float || scale is CGFloat || scale is Double || scale is NSNumber,
                          "Scale should be numeric")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSystemInfoHandler_BatteryLevelIsInt() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info battery int")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertTrue(data["batteryLevel"] is Int)
            let level = data["batteryLevel"] as? Int ?? -1
            XCTAssertTrue((0...100).contains(level) || level == -100,
                          "Battery level should be 0-100 or -100 (simulator), got \(level)")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSystemInfoHandler_BatteryStateIsValid() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info battery state")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            let validStates = ["charging", "full", "unplugged", "unknown"]
            let state = data["batteryState"] as? String ?? ""
            XCTAssertTrue(validStates.contains(state), "Invalid battery state: \(state)")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSystemInfoHandler_SystemNameNotEmpty() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info name")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            let name = data["systemName"] as? String ?? ""
            XCTAssertFalse(name.isEmpty)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSystemInfoHandler_IgnoresBodyParams() {
        let handler = WebSystemInfoHandler()
        let expectation = XCTestExpectation(description: "system info ignores body")

        handler.handle(body: ["action": "getAll", "extra": true]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["systemName"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSystemInfoHandler_MultipleCallsConsistent() {
        let handler = WebSystemInfoHandler()
        var versions: [String] = []

        for i in 0..<3 {
            let expectation = XCTestExpectation(description: "system info consistent \(i)")

            handler.handle(body: [:]) { result in
                let dict = self.assertSuccess(result)
                guard let data = dict["data"] as? [String: Any],
                      let version = data["systemVersion"] as? String else {
                    XCTFail("Missing data")
                    return
                }
                versions.append(version)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0)
        }

        XCTAssertEqual(Set(versions).count, 1, "System version should be consistent")
    }

    // MARK: - Handler Name

    func testSystemInfoHandler_HandlerName() {
        let handler = WebSystemInfoHandler()
        XCTAssertEqual(handler.handlerName, "SystemInfo")
    }
}
