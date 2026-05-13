import Foundation
import Hummingbird

struct DeviceRegistration: Codable, Sendable {
    let deviceToken: String
    let key: String
    let platform: String?
    let appVersion: String?
    let createdAt: String

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    init(
        deviceToken: String,
        key: String,
        platform: String? = nil,
        appVersion: String? = nil,
        createdAt: String? = nil
    ) {
        self.deviceToken = deviceToken
        self.key = key
        self.platform = platform
        self.appVersion = appVersion
        self.createdAt = createdAt ?? Self.isoFormatter.string(from: Date())
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceToken = try container.decode(String.self, forKey: .deviceToken)
        key = try container.decode(String.self, forKey: .key)
        platform = try container.decodeIfPresent(String.self, forKey: .platform)
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? Self.isoFormatter.string(from: Date())
    }
}
