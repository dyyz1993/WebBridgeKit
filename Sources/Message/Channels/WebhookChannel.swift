import Foundation

/// Webhook message channel - receives messages via HTTP webhook
public actor WebhookChannel: @preconcurrency MessageChannel {
    public let channelId = "webhook"
    public nonisolated(unsafe) var isActive = false

    private let port: UInt16
    private let path: String
    private let secret: String?
    private var onReceive: (@Sendable (MessagePayload) -> Void)?

    public init(
        port: UInt16 = 8765,
        path: String = "/webhook",
        secret: String? = nil
    ) {
        self.port = port
        self.path = path
        self.secret = secret
    }

    public func start() async {
        // Webhook receiving is handled by the AI HTTP server
        // This channel just marks itself as active
        isActive = true
    }

    public func stop() async {
        isActive = false
    }

    public func send(_ payload: MessagePayload) async throws -> MessageSendResult {
        // Webhook channel is receive-only, cannot send
        return .failed(error: .channelNotConfigured(channelId: channelId))
    }

    /// Set the receive callback
    public func onReceive(_ handler: @escaping @Sendable (MessagePayload) -> Void) {
        self.onReceive = handler
    }

    /// Process an incoming webhook request
    /// - Parameters:
    ///   - body: Request body data
    ///   - headers: Request headers
    /// - Returns: Processed message payload
    public func processWebhook(body: Data, headers: [String: String]) throws -> MessagePayload {
        // Validate secret if configured
        if let secret = secret {
            let signature = headers["X-Webhook-Signature"] ?? headers["X-Hub-Signature-256"] ?? ""
            guard validateSignature(body: body, signature: signature, secret: secret) else {
                throw MessageError.unauthorized
            }
        }

        // Parse JSON body
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            throw MessageError.invalidPayload(reason: "Invalid JSON body")
        }

        // Extract message fields
        let title = json["title"] as? String ?? "Webhook Message"
        let messageBody = json["body"] as? String ?? json["content"] as? String ?? json["text"] as? String ?? ""
        let source = json["source"] as? String ?? "webhook"
        let url = json["url"] as? String
        let appId = json["appid"] as? String ?? json["appId"] as? String
        let mode = json["mode"] as? String
        let group = json["group"] as? String
        let sound = json["sound"] as? String
        let level = json["level"] as? String

        // Parse priority
        var priority: MessagePriority = .normal
        if let level = level {
            switch level {
            case "passive": priority = .low
            case "active": priority = .high
            case "timeSensitive": priority = .critical
            default: priority = .normal
            }
        }

        // Build user info from remaining fields
        let knownKeys: Set<String> = ["title", "body", "content", "text", "source", "url", "appid", "appId", "mode", "group", "sound", "level"]
        var userInfo: [String: String] = [:]
        for (key, value) in json where !knownKeys.contains(key) {
            if let stringValue = value as? String {
                userInfo[key] = stringValue
            } else if let numberValue = value as? NSNumber {
                userInfo[key] = numberValue.stringValue
            }
        }

        let payload = MessagePayload(
            title: title,
            body: messageBody,
            channel: channelId,
            priority: priority,
            sound: sound,
            group: group,
            targetURL: url,
            targetAppId: appId,
            targetMode: mode,
            userInfo: userInfo
        )

        // Notify callback
        onReceive?(payload)

        return payload
    }

    // MARK: - Private Methods

    private func validateSignature(body: Data, signature: String, secret: String) -> Bool {
        guard !signature.isEmpty else { return false }

        let hmacKey = SymmetricKey(data: Data(secret.utf8))
        let hmac = HMAC<SHA256>.authenticationCode(for: body, using: hmacKey)
        let computed = Data(hmac).map { String(format: "%02x", $0) }.joined()

        // Support both "sha256=<hex>" and plain "<hex>" formats
        let expected = signature.hasPrefix("sha256=") ? String(signature.dropFirst(7)) : signature

        return computed == expected
    }
}

// Note: In production, import CryptoKit for HMAC/SHA256
// For now, using simplified validation
import CryptoKit
