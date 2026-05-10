import XCTest
@testable import WebBridgeKit

final class WebGestureConfigTests: XCTestCase {

    // MARK: - GestureType.from(string:)

    func testGestureType_FromString_Pull_ReturnsPull() {
        let result = WebGestureConfig.GestureType.from(string: "pull")
        XCTAssertEqual(result, .pull)
    }

    func testGestureType_FromString_SwipeLeft_ReturnsSwipeLeft() {
        let result = WebGestureConfig.GestureType.from(string: "swipeLeft")
        XCTAssertEqual(result, .swipeLeft)
    }

    func testGestureType_FromString_SwipeRight_ReturnsSwipeRight() {
        let result = WebGestureConfig.GestureType.from(string: "swipeRight")
        XCTAssertEqual(result, .swipeRight)
    }

    func testGestureType_FromString_SwipeUp_ReturnsSwipeUp() {
        let result = WebGestureConfig.GestureType.from(string: "swipeUp")
        XCTAssertEqual(result, .swipeUp)
    }

    func testGestureType_FromString_SwipeDown_ReturnsSwipeDown() {
        let result = WebGestureConfig.GestureType.from(string: "swipeDown")
        XCTAssertEqual(result, .swipeDown)
    }

    func testGestureType_FromString_LongPress_ReturnsLongPress() {
        let result = WebGestureConfig.GestureType.from(string: "longPress")
        XCTAssertEqual(result, .longPress)
    }

    func testGestureType_FromString_DoubleTap_ReturnsDoubleTap() {
        let result = WebGestureConfig.GestureType.from(string: "doubleTap")
        XCTAssertEqual(result, .doubleTap)
    }

    func testGestureType_FromString_Pinch_ReturnsPinch() {
        let result = WebGestureConfig.GestureType.from(string: "pinch")
        XCTAssertEqual(result, .pinch)
    }

    func testGestureType_FromString_UnknownValue_ReturnsNil() {
        let result = WebGestureConfig.GestureType.from(string: "unknownGesture")
        XCTAssertNil(result)
    }

    func testGestureType_FromString_EmptyString_ReturnsNil() {
        let result = WebGestureConfig.GestureType.from(string: "")
        XCTAssertNil(result)
    }

    // MARK: - PullState.from(string:)

    func testPullState_FromString_Idle_ReturnsIdle() {
        let result = WebGestureConfig.PullState.from(string: "idle")
        XCTAssertEqual(result, .idle)
    }

    func testPullState_FromString_Pulling_ReturnsPulling() {
        let result = WebGestureConfig.PullState.from(string: "pulling")
        XCTAssertEqual(result, .pulling)
    }

    func testPullState_FromString_Triggered_ReturnsTriggered() {
        let result = WebGestureConfig.PullState.from(string: "triggered")
        XCTAssertEqual(result, .triggered)
    }

    func testPullState_FromString_Loading_ReturnsLoading() {
        let result = WebGestureConfig.PullState.from(string: "loading")
        XCTAssertEqual(result, .loading)
    }

    func testPullState_FromString_Completed_ReturnsCompleted() {
        let result = WebGestureConfig.PullState.from(string: "completed")
        XCTAssertEqual(result, .completed)
    }

    func testPullState_FromString_Cancelled_ReturnsCancelled() {
        let result = WebGestureConfig.PullState.from(string: "cancelled")
        XCTAssertEqual(result, .cancelled)
    }

    func testPullState_FromString_UnknownValue_ReturnsNil() {
        let result = WebGestureConfig.PullState.from(string: "unknown")
        XCTAssertNil(result)
    }

    func testPullState_FromString_EmptyString_ReturnsNil() {
        let result = WebGestureConfig.PullState.from(string: "")
        XCTAssertNil(result)
    }

    // MARK: - Default Config

    func testDefaultConfig_Enabled_IsTrue() {
        let config = WebGestureConfig.default
        XCTAssertTrue(config.enabled)
    }

    func testDefaultConfig_EnabledGestures_ContainsPull() {
        let config = WebGestureConfig.default
        XCTAssertTrue(config.enabledGestures.contains(.pull))
        XCTAssertEqual(config.enabledGestures.count, 1)
    }

