// swift-crypto's P256.Signing.PrivateKey predates strict Sendable annotations;
// it is an immutable key value, safe to share across the actor boundary here.
@preconcurrency import Crypto
import Foundation

enum APNsJWTSignerError: Error {
    case missingConfiguration
    case unreadableKey
    case invalidKey
}

/// Creates the short-lived provider token required by APNs token authentication.
/// Apple limits provider-token refreshes (HTTP 429 TooManyProviderTokenUpdates),
/// so generated tokens are cached and reused until close to their 1-hour limit.
final class APNsJWTSigner: @unchecked Sendable {
    private let keyID: String
    private let teamID: String
    private let privateKey: P256.Signing.PrivateKey

    private let cacheLock = NSLock()
    private var cachedToken: String?
    private var cachedTokenAt: Date?

    /// Provider tokens stay valid for up to 1 hour; rotate well before that.
    private static let tokenLifetime: TimeInterval = 50 * 60

    convenience init(keyID: String, teamID: String, keyPath: String) throws {
        guard !keyID.isEmpty, !teamID.isEmpty, !keyPath.isEmpty else {
            throw APNsJWTSignerError.missingConfiguration
        }

        guard let pem = try? String(contentsOfFile: keyPath, encoding: .utf8) else {
            throw APNsJWTSignerError.unreadableKey
        }

        try self.init(keyID: keyID, teamID: teamID, pemRepresentation: pem)
    }

    init(keyID: String, teamID: String, pemRepresentation: String) throws {
        guard !keyID.isEmpty, !teamID.isEmpty else {
            throw APNsJWTSignerError.missingConfiguration
        }

        guard let privateKey = try? P256.Signing.PrivateKey(pemRepresentation: pemRepresentation) else {
            throw APNsJWTSignerError.invalidKey
        }

        self.keyID = keyID
        self.teamID = teamID
        self.privateKey = privateKey
    }

    /// Drops the cached token so the next `token()` call mints a fresh one.
    /// Apple blacklists individual over-refreshed tokens with 429, so a cached
    /// token that was rejected must not be reused.
    func invalidateCachedToken() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cachedToken = nil
        cachedTokenAt = nil
    }

    func token(at date: Date = Date()) throws -> String {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let cachedToken,
           let cachedTokenAt,
           date.timeIntervalSince(cachedTokenAt) < Self.tokenLifetime {
            return cachedToken
        }

        let header = try JSONSerialization.data(
            withJSONObject: ["alg": "ES256", "kid": keyID],
            options: [.sortedKeys]
        )
        let claims = try JSONSerialization.data(
            withJSONObject: [
                "iat": Int(date.timeIntervalSince1970),
                "iss": teamID,
            ],
            options: [.sortedKeys]
        )

        let unsignedToken = "\(Self.base64URL(header)).\(Self.base64URL(claims))"
        let signature = try privateKey.signature(for: Data(unsignedToken.utf8))
        let token = "\(unsignedToken).\(Self.base64URL(signature.rawRepresentation))"
        cachedToken = token
        cachedTokenAt = date
        return token
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
}
