//
//  WebSocketMessageTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class WebSocketMessageTests: XCTestCase {

    // MARK: - Roundtrip: Request

    func testRoundtrip_requestWithParams() {
        let original = WebSocketMessage.request(id: "r1", method: "getUser", params: ["id": "42"])
        guard let data = original.encode() else { return XCTFail("encode returned nil") }
        let decoded = WebSocketMessage.decode(data)
        XCTAssertEqual(original, decoded)
    }

    func testRoundtrip_requestWithEmptyParams() {
        let original = WebSocketMessage.request(id: "r2", method: "ping", params: [:])
        guard let data = original.encode() else { return XCTFail("encode returned nil") }
        let decoded = WebSocketMessage.decode(data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Roundtrip: Response

    func testRoundtrip_responseWithResult() {
        let original = WebSocketMessage.response(id: "s1", result: ["name": "test"])
        guard let data = original.encode() else { return XCTFail("encode returned nil") }
        let decoded = WebSocketMessage.decode(data)
        XCTAssertEqual(original, decoded)
    }

    func testRoundtrip_responseWithNilResult() {
        let original = WebSocketMessage.response(id: "s2", result: nil)
        guard let data = original.encode() else { return XCTFail("encode returned nil") }
        let decoded = WebSocketMessage.decode(data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Roundtrip: ResponseError

    func testRoundtrip_responseError() {
        let original = WebSocketMessage.responseError(id: "e1", code: -32000, message: "server error")
        guard let data = original.encode() else { return XCTFail("encode returned nil") }
        let decoded = WebSocketMessage.decode(data)
        XCTAssertEqual(original, decoded)
    }

    func testRoundtrip_responseErrorStandardCode() {
        let original = WebSocketMessage.responseError(id: "e2", code: -32600, message: "Invalid Request")
        guard let data = original.encode() else { return XCTFail("encode returned nil") }
        let decoded = WebSocketMessage.decode(data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Roundtrip: Notification

    func testRoundtrip_notificationWithParams() {
        let original = WebSocketMessage.notification(method: "tick", params: ["value": "100"])
        guard let data = original.encode() else { return XCTFail("encode returned nil") }
        let decoded = WebSocketMessage.decode(data)
        XCTAssertEqual(original, decoded)
    }

    func testRoundtrip_notificationWithEmptyParams() {
        let original = WebSocketMessage.notification(method: "heartbeat", params: [:])
        guard let data = original.encode() else { return XCTFail("encode returned nil") }
        let decoded = WebSocketMessage.decode(data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - messageId Property

    func testMessageId_requestHasId() {
        let msg = WebSocketMessage.request(id: "abc", method: "m", params: [:])
        XCTAssertEqual(msg.messageId, "abc")
    }

    func testMessageId_responseHasId() {
        let msg = WebSocketMessage.response(id: "def", result: nil)
        XCTAssertEqual(msg.messageId, "def")
    }

    func testMessageId_responseErrorHasId() {
        let msg = WebSocketMessage.responseError(id: "ghi", code: 1, message: "")
        XCTAssertEqual(msg.messageId, "ghi")
    }

    func testMessageId_notificationIsNil() {
        let msg = WebSocketMessage.notification(method: "e", params: [:])
        XCTAssertNil(msg.messageId)
    }

    // MARK: - isNotification Property

    func testIsNotification_requestIsFalse() {
        XCTAssertFalse(WebSocketMessage.request(id: "1", method: "m", params: [:]).isNotification)
    }

    func testIsNotification_responseIsFalse() {
        XCTAssertFalse(WebSocketMessage.response(id: "1", result: nil).isNotification)
    }

    func testIsNotification_responseErrorIsFalse() {
        XCTAssertFalse(WebSocketMessage.responseError(id: "1", code: 1, message: "").isNotification)
    }

    func testIsNotification_notificationIsTrue() {
        XCTAssertTrue(WebSocketMessage.notification(method: "e", params: [:]).isNotification)
    }

    // MARK: - Equatable Across Types

    func testInequality_requestVsResponse() {
        let req = WebSocketMessage.request(id: "1", method: "m", params: [:])
        let res = WebSocketMessage.response(id: "1", result: nil)
        XCTAssertNotEqual(req, res)
    }

    func testInequality_requestVsResponseError() {
        let req = WebSocketMessage.request(id: "1", method: "m", params: [:])
        let err = WebSocketMessage.responseError(id: "1", code: 1, message: "")
        XCTAssertNotEqual(req, err)
    }

    func testInequality_requestVsNotification() {
        let req = WebSocketMessage.request(id: "1", method: "m", params: [:])
        let notif = WebSocketMessage.notification(method: "m", params: [:])
        XCTAssertNotEqual(req, notif)
    }

    func testInequality_responseVsNotification() {
        let res = WebSocketMessage.response(id: "1", result: nil)
        let notif = WebSocketMessage.notification(method: "m", params: [:])
        XCTAssertNotEqual(res, notif)
    }

    func testInequality_responseErrorVsNotification() {
        let err = WebSocketMessage.responseError(id: "1", code: 1, message: "")
        let notif = WebSocketMessage.notification(method: "m", params: [:])
        XCTAssertNotEqual(err, notif)
    }

    // MARK: - Same Type Equality

    func testEquality_requestSameIdAndMethod() {
        let a = WebSocketMessage.request(id: "1", method: "m", params: ["k": "v"])
        let b = WebSocketMessage.request(id: "1", method: "m", params: ["k": "v"])
        XCTAssertEqual(a, b)
    }

    func testEquality_requestDifferentId() {
        let a = WebSocketMessage.request(id: "1", method: "m", params: [:])
        let b = WebSocketMessage.request(id: "2", method: "m", params: [:])
        XCTAssertNotEqual(a, b)
    }

    func testEquality_requestDifferentMethod() {
        let a = WebSocketMessage.request(id: "1", method: "a", params: [:])
        let b = WebSocketMessage.request(id: "1", method: "b", params: [:])
        XCTAssertNotEqual(a, b)
    }

    func testEquality_requestDifferentParams() {
        let a = WebSocketMessage.request(id: "1", method: "m", params: ["k": "v"])
        let b = WebSocketMessage.request(id: "1", method: "m", params: ["k": "w"])
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Boundary Cases

    func testBoundary_emptyParams_encodedOmitsKey() {
        let msg = WebSocketMessage.request(id: "1", method: "m", params: [:])
        guard let data = msg.encode(),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return XCTFail("encode failed")
        }
        XCTAssertNil(obj["params"])
    }

    func testBoundary_nilResult_encodedAsNull() {
        let msg = WebSocketMessage.response(id: "1", result: nil)
        guard let data = msg.encode(),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return XCTFail("encode failed")
        }
        XCTAssertNil(obj["result"])
    }

    func testBoundary_specialCharactersInParams() {
        let msg = WebSocketMessage.request(id: "1", method: "test", params: [
            "key": "hello & <world> \"quotes\"",
            "emoji": "🎉"
        ])
        guard let data = msg.encode() else { return XCTFail("encode returned nil") }
        let decoded = WebSocketMessage.decode(data)
        XCTAssertEqual(msg, decoded)
    }

    func testBoundary_specialCharactersInErrorMessage() {
        let msg = WebSocketMessage.responseError(id: "1", code: -1, message: "Error: 中文测试 🚀")
        guard let data = msg.encode() else { return XCTFail("encode returned nil") }
        let decoded = WebSocketMessage.decode(data)
        XCTAssertEqual(msg, decoded)
    }

    func testBoundary_longMethodAndId() {
        let longId = String(repeating: "a", count: 500)
        let longMethod = String(repeating: "m", count: 300)
        let msg = WebSocketMessage.request(id: longId, method: longMethod, params: [:])
        guard let data = msg.encode() else { return XCTFail("encode returned nil") }
        let decoded = WebSocketMessage.decode(data)
        XCTAssertEqual(msg, decoded)
    }

    func testBoundary_unicodeMethod() {
        let msg = WebSocketMessage.notification(method: "用户登录事件", params: ["用户名": "张三"])
        guard let data = msg.encode() else { return XCTFail("encode returned nil") }
        let decoded = WebSocketMessage.decode(data)
        XCTAssertEqual(msg, decoded)
    }
}
