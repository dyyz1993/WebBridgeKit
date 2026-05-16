import XCTest
@testable import WebBridgeKit

final class WebMirroringHandlerTests: XCTestCase {

    // MARK: - Get Status (Default)

    func testMirroringHandler_Default_ReturnsStatus() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring default")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["isMirroring"])
            XCTAssertNotNil(data["screenCount"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMirroringHandler_GetStatusAction() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring getStatus")

        handler.handle(body: ["params": ["action": "getStatus"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertTrue(data["isMirroring"] is Bool)
            XCTAssertTrue(data["screenCount"] is Int)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMirroringHandler_ScreenCount_IsAtLeastOne() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring screen count")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any],
                  let count = data["screenCount"] as? Int else {
                XCTFail("Missing screenCount")
                return
            }
            XCTAssertGreaterThanOrEqual(count, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Start/Stop Observe

    func testMirroringHandler_StartObserve_ReturnsObserving() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring startObserve")

        handler.handle(body: ["params": ["action": "startObserve"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "observing")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMirroringHandler_StopObserve_ReturnsStopped() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring stopObserve")

        handler.handle(body: ["params": ["action": "stopObserve"]]) { result in
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

    func testMirroringHandler_StartObserveTwice_StillReturnsObserving() {
        let handler = WebMirroringHandler()
        let exp1 = XCTestExpectation(description: "mirroring startObserve 1")
        let exp2 = XCTestExpectation(description: "mirroring startObserve 2")

        handler.handle(body: ["params": ["action": "startObserve"]]) { result in
            let dict = assertSuccess(result)
            XCTAssertEqual((dict["data"] as? [String: Any])?["status"] as? String, "observing")
            exp1.fulfill()
        }

        wait(for: [exp1], timeout: 2.0)

        handler.handle(body: ["params": ["action": "startObserve"]]) { result in
            let dict = assertSuccess(result)
            XCTAssertEqual((dict["data"] as? [String: Any])?["status"] as? String, "observing")
            exp2.fulfill()
        }

        wait(for: [exp2], timeout: 2.0)
    }

    // MARK: - Unsupported Actions

    func testMirroringHandler_UnsupportedAction_ReturnsError() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring unsupported")

        handler.handle(body: ["params": ["action": "mirror"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Handler Name

    func testMirroringHandler_HandlerName() {
        let handler = WebMirroringHandler()
        XCTAssertEqual(handler.handlerName, "Mirroring")
    }
}
