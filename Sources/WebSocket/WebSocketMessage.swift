//
//  WebSocketMessage.swift
//  WebBridgeKit
//

import Foundation

public enum WebSocketMessage: Sendable, Equatable {
    case request(id: String, method: String, params: [String: String])
    case response(id: String, result: [String: String]?)
    case responseError(id: String, code: Int, message: String)
    case notification(method: String, params: [String: String])

    public var isNotification: Bool {
        if case .notification = self { return true }
        return false
    }

    public var messageId: String? {
        switch self {
        case .request(let id, _, _): return id
        case .response(let id, _): return id
        case .responseError(let id, _, _): return id
        case .notification: return nil
        }
    }

    public func encode() -> Data? {
        let dict: [String: Any?]
        switch self {
        case .request(let id, let method, let params):
            dict = [
                "jsonrpc": "2.0",
                "id": id,
                "method": method,
                "params": params.isEmpty ? nil : params
            ]
        case .response(let id, let result):
            dict = [
                "jsonrpc": "2.0",
                "id": id,
                "result": result
            ]
        case .responseError(let id, let code, let message):
            dict = [
                "jsonrpc": "2.0",
                "id": id,
                "error": ["code": code, "message": message]
            ]
        case .notification(let method, let params):
            dict = [
                "jsonrpc": "2.0",
                "method": method,
                "params": params.isEmpty ? nil : params
            ]
        }
        let cleaned: [String: Any] = dict.compactMapValues { $0 }
        return try? JSONSerialization.data(withJSONObject: cleaned)
    }

    public static func decode(_ data: Data) -> WebSocketMessage? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let jsonrpc = obj["jsonrpc"] as? String,
              jsonrpc == "2.0" else {
            return nil
        }
        if let id = obj["id"] as? String, obj["method"] != nil {
            let params = obj["params"] as? [String: String] ?? [:]
            return .request(id: id, method: obj["method"] as! String, params: params)
        }
        if let id = obj["id"] as? String {
            if let error = obj["error"] as? [String: Any],
               let code = error["code"] as? Int,
               let message = error["message"] as? String {
                return .responseError(id: id, code: code, message: message)
            }
            let result = obj["result"] as? [String: String]
            return .response(id: id, result: result)
        }
        guard let method = obj["method"] as? String else { return nil }
        let params = obj["params"] as? [String: String] ?? [:]
        return .notification(method: method, params: params)
    }

    public static func == (lhs: WebSocketMessage, rhs: WebSocketMessage) -> Bool {
        switch (lhs, rhs) {
        case (.request(let a, let b, let c), .request(let x, let y, let z)):
            return a == x && b == y && c == z
        case (.response(let a, let b), .response(let x, let y)):
            return a == x && b == y
        case (.responseError(let a, let b, let c), .responseError(let x, let y, let z)):
            return a == x && b == y && c == z
        case (.notification(let a, let b), .notification(let x, let y)):
            return a == x && b == y
        default:
            return false
        }
    }
}
