//
//  WebSocketClientTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class WebSocketClientTests: XCTestCase {

    private func makeConfig() -> WebSocketConfiguration {
        WebSocketConfiguration(url: URL(string: "ws://localhost:8080")!)
    }

    func testInit_defaultStateIsDisconnected() async {
        let client = WebSocketClient(
            configuration: makeConfig(),
            onMessage: { _ in },
            onStateChange: { _ in }
        )
        let state = await client.state
        XCTAssertEqual(state, .disconnected)
    }

    func testInit_customIdPreserved() async {
        let client = WebSocketClient(
            configuration: makeConfig(),
            onMessage: { _ in },
            onStateChange: { _ in },
            id: "my-custom-client-123"
        )
        let state = await client.state
        XCTAssertEqual(state, .disconnected)
    }

    func testCall_generatesRequestWithUUID() async {
        var capturedMessage: WebSocketMessage?
        let client = WebSocketClient(
            configuration: makeConfig(),
            onMessage: { msg in capturedMessage = msg },
            onStateChange: { _ in }
        )
        do {
            let result = try await client.call(method: "getUser", params: ["id": "42"])
            if case .request(let id, let method, let params) = result {
                XCTAssertFalse(id.isEmpty)
                XCTAssertEqual(method, "getUser")
                XCTAssertEqual(params["id"], "42")
                XCTAssertNotNil(UUID(uuidString: id))
            } else {
                XCTFail("Expected request message")
            }
        } catch {
            XCTAssertEqual((error as? WSError), WSError.notConnected)
        }
    }

    func testCall_emptyParamsDefaultsToEmptyDict() async {
        let client = WebSocketClient(
            configuration: makeConfig(),
            onMessage: { _ in },
            onStateChange: { _ in }
        )
        do {
            let result = try await client.call(method: "ping")
            if case .request(_, _, let params) = result {
                XCTAssertTrue(params.isEmpty)
            }
        } catch {
            XCTAssertEqual((error as? WSError), WSError.notConnected)
        }
    }

    func testNotify_generatesNotificationMessage() async {
        var capturedMessage: WebSocketMessage?
        let client = WebSocketClient(
            configuration: makeConfig(),
            onMessage: { msg in capturedMessage = msg },
            onStateChange: { _ in }
        )
        do {
            try await client.notify(method: "tick", params: ["value": "100"])
            if case .notification(let method, let params) = capturedMessage {
                XCTAssertEqual(method, "tick")
                XCTAssertEqual(params["value"], "100")
            } else {
                XCTFail("Expected notification message")
            }
        } catch {
            XCTAssertEqual((error as? WSError), WSError.notConnected)
        }
    }

    func testNotify_noParamsGeneratesEmptyParams() async {
        var capturedMessage: WebSocketMessage?
        let client = WebSocketClient(
            configuration: makeConfig(),
            onMessage: { msg in capturedMessage = msg },
            onStateChange: { _ in }
        )
        do {
            try await client.notify(method: "heartbeat")
            if case .notification(_, let params) = capturedMessage {
                XCTAssertTrue(params.isEmpty)
            }
        } catch {
            XCTAssertEqual((error as? WSError), WSError.notConnected)
        }
    }

    func testCall_uniqueIdsPerCall() async {
        let client = WebSocketClient(
            configuration: makeConfig(),
            onMessage: { _ in },
            onStateChange: { _ in }
        )
        do {
            let r1 = try await client.call(method: "a")
            let r2 = try await client.call(method: "b")
            if case .request(let id1, _, _) = r1,
               case .request(let id2, _, _) = r2 {
                XCTAssertNotEqual(id1, id2)
            }
        } catch {
            XCTAssertEqual((error as? WSError), WSError.notConnected)
        }
    }
}
