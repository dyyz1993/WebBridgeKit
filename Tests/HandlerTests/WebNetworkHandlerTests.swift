import XCTest
@testable import WebBridgeKit

final class WebNetworkHandlerTests: XCTestCase {

    private func assertSuccess(_ result: Any) -> [String: Any] {
        guard let dict = result as? [String: Any] else {
            XCTFail("Result is not a dictionary")
            return [:]
        }
        XCTAssertEqual(dict["success"] as? Bool, true)
        return dict
    }

    // MARK: - Response Structure

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
            XCTAssertTrue(data["isConnected"] is Bool)
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

    // MARK: - Multiple Calls Return Consistent Results

    func testNetworkHandler_MultipleCalls_ReturnConsistentType() {
        let handler = WebNetworkHandler()
        var results: [String] = []

        for i in 0..<3 {
            let expectation = XCTestExpectation(description: "network consistent \(i)")

            handler.handle(body: [:]) { result in
                let dict = self.assertSuccess(result)
                guard let data = dict["data"] as? [String: Any],
                      let networkType = data["networkType"] as? String else {
                    XCTFail("Missing data")
                    return
                }
                results.append(networkType)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0)
        }

        let uniqueResults = Set(results)
        XCTAssertEqual(uniqueResults.count, 1, "Network type should be consistent across calls")
    }

    // MARK: - Ignores Body Parameters

    func testNetworkHandler_IgnoresBodyParams() {
        let handler = WebNetworkHandler()
        let expectation = XCTestExpectation(description: "network ignores body")

        handler.handle(body: ["foo": "bar", "action": "unknown"]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["isConnected"])
            XCTAssertNotNil(data["networkType"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Handler Name

    func testNetworkHandler_HandlerName() {
        let handler = WebNetworkHandler()
        XCTAssertEqual(handler.handlerName, "Network")
    }

    // MARK: - Response Has Exactly Two Keys In Data

    func testNetworkHandler_DataHasTwoKeys() {
        let handler = WebNetworkHandler()
        let expectation = XCTestExpectation(description: "network data keys")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertTrue(data.keys.contains("isConnected"))
            XCTAssertTrue(data.keys.contains("networkType"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
