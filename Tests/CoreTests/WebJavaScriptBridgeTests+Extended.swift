//
//  WebJavaScriptBridgeTests+Extended.swift
//  CoreTests
//

import XCTest
import WebKit
@testable import WebBridgeKit

final class WebJavaScriptBridgeExtendedTests: XCTestCase {

    private var bridge: WebJavaScriptBridge!

    override func setUp() {
        super.setUp()
        bridge = WebJavaScriptBridge()
    }

    override func tearDown() {
        bridge = nil
        super.tearDown()
    }

    // MARK: - Handler Factory Registration (All Actions)

    func testAllRegisteredHandlerFactories() {
        let actions = [
            "share", "getLocation", "requestPermission",
            "getSystemInfo", "getNetworkInfo",
            "haptic", "vibrate", "clipboard",
            "scan", "camera", "videoStream",
            "speech", "audioLevel", "contacts",
            "screen", "layout", "mirroring",
            "sensors", "media", "systemExtra",
            "tts", "bluetooth", "file",
            "getPermissionStatus", "openSettings",
            "openPage", "closePage", "getHistory",
            "getPayload", "goBack", "setModal",
            "gesture", "cacheDebug", "page"
        ]

        for action in actions {
            let handler = bridge.getHandler(for: action)
            XCTAssertNotNil(handler, "Expected handler for action: \(action)")
        }
    }

    func testHandlerLazilyLoadedInitiallyEmpty() {
        XCTAssertTrue(bridge.nativeHandlers.isEmpty)
    }

    func testGetHandlerPopulatesNativeHandlers() {
        XCTAssertNil(bridge.nativeHandlers["share"])
        let _ = bridge.getHandler(for: "share")
        XCTAssertNotNil(bridge.nativeHandlers["share"])
    }

    func testGetHandlerForUnknownActionDoesNotPopulate() {
        let _ = bridge.getHandler(for: "nonexistent_xyz")
        XCTAssertTrue(bridge.nativeHandlers.isEmpty)
    }

    // MARK: - Handler Identity (Same Instance)

    func testGetHandlerReturnsSameInstanceForAllActions() {
        let actions = ["share", "clipboard", "haptic", "getSystemInfo"]
        for action in actions {
            let first = bridge.getHandler(for: action)
            let second = bridge.getHandler(for: action)
            XCTAssertTrue(
                (first as AnyObject) === (second as AnyObject),
                "Handler for \(action) should be same instance"
            )
        }
    }

    func testDifferentActionsReturnDifferentInstances() {
        let share = bridge.getHandler(for: "share")
        let clipboard = bridge.getHandler(for: "clipboard")
        XCTAssertFalse(
            (share as AnyObject) === (clipboard as AnyObject),
            "Different actions should return different handler instances"
        )
    }

    // MARK: - sendResultToJS with WebBridgeResponse

    func testSendResultToJSWithSuccessResponse() {
        let response = WebBridgeResponse.success(data: ["key": "value"])
        bridge.sendResultToJS(response, callbackId: "test-cb-1")
    }

    func testSendResultToJSWithErrorResponse() {
        let response = WebBridgeResponse.error(code: 404, message: "Not found")
        bridge.sendResultToJS(response, callbackId: "test-cb-2")
    }

    func testSendResultToJSWithErrorResponseDefault() {
        let response = WebBridgeResponse.error(message: "Server error")
        bridge.sendResultToJS(response, callbackId: "test-cb-3")
    }

    func testSendResultToJSWithSimpleValue() {
        bridge.sendResultToJS("string result", callbackId: "test-cb-4")
    }

    func testSendResultToJSWithIntValue() {
        bridge.sendResultToJS(42, callbackId: "test-cb-5")
    }

    func testSendResultToJSWithArray() {
        bridge.sendResultToJS([1, 2, 3], callbackId: "test-cb-6")
    }

    // MARK: - sendErrorToJS

    func testSendErrorToJSEmptyMessage() {
        bridge.sendErrorToJS("", callbackId: "test-cb-7")
    }

    func testSendErrorToJSLongMessage() {
        let longMsg = String(repeating: "a", count: 10000)
        bridge.sendErrorToJS(longMsg, callbackId: "test-cb-8")
    }

    // MARK: - sendEventToJS

    func testSendEventToJSWithIntData() {
        bridge.sendEventToJS(event: "count", data: 42)
    }

    func testSendEventToJSWithBoolData() {
        bridge.sendEventToJS(event: "status", data: true)
    }

    func testSendEventToJSWithArrayData() {
        bridge.sendEventToJS(event: "items", data: [1, 2, 3])
    }

    func testSendEventToJSEmptyEventName() {
        bridge.sendEventToJS(event: "", data: "test")
    }

    func testSendEventToJSWithNestedDict() {
        bridge.sendEventToJS(event: "complex", data: ["nested": ["key": "value"]])
    }

    // MARK: - setWebView

    func testSetWebViewPropagatesToCreatedHandlers() {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)

        let _ = bridge.getHandler(for: "share")
        bridge.setWebView(webView)
    }

    func testSetWebViewTwice() {
        let config = WKWebViewConfiguration()
        let webView1 = WKWebView(frame: .zero, configuration: config)
        let webView2 = WKWebView(frame: .zero, configuration: config)

        bridge.setWebView(webView1)
        bridge.setWebView(webView2)
    }

    func testSetWebViewWithPreCreatedHandlers() {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)

        let _ = bridge.getHandler(for: "getSystemInfo")
        let _ = bridge.getHandler(for: "clipboard")
        let _ = bridge.getHandler(for: "haptic")

        bridge.setWebView(webView)
    }

    // MARK: - userContentController

    func testUserContentControllerWithInvalidBody() {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        bridge.setWebView(webView)

        let userContentController = WKUserContentController()
        let message = WKScriptMessage(name: "barkBridge", body: "invalid_string_body", webView: webView, frameInfo: WKFrameInfo())
        bridge.userContentController(userContentController, didReceive: message)
    }

    func testUserContentControllerWithUnsupportedAction() {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        bridge.setWebView(webView)

        let body: [String: Any] = ["action": "unsupported_action_xyz_123"]
        let message = WKScriptMessage(name: "barkBridge", body: body, webView: webView, frameInfo: WKFrameInfo())
        bridge.userContentController(userContentController, didReceive: message)
    }

    func testUserContentControllerWithSupportedActionNoCallbackId() {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        bridge.setWebView(webView)

        let body: [String: Any] = ["action": "getSystemInfo"]
        let message = WKScriptMessage(name: "barkBridge", body: body, webView: webView, frameInfo: WKFrameInfo())
        bridge.userContentController(userContentController, didReceive: message)
    }

    // MARK: - Native Handlers Dictionary

    func testNativeHandlersCountAfterMultipleGets() {
        let _ = bridge.getHandler(for: "share")
        let _ = bridge.getHandler(for: "clipboard")
        let _ = bridge.getHandler(for: "haptic")
        XCTAssertEqual(bridge.nativeHandlers.count, 3)
    }

    func testNativeHandlersNotSharedBetweenBridges() {
        let bridge1 = WebJavaScriptBridge()
        let bridge2 = WebJavaScriptBridge()

        let _ = bridge1.getHandler(for: "share")
        XCTAssertTrue(bridge1.nativeHandlers.count == 1)
        XCTAssertTrue(bridge2.nativeHandlers.isEmpty)
    }
}
