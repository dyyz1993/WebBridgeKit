//
//  WebSocketEngineTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class WebSocketEngineTests: XCTestCase {

    // MARK: - WebSocketMessage Encoding

    func testEncodeRequest() {
        let msg = WebSocketMessage.request(id: "1", method: "test", params: ["key": "val"])
        let data = msg.encode()
        XCTAssertNotNil(data)
        if let data = data,
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(obj["jsonrpc"] as? String, "2.0")
            XCTAssertEqual(obj["id"] as? String, "1")
            XCTAssertEqual(obj["method"] as? String, "test")
        }
    }

    func testEncodeResponse() {
        let msg = WebSocketMessage.response(id: "1", result: ["data": "ok"])
        let data = msg.encode()
        XCTAssertNotNil(data)
        if let data = data,
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(obj["jsonrpc"] as? String, "2.0")
            XCTAssertEqual(obj["id"] as? String, "1")
        }
    }

    func testEncodeResponseError() {
        let msg = WebSocketMessage.responseError(id: "1", code: -1, message: "fail")
        let data = msg.encode()
        XCTAssertNotNil(data)
        if let data = data,
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(obj["jsonrpc"] as? String, "2.0")
            let error = obj["error"] as? [String: Any]
            XCTAssertEqual(error?["code"] as? Int, -1)
            XCTAssertEqual(error?["message"] as? String, "fail")
        }
    }

    func testEncodeNotification() {
        let msg = WebSocketMessage.notification(method: "event", params: ["x": "y"])
        let data = msg.encode()
        XCTAssertNotNil(data)
        if let data = data,
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(obj["jsonrpc"] as? String, "2.0")
            XCTAssertNil(obj["id"])
            XCTAssertEqual(obj["method"] as? String, "event")
        }
    }

    func testEncodeRequestWithEmptyParams() {
        let msg = WebSocketMessage.request(id: "2", method: "ping", params: [:])
        let data = msg.encode()
        XCTAssertNotNil(data)
        if let data = data,
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertNil(obj["params"])
        }
    }

    // MARK: - WebSocketMessage Decoding

    func testDecodeRequest() {
        let json = """
        {"jsonrpc":"2.0","id":"1","method":"test","params":{"k":"v"}}
        """
        let msg = WebSocketMessage.decode(Data(json.utf8))
        if case .request(let id, let method, _) = msg {
            XCTAssertEqual(id, "1")
            XCTAssertEqual(method, "test")
        } else {
            XCTFail("Expected request")
        }
    }

    func testDecodeResponse() {
        let json = """
        {"jsonrpc":"2.0","id":"1","result":{"status":"ok"}}
        """
        let msg = WebSocketMessage.decode(Data(json.utf8))
        if case .response(let id, let result) = msg {
            XCTAssertEqual(id, "1")
            XCTAssertEqual(result?["status"], "ok")
        } else {
            XCTFail("Expected response")
        }
    }

    func testDecodeResponseError() {
        let json = """
        {"jsonrpc":"2.0","id":"1","error":{"code":-32600,"message":"Invalid Request"}}
        """
        let msg = WebSocketMessage.decode(Data(json.utf8))
        if case .responseError(let id, let code, let message) = msg {
            XCTAssertEqual(id, "1")
            XCTAssertEqual(code, -32600)
            XCTAssertEqual(message, "Invalid Request")
        } else {
            XCTFail("Expected responseError")
        }
    }

    func testDecodeNotification() {
        let json = """
        {"jsonrpc":"2.0","method":"update","params":{"val":"1"}}
        """
        let msg = WebSocketMessage.decode(Data(json.utf8))
        if case .notification(let method, _) = msg {
            XCTAssertEqual(method, "update")
        } else {
            XCTFail("Expected notification")
        }
    }

    func testDecodeInvalidJSON() {
        let msg = WebSocketMessage.decode(Data("not json".utf8))
        XCTAssertNil(msg)
    }

    func testDecodeWrongVersion() {
        let json = """
        {"jsonrpc":"1.0","id":"1","method":"test"}
        """
        let msg = WebSocketMessage.decode(Data(json.utf8))
        XCTAssertNil(msg)
    }

    func testDecodeEmptyData() {
        let msg = WebSocketMessage.decode(Data())
        XCTAssertNil(msg)
    }

    func testDecodeMissingMethod() {
        let json = """
        {"jsonrpc":"2.0","params":{"k":"v"}}
        """
        let msg = WebSocketMessage.decode(Data(json.utf8))
        XCTAssertNil(msg)
    }

    // MARK: - WebSocketMessage Properties

    func testIsNotification() {
        let req = WebSocketMessage.request(id: "1", method: "m", params: [:])
        let notif = WebSocketMessage.notification(method: "e", params: [:])
        XCTAssertFalse(req.isNotification)
        XCTAssertTrue(notif.isNotification)
    }

    func testMessageId() {
        XCTAssertEqual(WebSocketMessage.request(id: "a", method: "m", params: [:]).messageId, "a")
        XCTAssertEqual(WebSocketMessage.response(id: "b", result: nil).messageId, "b")
        XCTAssertEqual(WebSocketMessage.responseError(id: "c", code: 1, message: "").messageId, "c")
        XCTAssertNil(WebSocketMessage.notification(method: "e", params: [:]).messageId)
    }

    func testMessageEquality() {
        let a = WebSocketMessage.request(id: "1", method: "m", params: ["k": "v"])
        let b = WebSocketMessage.request(id: "1", method: "m", params: ["k": "v"])
        let c = WebSocketMessage.request(id: "2", method: "m", params: ["k": "v"])
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testMessageInequalityAcrossTypes() {
        let req = WebSocketMessage.request(id: "1", method: "m", params: [:])
        let notif = WebSocketMessage.notification(method: "m", params: [:])
        XCTAssertNotEqual(req, notif)
    }

    // MARK: - ReconnectPolicy

    func testReconnectPolicyDefaultValues() {
        let policy = ReconnectPolicy.default
        XCTAssertEqual(policy.maxRetries, 5)
        XCTAssertEqual(policy.baseInterval, 1.0)
        XCTAssertEqual(policy.maxInterval, 30.0)
        XCTAssertEqual(policy.multiplier, 2.0)
    }

    func testReconnectPolicyCustomValues() {
        let policy = ReconnectPolicy(maxRetries: 10, baseInterval: 2.0, maxInterval: 60.0, multiplier: 3.0)
        XCTAssertEqual(policy.maxRetries, 10)
        XCTAssertEqual(policy.baseInterval, 2.0)
        XCTAssertEqual(policy.maxInterval, 60.0)
        XCTAssertEqual(policy.multiplier, 3.0)
    }

    func testReconnectPolicyIntervalIncreases() {
        let policy = ReconnectPolicy.default
        let i0 = policy.interval(for: 0)
        let i1 = policy.interval(for: 1)
        let i2 = policy.interval(for: 2)
        XCTAssertLessThan(i0, i1)
        XCTAssertLessThan(i1, i2)
    }

    func testReconnectPolicyIntervalCapped() {
        let policy = ReconnectPolicy(maxRetries: 5, baseInterval: 1.0, maxInterval: 5.0, multiplier: 10.0)
        let interval = policy.interval(for: 100)
        XCTAssertLessThanOrEqual(interval, 5.0 + 0.5)
    }

    func testReconnectPolicyEquatable() {
        let a = ReconnectPolicy(maxRetries: 3, baseInterval: 1.0, maxInterval: 10.0, multiplier: 2.0)
        let b = ReconnectPolicy(maxRetries: 3, baseInterval: 1.0, maxInterval: 10.0, multiplier: 2.0)
        XCTAssertEqual(a, b)
    }

    // MARK: - WebSocketConfiguration

    func testConfigurationDefaults() {
        let config = WebSocketConfiguration(url: URL(string: "ws://localhost")!)
        XCTAssertEqual(config.url.absoluteString, "ws://localhost")
        XCTAssertTrue(config.headers.isEmpty)
        XCTAssertEqual(config.heartbeatInterval, 30.0)
        XCTAssertEqual(config.messageQueueSize, 100)
    }

    func testConfigurationCustom() {
        let config = WebSocketConfiguration(
            url: URL(string: "ws://example.com")!,
            headers: ["Auth": "token"],
            heartbeatInterval: 10.0,
            messageQueueSize: 50
        )
        XCTAssertEqual(config.headers["Auth"], "token")
        XCTAssertEqual(config.heartbeatInterval, 10.0)
        XCTAssertEqual(config.messageQueueSize, 50)
    }

    // MARK: - WebSocketState

    func testWebSocketStateValues() {
        XCTAssertEqual(WebSocketState.disconnected.rawValue, "disconnected")
        XCTAssertEqual(WebSocketState.connecting.rawValue, "connecting")
        XCTAssertEqual(WebSocketState.connected.rawValue, "connected")
        XCTAssertEqual(WebSocketState.disconnecting.rawValue, "disconnecting")
        XCTAssertEqual(WebSocketState.reconnecting.rawValue, "reconnecting")
    }

    func testWebSocketStateIsOperational() {
        XCTAssertTrue(WebSocketState.connected.isOperational)
        XCTAssertFalse(WebSocketState.disconnected.isOperational)
        XCTAssertFalse(WebSocketState.connecting.isOperational)
    }

    // MARK: - WSError

    func testWSErrorDescriptions() {
        XCTAssertEqual(WSError.notConnected.errorDescription, "WebSocket is not connected")
        XCTAssertEqual(WSError.encodingFailed.errorDescription, "Failed to encode message")
        XCTAssertEqual(WSError.invalidURL.errorDescription, "Invalid WebSocket URL")
        XCTAssertEqual(WSError.maxRetriesReached.errorDescription, "Maximum reconnect retries reached")
    }

    // MARK: - WebSocketEngine State

    func testEngineInitialState() async {
        let config = WebSocketConfiguration(url: URL(string: "ws://localhost:8080")!)
        var receivedStates: [WebSocketState] = []
        let engine = WebSocketEngine(
            configuration: config,
            onMessage: { _ in },
            onStateChange: { state in
                receivedStates.append(state)
            }
        )
        let state = await engine.currentState
        XCTAssertEqual(state, .disconnected)
    }

    // MARK: - WebSocketClient

    func testClientCreation() async {
        let config = WebSocketConfiguration(url: URL(string: "ws://localhost")!)
        let client = WebSocketClient(
            configuration: config,
            onMessage: { _ in },
            onStateChange: { _ in },
            id: "test-client"
        )
        let state = await client.state
        XCTAssertEqual(state, .disconnected)
    }

    func testClientCallReturnsRequest() async {
        let config = WebSocketConfiguration(url: URL(string: "ws://localhost")!)
        let client = WebSocketClient(
            configuration: config,
            onMessage: { _ in },
            onStateChange: { _ in }
        )
        do {
            let result = try await client.call(method: "test", params: ["k": "v"])
            if case .request(let id, let method, _) = result {
                XCTAssertFalse(id.isEmpty)
                XCTAssertEqual(method, "test")
            } else {
                XCTFail("Expected request message")
            }
        } catch {
            XCTAssertEqual((error as? WSError), WSError.notConnected)
        }
    }

    // MARK: - WebSocketHandler

    func testHandlerRejectsMissingAction() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion")
        handler.handle(body: [:]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandlerRejectsUnknownAction() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion")
        handler.handle(body: ["action": "unknown"]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandlerConnectRejectsMissingURL() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion")
        handler.handle(body: ["action": "connect"]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandlerConnectRejectsInvalidURL() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion")
        handler.handle(body: ["action": "connect", "url": ""]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandlerDisconnectReturnsStatus() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion")
        handler.handle(body: ["action": "disconnect"]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, true)
                if let data = dict["data"] as? [String: Any] {
                    XCTAssertEqual(data["status"] as? String, "disconnected")
                }
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandlerSendRejectsMissingMethod() async {
        let handler = WebSocketHandler()
        let expectation = expectation(description: "completion")
        handler.handle(body: ["action": "send"]) { result in
            if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, false)
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandlerRegisterMeta() {
        let meta = WebSocketHandler.registerMeta()
        XCTAssertEqual(meta.action, "websocket")
        XCTAssertEqual(meta.category, .system)
        XCTAssertEqual(meta.displayName, "WebSocket")
        XCTAssertTrue(meta.requiresNetwork)
        XCTAssertEqual(meta.requiredPermissions, ["network"])
        XCTAssertEqual(meta.parameters.count, 5)
    }

    // MARK: - Roundtrip encode/decode

    func testRoundtripRequest() {
        let original = WebSocketMessage.request(id: "r1", method: "getUser", params: ["id": "42"])
        let data = original.encode()
        XCTAssertNotNil(data)
        if let data = data {
            let decoded = WebSocketMessage.decode(data)
            XCTAssertEqual(original, decoded)
        }
    }

    func testRoundtripResponse() {
        let original = WebSocketMessage.response(id: "r1", result: ["name": "test"])
        let data = original.encode()
        XCTAssertNotNil(data)
        if let data = data {
            let decoded = WebSocketMessage.decode(data)
            XCTAssertEqual(original, decoded)
        }
    }

    func testRoundtripResponseError() {
        let original = WebSocketMessage.responseError(id: "e1", code: -32000, message: "server error")
        let data = original.encode()
        XCTAssertNotNil(data)
        if let data = data {
            let decoded = WebSocketMessage.decode(data)
            XCTAssertEqual(original, decoded)
        }
    }

    func testRoundtripNotification() {
        let original = WebSocketMessage.notification(method: "tick", params: ["value": "100"])
        let data = original.encode()
        XCTAssertNotNil(data)
        if let data = data {
            let decoded = WebSocketMessage.decode(data)
            XCTAssertEqual(original, decoded)
        }
    }
}
