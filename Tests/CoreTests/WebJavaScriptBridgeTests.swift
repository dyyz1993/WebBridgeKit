//
//  WebJavaScriptBridgeTests.swift
//  CoreTests
//

import XCTest
@testable import WebBridgeKit

final class WebJavaScriptBridgeTests: XCTestCase {

    private var bridge: WebJavaScriptBridge!

    override func setUp() {
        super.setUp()
        bridge = WebJavaScriptBridge()
    }

    override func tearDown() {
        bridge = nil
        super.tearDown()
    }

    // MARK: - Initialization

    func testInitializationRegistersHandlerFactories() {
        XCTAssertFalse(bridge.nativeHandlers.isEmpty || bridge.nativeHandlers.count > 0)
        XCTAssertTrue(bridge.nativeHandlers.isEmpty, "Handlers should be lazy-loaded")
    }

    func testGetHandlerReturnsHandlerForRegisteredAction() {
        let handler = bridge.getHandler(for: "share")
        XCTAssertNotNil(handler)
    }

    func testGetHandlerReturnsNilForUnknownAction() {
        let handler = bridge.getHandler(for: "nonexistent_action_xyz")
        XCTAssertNil(handler)
    }

    func testGetHandlerCreatesSameInstanceOnSecondCall() {
        let first = bridge.getHandler(for: "share")
        let second = bridge.getHandler(for: "share")
        XCTAssertTrue(first === second, "Lazy loading should return the same instance")
    }

    func testGetHandlerForMultipleActions() {
        XCTAssertNotNil(bridge.getHandler(for: "getLocation"))
        XCTAssertNotNil(bridge.getHandler(for: "getSystemInfo"))
        XCTAssertNotNil(bridge.getHandler(for: "haptic"))
        XCTAssertNotNil(bridge.getHandler(for: "clipboard"))
    }

    // MARK: - Send Error to JS

    func testSendErrorToJSDoesNotCrashWithoutWebView() {
        bridge.sendErrorToJS("test error", callbackId: "cb-1")
    }

    func testSendResultToJSWithDictionary() {
        let result: [String: Any] = ["success": true, "data": "test"]
        bridge.sendResultToJS(result, callbackId: "cb-2")
    }

    func testSendResultToJSWithNilCallbackId() {
        let result: [String: Any] = ["success": true]
        bridge.sendResultToJS(result, callbackId: nil)
    }

    // MARK: - Send Event to JS

    func testSendEventToJSDoesNotCrashWithoutWebView() {
        bridge.sendEventToJS(event: "testEvent", data: "testData")
    }

    func testSendEventToJSWithDictionaryData() {
        bridge.sendEventToJS(event: "pageLoaded", data: ["url": "https://example.com"])
    }

    // MARK: - setWebView

    func testSetWebViewDoesNotCrash() {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        bridge.setWebView(webView)
    }

    // MARK: - Callback ID

    func testCurrentCallbackIdInitiallyNil() {
        XCTAssertNil(bridge.currentCallbackId)
    }
}

import WebKit
