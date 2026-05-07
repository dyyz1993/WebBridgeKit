import XCTest
@testable import WebBridgeKit

final class WebBluetoothHandlerTests: XCTestCase {

    private func assertSuccess(_ result: Any) -> [String: Any] {
        guard let dict = result as? [String: Any] else {
            XCTFail("Result is not a dictionary")
            return [:]
        }
        XCTAssertEqual(dict["success"] as? Bool, true)
        return dict
    }

    private func assertFailure(_ result: Any) -> [String: Any] {
        guard let dict = result as? [String: Any] else {
            XCTFail("Result is not a dictionary")
            return [:]
        }
        XCTAssertEqual(dict["success"] as? Bool, false)
        return dict
    }

    // MARK: - Instantiation

    func testBluetoothHandler_CanBeInstantiated() {
        let handler = WebBluetoothHandler()
        XCTAssertNotNil(handler)
    }

    // MARK: - Default Action (Get Status)

    func testBluetoothHandler_EmptyBody_ReturnsStatus() {
        let handler = WebBluetoothHandler()
        let expectation = XCTestExpectation(description: "bluetooth status default")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["available"])
            XCTAssertNotNil(data["state"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testBluetoothHandler_EmptyAction_ReturnsStatus() {
        let handler = WebBluetoothHandler()
        let expectation = XCTestExpectation(description: "bluetooth empty action")

        handler.handle(body: ["params": ["action": ""]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["available"])
            XCTAssertNotNil(data["state"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testBluetoothHandler_StatusStateIsString() {
        let handler = WebBluetoothHandler()
        let expectation = XCTestExpectation(description: "bluetooth state is string")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            let validStates = ["poweredOn", "poweredOff", "unauthorized", "unknown", "resetting", "unsupported"]
            let state = data["state"] as? String
            XCTAssertNotNil(state)
            XCTAssertTrue(validStates.contains(state ?? ""), "Invalid state: \(state ?? "nil")")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testBluetoothHandler_AvailableIsBool() {
        let handler = WebBluetoothHandler()
        let expectation = XCTestExpectation(description: "bluetooth available is bool")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertTrue(data["available"] is Bool)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Stop Scan

    func testBluetoothHandler_StopScan_ReturnsStopped() {
        let handler = WebBluetoothHandler()
        let expectation = XCTestExpectation(description: "bluetooth stopScan")

        handler.handle(body: ["params": ["action": "stopScan"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Unsupported Actions

    func testBluetoothHandler_ConnectAction_ReturnsError() {
        let handler = WebBluetoothHandler()
        let expectation = XCTestExpectation(description: "bluetooth connect unsupported")

        handler.handle(body: ["params": ["action": "connect"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testBluetoothHandler_PairAction_ReturnsError() {
        let handler = WebBluetoothHandler()
        let expectation = XCTestExpectation(description: "bluetooth pair unsupported")

        handler.handle(body: ["params": ["action": "pair"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testBluetoothHandler_WriteAction_ReturnsError() {
        let handler = WebBluetoothHandler()
        let expectation = XCTestExpectation(description: "bluetooth write unsupported")

        handler.handle(body: ["params": ["action": "write"]]) { result in
            let dict = self.assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Unsupported action"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Handler Name

    func testBluetoothHandler_HandlerName() {
        let handler = WebBluetoothHandler()
        XCTAssertEqual(handler.handlerName, "Bluetooth")
    }

    // MARK: - Multiple Instances

    func testBluetoothHandler_MultipleInstances_AreIndependent() {
        let handler1 = WebBluetoothHandler()
        let handler2 = WebBluetoothHandler()

        let exp1 = XCTestExpectation(description: "handler1")
        let exp2 = XCTestExpectation(description: "handler2")

        handler1.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            exp1.fulfill()
        }

        handler2.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            exp2.fulfill()
        }

        wait(for: [exp1, exp2], timeout: 5.0)
    }
}
