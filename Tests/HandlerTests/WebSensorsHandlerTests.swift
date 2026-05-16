import XCTest
@testable import WebBridgeKit

final class WebSensorsHandlerTests: XCTestCase {

    // MARK: - Get Status (Default)

    func testSensorsHandler_Default_ReturnsStatus() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors default")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["accelerometer"])
            XCTAssertNotNil(data["gyroscope"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSensorsHandler_EmptyAction_ReturnsStatus() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors empty action")

        handler.handle(body: ["params": ["action": ""]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["accelerometer"])
            XCTAssertNotNil(data["gyroscope"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSensorsHandler_StatusContainsActiveFlags() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors active flags")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["accelerometerActive"])
            XCTAssertNotNil(data["gyroscopeActive"])
            XCTAssertTrue(data["accelerometerActive"] is Bool)
            XCTAssertTrue(data["gyroscopeActive"] is Bool)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Stop Actions

    func testSensorsHandler_StopAccelerometer_ReturnsStopped() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors stopAccelerometer")

        handler.handle(body: ["params": ["action": "stopAccelerometer"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSensorsHandler_StopGyroscope_ReturnsStopped() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors stopGyroscope")

        handler.handle(body: ["params": ["action": "stopGyroscope"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSensorsHandler_StopWithoutStart_StillSucceeds() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors stop without start")

        handler.handle(body: ["params": ["action": "stopAccelerometer"]]) { result in
            let dict = assertSuccess(result)
            XCTAssertEqual((dict["data"] as? [String: Any])?["status"] as? String, "stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Unsupported Actions

    func testSensorsHandler_UnsupportedAction_ReturnsError() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors unsupported")

        handler.handle(body: ["params": ["action": "startMagnetometer"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSensorsHandler_InvalidAction_ReturnsError() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors invalid")

        handler.handle(body: ["params": ["action": "calibrate"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Handler Name

    func testSensorsHandler_HandlerName() {
        let handler = WebSensorsHandler()
        XCTAssertEqual(handler.handlerName, "Sensors")
    }
}
