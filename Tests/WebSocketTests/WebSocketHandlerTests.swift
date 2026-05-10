//
//  WebSocketHandlerTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class WebSocketHandlerTests: XCTestCase {

    // MARK: - handle Missing Action

    func testHandle_missingAction_returnsFailure() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion called")
        handler.handle(body: [:]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            } else {
                XCTFail("Expected dictionary result")
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandle_nilActionKey_returnsFailure() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion called")
        handler.handle(body: ["action": NSNull()]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - handle Unknown Action

    func testHandle_unknownAction_returnsFailure() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion called")
        handler.handle(body: ["action": "nonexistent"]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandle_randomUnknownAction_returnsFailure() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion called")
        handler.handle(body: ["action": "flyToMoon"]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - connect Missing URL

    func testHandleConnect_missingUrl_returnsFailure() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion called")
        handler.handle(body: ["action": "connect"]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandleConnect_urlKeyNonString_returnsFailure() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion called")
        handler.handle(body: ["action": "connect", "url": 12345]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - connect Invalid URL

    func testHandleConnect_emptyUrl_returnsFailure() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion called")
        handler.handle(body: ["action": "connect", "url": ""]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandleConnect_invalidUrlScheme_returnsSuccess() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion called")
        handler.handle(body: ["action": "connect", "url": "not-a-url"]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, true)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandleConnect_spacesOnlyUrl_returnsSuccess() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion called")
        handler.handle(body: ["action": "connect", "url": "   "]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, true)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - disconnect

    func testHandleDisconnect_returnsSuccessAndDisconnectedStatus() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion called")
        handler.handle(body: ["action": "disconnect"]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, true)
                if let data = dict["data"] as? [String: Any] {
                    XCTAssertEqual(data["status"] as? String, "disconnected")
                } else {
                    XCTFail("Missing data key")
                }
            } else {
                XCTFail("Expected dictionary result")
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandleDisconnect_withoutPriorConnect_stillSucceeds() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion called")
        handler.handle(body: ["action": "disconnect"]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, true)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - send Missing Method

    func testHandleSend_missingMethod_returnsFailure() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion called")
        handler.handle(body: ["action": "send"]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandleSend_methodKeyNonString_returnsFailure() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion called")
        handler.handle(body: ["action": "send", "method": 999]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandleSend_emptyMethod_returnsSuccess() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion called")
        handler.handle(body: ["action": "send", "method": ""]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, true)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - registerMeta()

    func testRegisterMeta_actionIsWebsocket() {
        let meta = WebSocketHandler.registerMeta()
        XCTAssertEqual(meta.action, "websocket")
    }

    func testRegisterMeta_categoryIsSystem() {
        let meta = WebSocketHandler.registerMeta()
        XCTAssertEqual(meta.category, .system)
    }

    func testRegisterMeta_displayNameIsWebSocket() {
        let meta = WebSocketHandler.registerMeta()
        XCTAssertEqual(meta.displayName, "WebSocket")
    }

    func testRegisterMeta_requiresNetworkIsTrue() {
        let meta = WebSocketHandler.registerMeta()
        XCTAssertTrue(meta.requiresNetwork)
    }

    func testRegisterMeta_requiredPermissionsContainsNetwork() {
        let meta = WebSocketHandler.registerMeta()
        XCTAssertTrue(meta.requiredPermissions.contains("network"))
    }

    func testRegisterMeta_parametersCountIs5() {
        let meta = WebSocketHandler.registerMeta()
        XCTAssertEqual(meta.parameters.count, 5)
    }

    func testRegisterMeta_parameterActionIsRequired() {
        let meta = WebSocketHandler.registerMeta()
        let actionParam = meta.parameters.first { $0.name == "action" }
        XCTAssertNotNil(actionParam)
        XCTAssertTrue(actionParam?.required ?? false)
    }

    func testRegisterMeta_parameterUrlIsOptional() {
        let meta = WebSocketHandler.registerMeta()
        let urlParam = meta.parameters.first { $0.name == "url" }
        XCTAssertNotNil(urlParam)
        XCTAssertFalse(urlParam?.required ?? true)
    }

    func testRegisterMeta_parameterMethodIsOptional() {
        let meta = WebSocketHandler.registerMeta()
        let methodParam = meta.parameters.first { $0.name == "method" }
        XCTAssertNotNil(methodParam)
        XCTAssertFalse(methodParam?.required ?? true)
    }

    func testRegisterMeta_descriptionIsPresent() {
        let meta = WebSocketHandler.registerMeta()
        XCTAssertFalse(meta.description.isEmpty)
    }
}
