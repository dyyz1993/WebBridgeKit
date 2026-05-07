import XCTest
@testable import WebBridgeKit

final class WebVibrationHandlerTests: XCTestCase {

    private func assertSuccess(_ result: Any) -> [String: Any] {
        guard let dict = result as? [String: Any] else {
            XCTFail("Result is not a dictionary")
            return [:]
        }
        XCTAssertEqual(dict["success"] as? Bool, true)
        return dict
    }

    // MARK: - Default Duration

    func testVibrateHandler_DefaultDuration_Is1000() {
        let handler = WebVibrateHandler()
        let expectation = XCTestExpectation(description: "vibrate default duration")

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

    // MARK: - Explicit Duration

    func testVibrateHandler_ExplicitDuration() {
        let handler = WebVibrateHandler()
        let expectation = XCTestExpectation(description: "vibrate explicit duration")

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

    // MARK: - Long Duration

    func testVibrateHandler_LongDuration() {
        let handler = WebVibrateHandler()
        let expectation = XCTestExpectation(description: "vibrate long duration")

        handler.handle(body: ["duration": 3000]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["duration"] as? Int, 3000)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Zero Duration

    func testVibrateHandler_ZeroDuration() {
        let handler = WebVibrateHandler()
        let expectation = XCTestExpectation(description: "vibrate zero duration")

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

    func testVibrateHandler_HandlerName() {
        let handler = WebVibrateHandler()
        XCTAssertEqual(handler.handlerName, "Vibrate")
    }

    // MARK: - Multiple Rapid Calls

    func testVibrateHandler_MultipleRapidCalls() {
        let handler = WebVibrateHandler()

        for i in 0..<5 {
            let expectation = XCTestExpectation(description: "vibrate rapid \(i)")

            handler.handle(body: ["duration": 100]) { result in
                let dict = self.assertSuccess(result)
                XCTAssertNotNil(dict["data"])
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0)
        }
    }
}
