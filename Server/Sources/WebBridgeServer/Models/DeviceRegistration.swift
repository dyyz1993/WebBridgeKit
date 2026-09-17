import Foundation
import Hummingbird

struct DeviceRegistration: Codable, Sendable {
    let deviceToken: String
    let key: String
    let platform: String?
    let appVersion: String?
    /// X25519 public key, base64url encoded. Absent registrations remain
    /// compatible with the existing official/Bark push route.
    let encryptionPublicKey: String?
    /// Trusted registration-owned source label used only by Drel's local
    /// inbox filter. It is not a delivery permission.
    let drelSourceChannel: String?
    let createdAt: String

    nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    init(
        deviceToken: String,
        key: String,
        platform: String? = nil,
        appVersion: String? = nil,
        encryptionPublicKey: String? = nil,
        drelSourceChannel: String? = nil,
        createdAt: String? = nil
    ) {
        self.deviceToken = deviceToken
        self.key = key
        self.platform = platform
        self.appVersion = appVersion
        self.encryptionPublicKey = encryptionPublicKey
        self.drelSourceChannel = drelSourceChannel
        self.createdAt = createdAt ?? Self.isoFormatter.string(from: Date())
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceToken = try container.decode(String.self, forKey: .deviceToken)
        key = try container.decode(String.self, forKey: .key)
        platform = try container.decodeIfPresent(String.self, forKey: .platform)
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion)
        encryptionPublicKey = try container.decodeIfPresent(String.self, forKey: .encryptionPublicKey)
        drelSourceChannel = try container.decodeIfPresent(String.self, forKey: .drelSourceChannel)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? Self.isoFormatter.string(from: Date())
    }
}
