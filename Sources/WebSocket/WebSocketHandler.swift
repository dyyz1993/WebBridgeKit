//
//  WebSocketHandler.swift
//  WebBridgeKit
//

import Foundation

public final class WebSocketHandler: BaseWebNativeHandler {

    private var client: WebSocketClient?

    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        guard let action = body["action"] as? String else {
            reject(error: "Missing action", completion: completion)
            return
        }
        switch action {
        case "connect":
            handleConnect(body: body, completion: completion)
        case "disconnect":
            handleDisconnect(completion: completion)
        case "send":
            handleSend(body: body, completion: completion)
        default:
            reject(error: "Unknown action: \(action)", completion: completion)
        }
    }

    private func handleConnect(body: [String: Any], completion: @escaping (Any) -> Void) {
        guard let urlString = body["url"] as? String,
              let url = URL(string: urlString) else {
            reject(error: "Invalid or missing URL", completion: completion)
            return
        }
        let headers = body["headers"] as? [String: String] ?? [:]
        let config = WebSocketConfiguration(url: url, headers: headers)
        client = WebSocketClient(
            configuration: config,
            onMessage: { [weak self] message in
                self?.forwardToJS(message)
            },
            onStateChange: { [weak self] state in
                self?.notifyStateChange(state)
            }
        )
        Task {
            await client?.connect()
            resolve(["status": "connecting"], completion: completion)
        }
    }

    private func handleDisconnect(completion: @escaping (Any) -> Void) {
        Task {
            await client?.disconnect()
            client = nil
            resolve(["status": "disconnected"], completion: completion)
        }
    }

    private func handleSend(body: [String: Any], completion: @escaping (Any) -> Void) {
        guard let method = body["method"] as? String else {
            reject(error: "Missing method", completion: completion)
            return
        }
        let params = body["params"] as? [String: String] ?? [:]
        Task {
            do {
                let request = WebSocketMessage.request(
                    id: UUID().uuidString,
                    method: method,
                    params: params
                )
                try await client?.send(request)
                resolve(["sent": true, "method": method], completion: completion)
            } catch {
                reject(error: error.localizedDescription, completion: completion)
            }
        }
    }

    private func forwardToJS(_ message: WebSocketMessage) {
        guard let data = message.encode(),
              let json = String(data: data, encoding: .utf8) else { return }
        sendEventToJS(event: "wsMessage", data: json)
    }

    private func notifyStateChange(_ state: WebSocketState) {
        sendEventToJS(event: "wsStateChange", data: ["state": state.rawValue])
    }

    public static func registerMeta() -> HandlerMeta {
        HandlerMeta(
            action: "websocket",
            category: .system,
            displayName: "WebSocket",
            description: "WebSocket real-time communication channel",
            requiredPermissions: ["network"],
            parameters: [
                ParamDef(name: "action", type: .string, required: true,
                         description: "connect, disconnect, or send"),
                ParamDef(name: "url", type: .string, required: false,
                         description: "WebSocket server URL (required for connect)"),
                ParamDef(name: "method", type: .string, required: false,
                         description: "JSON-RPC method name (for send)"),
                ParamDef(name: "params", type: .object, required: false,
                         description: "JSON-RPC params"),
                ParamDef(name: "headers", type: .object, required: false,
                         description: "Custom headers for connection")
            ],
            requiresNetwork: true
        )
    }
}
