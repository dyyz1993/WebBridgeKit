import Crypto
import Foundation
import Hummingbird

actor CommandService {
    private var tokens: [String: CommandToken] = [:]
    private let hmacKey: SymmetricKey

    init() {
        self.hmacKey = SymmetricKey(size: .bits256)
    }

    func generate(request: CommandGenerateRequest) throws -> CommandGenerateResponse {
        let id = UUID().uuidString
        let format = request.format ?? resolveFormat(for: request.type)
        let payload = CommandToken.CommandPayload(
            type: request.type,
            data: request.data,
            format: format
        )

        let formatter = ISO8601DateFormatter()
        let now = Date()
        let expiresAt = request.ttlSeconds.map { ttl in
            formatter.string(from: now.addingTimeInterval(TimeInterval(ttl)))
        }

        let signature = generateSignature(id: id, payload: payload)

        let token = CommandToken(
            id: id,
            payload: payload,
            signature: signature,
            createdAt: formatter.string(from: now),
            expiresAt: expiresAt,
            shareCount: 0,
            lastSharedAt: nil
        )

        tokens[id] = token

        let encodedPayload = try JSONEncoder().encode(payload)
        let tokenString = "\(id).\(encodedPayload.base64EncodedString())"

        return CommandGenerateResponse(
            id: id,
            token: tokenString,
            url: "webbridgekit://command/\(tokenString)",
            signature: signature
        )
    }

    func resolve(id: String) throws -> CommandResolveResponse {
        guard let token = tokens[id] else {
            throw HTTPError(.notFound, message: "Command token not found: \(id)")
        }

        if let expiresAt = token.expiresAt {
            let formatter = ISO8601DateFormatter()
            if let expiry = formatter.date(from: expiresAt), expiry < Date() {
                tokens.removeValue(forKey: id)
                throw HTTPError(.gone, message: "Command token has expired")
            }
        }

        let output = formatOutput(payload: token.payload)

        return CommandResolveResponse(
            id: token.id,
            payload: token.payload,
            format: token.payload.format,
            output: output
        )
    }

    func share(id: String) throws -> CommandShareResponse {
        guard var token = tokens[id] else {
            throw HTTPError(.notFound, message: "Command token not found: \(id)")
        }

        if let expiresAt = token.expiresAt {
            let formatter = ISO8601DateFormatter()
            if let expiry = formatter.date(from: expiresAt), expiry < Date() {
                tokens.removeValue(forKey: id)
                throw HTTPError(.gone, message: "Command token has expired")
            }
        }

        let formatter = ISO8601DateFormatter()
        token.shareCount += 1
        token.lastSharedAt = formatter.string(from: Date())
        tokens[id] = token

        let encodedPayload = try JSONEncoder().encode(token.payload)
        let tokenString = "\(id).\(encodedPayload.base64EncodedString())"
        let shareURL = "webbridgekit://command/\(tokenString)"
        let expiresText = token.expiresAt ?? "永不过期"
        let shareText = "【WebBridgeKit】共享口令: \(id)\n\(shareURL)\n有效期至: \(expiresText)"

        return CommandShareResponse(
            id: id,
            shareCount: token.shareCount,
            shareURL: shareURL,
            shareText: shareText
        )
    }

    func tokenCount() -> Int {
        tokens.count
    }

    private func generateSignature(id: String, payload: CommandToken.CommandPayload) -> String {
        let data = id.data(using: .utf8)! + (try! JSONEncoder().encode(payload))
        return HMAC<SHA256>.authenticationCode(for: data, using: hmacKey).compactMap {
            String(format: "%02x", $0)
        }.joined()
    }

    private func resolveFormat(for type: CommandToken.CommandPayload.CommandType) -> CommandToken.CommandPayload.CommandFormat {
        switch type {
        case .urlScheme: return .urlScheme
        case .base64: return .base64
        case .plainText: return .plainText
        case .json: return .plainText
        }
    }

    private func formatOutput(payload: CommandToken.CommandPayload) -> String {
        switch payload.format {
        case .urlScheme:
            return "webbridgekit://execute?type=\(payload.type.rawValue)&data=\(payload.data.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? payload.data)"
        case .base64:
            return Data(payload.data.utf8).base64EncodedString()
        case .plainText:
            return payload.data
        }
    }
}
