import XCTest
@testable import WebBridgeKit

final class WebVibrateHandlerTests: XCTestCase {

    private var handler: WebVibrateHandler!

    override func setUp() {
        super.setUp()
        handler = WebVibrateHandler()
    }

    override func tearDown() {
        handler = nil
        super.tearDown()
    }

    private func assertSuccess(_ result: Any) -> [String: Any] {
        guard let dict = result as? [String: Any] else {
            XCTFail("Result is not a dictionary")
            return [:]
        }
        XCTAssertEqual(dict["success"] as? Bool, true)
        return dict
    }

    // MARK: - Default Duration

    func testHandle_DefaultDuration_Returns1000() {
        let expectation = XCTestExpectation(description: "default duration 1000")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["duration"] as? Int, 1000)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Custom Duration

    func testHandle_CustomDuration_ReturnsCustomValue() {
        let expectation = XCTestExpectation(description: "custom duration 500")

        handler.handle(body: ["duration": 500]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["duration"] as? Int, 500)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - No Duration Key

    func testHandle_NoDurationKey_DefaultsTo1000() {
        let expectation = XCTestExpectation(description: "no duration key defaults to 1000")

        handler.handle(body: ["otherKey": "value"]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["duration"] as? Int, 1000)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Large Duration

    func testHandle_LargeDuration_ReturnsLargeValue() {
        let expectation = XCTestExpectation(description: "large duration 5000")

        handler.handle(body: ["duration": 5000]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["duration"] as? Int, 5000)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Zero Duration

    func testHandle_ZeroDuration_ReturnsZero() {
        let expectation = XCTestExpectation(description: "zero duration")

        handler.handle(body: ["duration": 0]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["duration"] as? Int, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Handler Name

    func testHandler_HandlerName() {
        XCTAssertEqual(handler.handlerName, "Vibrate")
    }
}
