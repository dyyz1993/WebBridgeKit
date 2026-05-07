//
//  WebSocketConfiguration.swift
//  WebBridgeKit
//

import Foundation

public struct ReconnectPolicy: Equatable, Sendable {
    public let maxRetries: Int
    public let baseInterval: TimeInterval
    public let maxInterval: TimeInterval
    public let multiplier: Double

    public static let `default` = ReconnectPolicy(
        maxRetries: 5,
        baseInterval: 1.0,
        maxInterval: 30.0,
        multiplier: 2.0
    )

    public init(
        maxRetries: Int = 5,
        baseInterval: TimeInterval = 1.0,
        maxInterval: TimeInterval = 30.0,
        multiplier: Double = 2.0
    ) {
        self.maxRetries = maxRetries
        self.baseInterval = baseInterval
        self.maxInterval = maxInterval
        self.multiplier = multiplier
    }

    func interval(for attempt: Int) -> TimeInterval {
        let raw = baseInterval * pow(multiplier, Double(min(attempt, maxRetries)))
        let jitter = Double.random(in: 0 ..< 0.1 * raw)
        return min(raw + jitter, maxInterval)
    }
}

public struct WebSocketConfiguration: Sendable {
    public let url: URL
    public let headers: [String: String]
    public let reconnectPolicy: ReconnectPolicy
    public let heartbeatInterval: TimeInterval
    public let messageQueueSize: Int

    public init(
        url: URL,
        headers: [String: String] = [:],
        reconnectPolicy: ReconnectPolicy = .default,
        heartbeatInterval: TimeInterval = 30.0,
        messageQueueSize: Int = 100
    ) {
        self.url = url
        self.headers = headers
        self.reconnectPolicy = reconnectPolicy
        self.heartbeatInterval = heartbeatInterval
        self.messageQueueSize = messageQueueSize
    }
}
