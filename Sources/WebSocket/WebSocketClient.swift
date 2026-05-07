//
//  WebSocketClient.swift
//  WebBridgeKit
//

import Foundation

public final class WebSocketClient: Sendable {
    private let engine: WebSocketEngine
    private let id: String

    public var state: WebSocketState { get async { await engine.currentState } }

    public init(
        configuration: WebSocketConfiguration,
        onMessage: @escaping @Sendable (WebSocketMessage) -> Void,
        onStateChange: @escaping @Sendable (WebSocketState) -> Void,
        id: String = UUID().uuidString
    ) {
        self.id = id
        self.engine = WebSocketEngine(
            configuration: configuration,
            onMessage: onMessage,
            onStateChange: onStateChange
        )
    }

    public func connect() async { await engine.connect() }
    public func disconnect(code: URLSessionWebSocketTask.CloseCode = .normalClosure) async {
        await engine.disconnect(code: code)
    }
    public func send(_ message: WebSocketMessage) async throws { try await engine.send(message) }

    public func call(
        method: String,
        params: [String: String] = [:]
    ) async throws -> WebSocketMessage {
        let requestId = UUID().uuidString
        let request = WebSocketMessage.request(id: requestId, method: method, params: params)
        try await send(request)
        return request
    }

    public func notify(method: String, params: [String: String] = [:]) async throws {
        let message = WebSocketMessage.notification(method: method, params: params)
        try await send(message)
    }
}