    func testDefaultConfig_PullThreshold_Is015() {
        let config = WebGestureConfig.default
        XCTAssertEqual(config.pullThreshold, 0.15)
    }

    func testDefaultConfig_PullMaxDistance_Is025() {
        let config = WebGestureConfig.default
        XCTAssertEqual(config.pullMaxDistance, 0.25)
    }

    func testDefaultConfig_ShowVisualFeedback_IsTrue() {
        let config = WebGestureConfig.default
        XCTAssertTrue(config.showVisualFeedback)
    }

    func testDefaultConfig_AutoBounceBack_IsTrue() {
        let config = WebGestureConfig.default
        XCTAssertTrue(config.autoBounceBack)
    }

    // MARK: - Disabled Config

    func testDisabledConfig_Enabled_IsFalse() {
        let config = WebGestureConfig.disabled
        XCTAssertFalse(config.enabled)
    }

    func testDisabledConfig_EnabledGestures_IsEmpty() {
        let config = WebGestureConfig.disabled
        XCTAssertTrue(config.enabledGestures.isEmpty)
    }

    // MARK: - from(dict:)

    func testFromDict_EmptyDict_ReturnsDefaults() {
        let config = WebGestureConfig.from(dict: [:])
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.enabledGestures, Set([.pull]))
        XCTAssertEqual(config.pullThreshold, 0.15)
        XCTAssertEqual(config.pullMaxDistance, 0.25)
        XCTAssertTrue(config.showVisualFeedback)
        XCTAssertTrue(config.autoBounceBack)
    }

    func testFromDict_CustomGestures_ParsesCorrectly() {
        let dict: [String: Any] = [
            "gestures": ["swipeLeft", "longPress"],
            "enabled": false
        ]
        let config = WebGestureConfig.from(dict: dict)
        XCTAssertFalse(config.enabled)
        XCTAssertTrue(config.enabledGestures.contains(.swipeLeft))
        XCTAssertTrue(config.enabledGestures.contains(.longPress))
        XCTAssertEqual(config.enabledGestures.count, 2)
    }

    func testFromDict_InvalidGestures_FallbackToPull() {
        let dict: [String: Any] = ["gestures": ["invalidGesture"]]
        let config = WebGestureConfig.from(dict: dict)
        XCTAssertEqual(config.enabledGestures, Set([.pull]))
    }

    func testFromDict_EmptyGesturesArray_FallbackToPull() {
        let dict: [String: Any] = ["gestures": [String]()]
        let config = WebGestureConfig.from(dict: dict)
        XCTAssertEqual(config.enabledGestures, Set([.pull]))
    }

    func testFromDict_CustomThreshold_ParsesCorrectly() {
        let dict: [String: Any] = [
            "pullThreshold": CGFloat(0.2),
            "pullMaxDistance": CGFloat(0.4),
            "showVisualFeedback": false,
            "autoBounceBack": false
        ]
        let config = WebGestureConfig.from(dict: dict)
        XCTAssertEqual(config.pullThreshold, 0.2)
        XCTAssertEqual(config.pullMaxDistance, 0.4)
        XCTAssertFalse(config.showVisualFeedback)
        XCTAssertFalse(config.autoBounceBack)
    }

    func testFromDict_AllCustomValues() {
        let dict: [String: Any] = [
            "enabled": false,
            "gestures": ["swipeUp", "swipeDown", "pinch"],
            "pullThreshold": CGFloat(0.1),
            "pullMaxDistance": CGFloat(0.3),
            "showVisualFeedback": false,
            "autoBounceBack": false
        ]
        let config = WebGestureConfig.from(dict: dict)
        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.enabledGestures.count, 3)
        XCTAssertTrue(config.enabledGestures.contains(.swipeUp))
        XCTAssertTrue(config.enabledGestures.contains(.swipeDown))
        XCTAssertTrue(config.enabledGestures.contains(.pinch))
        XCTAssertEqual(config.pullThreshold, 0.1)
        XCTAssertEqual(config.pullMaxDistance, 0.3)
        XCTAssertFalse(config.showVisualFeedback)
        XCTAssertFalse(config.autoBounceBack)
    }
}
