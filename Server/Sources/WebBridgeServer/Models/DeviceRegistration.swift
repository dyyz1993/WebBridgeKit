import Foundation
import Hummingbird

struct DeviceRegistration: Codable, Sendable {
    let deviceToken: String
    let key: String
    let platform: String?
    let appVersion: String?
    let createdAt: String

    init(
        deviceToken: String,
        key: String,
        platform: String? = nil,
        appVersion: String? = nil
    ) {
        self.deviceToken = deviceToken
        self.key = key
        self.platform = platform
        self.appVersion = appVersion
        let formatter = ISO8601DateFormatter()
        self.createdAt = formatter.string(from: Date())
    }
}
