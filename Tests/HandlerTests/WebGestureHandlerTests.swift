import XCTest
@testable import WebBridgeKit

final class WebGestureHandlerTests: XCTestCase {

    private var handler: WebGestureHandler!

    override func setUp() {
        super.setUp()
        handler = WebGestureHandler()
    }

    override func tearDown() {
        handler = nil
        super.tearDown()
    }

    // MARK: - Handle Empty Body / No Action

    func testHandle_EmptyBody_NoAction_ReturnsConfigStatus() {
        let expectation = XCTestExpectation(description: "empty body returns config")

        handler.handle(body: [:]) { result in
            let data = assertSuccess(result)
            XCTAssertNotNil(data["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testHandle_EmptyAction_ReturnsConfigStatusWithEnabledTrue() {
        let expectation = XCTestExpectation(description: "empty action returns config")

        handler.handle(body: ["action": ""]) { result in
            let data = assertSuccess(result)
            guard let configData = data["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(configData["enabled"] as? Bool, true)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Unknown Action

    func testHandle_UnknownAction_RejectsWith404() {
        let expectation = XCTestExpectation(description: "unknown action rejects")

        handler.handle(body: ["action": "nonExistent"]) { result in
            let data = assertFailure(result)
            XCTAssertNotNil(data["error"])
            XCTAssertEqual(data["code"] as? Int, 404)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Config Action

    func testHandle_ConfigAction_UpdatesConfig() {
        let expectation = XCTestExpectation(description: "config action updates")

        let body: [String: Any] = [
            "action": "config",
            "enabled": false,
            "pullThreshold": CGFloat(0.3),
            "gestures": ["swipeLeft"]
        ]

        handler.handle(body: body) { result in
            _ = assertSuccess(result)
            let config = self.handler.getConfig()
            XCTAssertFalse(config.enabled)
            XCTAssertEqual(config.pullThreshold, 0.3, accuracy: 0.001)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Enable Action (no gestures)

    func testHandle_EnableAction_NoGestures_SetsEnabledTrue() {
        let expectation = XCTestExpectation(description: "enable without gestures")

        handler.handle(body: ["action": "disable"]) { _ in
            XCTAssertFalse(self.handler.getConfig().enabled)
            self.handler.handle(body: ["action": "enable"]) { result in
                _ = assertSuccess(result)
                XCTAssertTrue(self.handler.getConfig().enabled)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Enable Action (with gestures)

    func testHandle_EnableAction_WithGestures_AddsGestures() {
        let expectation = XCTestExpectation(description: "enable with gestures")

        handler.handle(body: [
            "action": "enable",
            "gestures": ["swipeLeft", "longPress"]
        ]) { result in
            _ = assertSuccess(result)
            let config = self.handler.getConfig()
            XCTAssertTrue(config.enabledGestures.contains(.swipeLeft))
            XCTAssertTrue(config.enabledGestures.contains(.longPress))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Disable Action (no gestures)

    func testHandle_DisableAction_NoGestures_SetsEnabledFalse() {
        let expectation = XCTestExpectation(description: "disable without gestures")

        handler.handle(body: ["action": "disable"]) { result in
            _ = assertSuccess(result)
            XCTAssertFalse(self.handler.getConfig().enabled)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Disable Action (with gestures)

    func testHandle_DisableAction_WithGestures_RemovesGestures() {
        let expectation = XCTestExpectation(description: "disable with gestures")

        handler.handle(body: [
            "action": "disable",
            "gestures": ["pull"]
        ]) { result in
            _ = assertSuccess(result)
            let config = self.handler.getConfig()
            XCTAssertFalse(config.enabledGestures.contains(.pull))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - setPullThreshold

    func testHandle_SetPullThreshold_UpdatesThreshold() {
        let expectation = XCTestExpectation(description: "set pull threshold")

        handler.handle(body: [
            "action": "setPullThreshold",
            "threshold": CGFloat(0.3)
        ]) { result in
            let data = assertSuccess(result)
            guard let responseData = data["data"] as? [String: Any] else {
                XCTFail("Missing response data")
                return
            }
            XCTAssertEqual(responseData["pullThreshold"] as? CGFloat, 0.3)
            let config = self.handler.getConfig()
            XCTAssertEqual(config.pullThreshold, 0.3, accuracy: 0.001)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - startPullRefresh

    func testHandle_StartPullRefresh_ReturnsLoadingState() {
        let expectation = XCTestExpectation(description: "start pull refresh")

        handler.handle(body: ["action": "startPullRefresh"]) { result in
            let data = assertSuccess(result)
            guard let responseData = data["data"] as? [String: Any] else {
                XCTFail("Missing response data")
                return
            }
            XCTAssertEqual(responseData["state"] as? String, "loading")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - stopPullRefresh

    func testHandle_StopPullRefresh_ReturnsCompletedState() {
        let expectation = XCTestExpectation(description: "stop pull refresh")

        handler.handle(body: ["action": "stopPullRefresh"]) { result in
            let data = assertSuccess(result)
            guard let responseData = data["data"] as? [String: Any] else {
                XCTFail("Missing response data")
                return
            }
            XCTAssertEqual(responseData["state"] as? String, "completed")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - cancelPullRefresh

    func testHandle_CancelPullRefresh_ReturnsCancelledState() {
        let expectation = XCTestExpectation(description: "cancel pull refresh")

        handler.handle(body: ["action": "cancelPullRefresh"]) { result in
            let data = assertSuccess(result)
            guard let responseData = data["data"] as? [String: Any] else {
                XCTFail("Missing response data")
                return
            }
            XCTAssertEqual(responseData["state"] as? String, "cancelled")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - getConfig()

    func testGetConfig_ReturnsDefaultConfig() {
        let config = handler.getConfig()
        XCTAssertTrue(config.enabled)
        XCTAssertTrue(config.enabledGestures.contains(.pull))
        XCTAssertEqual(config.pullThreshold, 0.15, accuracy: 0.001)
        XCTAssertEqual(config.pullMaxDistance, 0.25, accuracy: 0.001)
        XCTAssertTrue(config.showVisualFeedback)
        XCTAssertTrue(config.autoBounceBack)
    }

    // MARK: - handlePullStart when disabled

    func testHandlePullStart_WhenDisabled_DoesNotCrash() {
        handler.handle(body: ["action": "disable"]) { _ in }
        handler.handlePullStart(at: 100)
    }

    func testHandlePullStart_WhenDisabled_DoesNotSendEvent() {
        let expectation = XCTestExpectation(description: "disabled no event")

        handler.handle(body: ["action": "disable"]) { _ in
            self.handler.handlePullStart(at: 100)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - handlePullStart when enabled

    func testHandlePullStart_WhenEnabled_DoesNotCrash() {
        handler.handlePullStart(at: 100)
    }

    // MARK: - handlePullRelease not triggered → cancelled

    func testHandlePullRelease_NotTriggered_Cancels() {
        handler.handlePullStart(at: 0)
        handler.handlePullRelease(threshold: 99999)
    }

    // MARK: - handlePullRelease triggered → loading

    func testHandlePullRelease_Triggered_GoesToLoading() {
        handler.handlePullStart(at: 0)
        handler.handlePullMove(distance: 200, threshold: 100, maxDistance: 300)
        handler.handlePullRelease(threshold: 100)
    }

    // MARK: - handlePullCancel

    func testHandlePullCancel_SetsCancelled() {
        handler.handlePullStart(at: 0)
        handler.handlePullCancel()
    }

    func testHandlePullCancel_WhenIdle_DoesNothing() {
        handler.handlePullCancel()
    }

    // MARK: - Handler Name

    func testHandler_HandlerName() {
        XCTAssertEqual(handler.handlerName, "Gesture")
    }
}
