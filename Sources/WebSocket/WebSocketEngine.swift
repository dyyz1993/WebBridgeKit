//
//  WebSocketEngine.swift
//  WebBridgeKit
//

import Foundation

public actor WebSocketEngine {
    public nonisolated let onMessage: @Sendable (WebSocketMessage) -> Void
    public nonisolated let onStateChange: @Sendable (WebSocketState) -> Void

    private var state: WebSocketState = .disconnected {
        didSet { onStateChange(state) }
    }

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private let configuration: WebSocketConfiguration
    private var reconnectAttempt: Int = 0
    private var pendingMessages: [WebSocketMessage] = []
    private var heartbeatTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var isManualDisconnect: Bool = false

    public init(
        configuration: WebSocketConfiguration,
        onMessage: @escaping @Sendable (WebSocketMessage) -> Void,
        onStateChange: @escaping @Sendable (WebSocketState) -> Void
    ) {
        self.configuration = configuration
        self.onMessage = onMessage
        self.onStateChange = onStateChange
    }

    public var currentState: WebSocketState { state }

    public func connect() async {
        guard state == .disconnected || state == .reconnecting else { return }
        isManualDisconnect = false
        state = .connecting

        let request = URLRequest(url: configuration.url)
        var urlRequest = request
        for (key, value) in configuration.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        session = URLSession(configuration: .default)
        task = session?.webSocketTask(with: urlRequest)
        task?.resume()
        state = .connected
        reconnectAttempt = 0
        await flushPendingMessages()
        startHeartbeat()
        receiveTask = Task { [weak self] in await self?.receiveLoop() }
    }

    public func disconnect(code: URLSessionWebSocketTask.CloseCode = .normalClosure) async {
        isManualDisconnect = true
        state = .disconnecting
        heartbeatTask?.cancel()
        heartbeatTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        try? await task?.cancel(with: code, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        state = .disconnected
    }

    public func send(_ message: WebSocketMessage) async throws {
        guard state == .connected, let task = task else {
            if state == .reconnecting || state == .connecting {
                if pendingMessages.count < configuration.messageQueueSize {
                    pendingMessages.append(message)
                    return
                }
            }
            throw WSError.notConnected
        }
        guard let data = message.encode() else {
            throw WSError.encodingFailed
        }
        try await task.send(.data(data))
    }

    private func flushPendingMessages() async {
        let messages = pendingMessages
        pendingMessages.removeAll()
        for msg in messages {
            guard let task = task, let data = msg.encode() else { continue }
            try? await task.send(.data(data))
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self?.configuration.heartbeatInterval ?? 30) * 1_000_000_000)
                guard !Task.isCancelled else { break }
                try? await self?.task?.send(.string("ping"))
            }
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            do {
                guard let task = task else { return }
                let wsMessage = try await task.receive()
                switch wsMessage {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let message = WebSocketMessage.decode(data) {
                        onMessage(message)
                    }
                case .data(let data):
                    if let message = WebSocketMessage.decode(data) {
                        onMessage(message)
                    }
                @unknown default:
                    break
                }
            } catch {
                if !isManualDisconnect && !Task.isCancelled {
                    await handleReconnect()
                    return
                }
            }
        }
    }

    private func handleReconnect() {
        guard !isManualDisconnect,
              reconnectAttempt < configuration.reconnectPolicy.maxRetries else {
            state = .disconnected
            return
        }
        state = .reconnecting
        let delay = configuration.reconnectPolicy.interval(for: reconnectAttempt)
        reconnectAttempt += 1
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            await self.connect()
        }
    }
}

public enum WSError: Error, LocalizedError {
    case notConnected
    case encodingFailed
    case invalidURL
    case maxRetriesReached

    public var errorDescription: String? {
        switch self {
        case .notConnected: return "WebSocket is not connected"
        case .encodingFailed: return "Failed to encode message"
        case .invalidURL: return "Invalid WebSocket URL"
        case .maxRetriesReached: return "Maximum reconnect retries reached"
        }
    }
}
