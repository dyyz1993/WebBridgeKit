//
//  WebSocketState.swift
//  WebBridgeKit
//

import Foundation

public enum WebSocketState: String, Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case reconnecting

    public var isOperational: Bool {
        self == .connected
    }
}
