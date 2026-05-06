import Foundation
import Hummingbird

struct PushPayload: Codable, Sendable {
    let title: String
    let body: String
    let sound: String?
    let badge: Int?
    let icon: String?
    let group: String?
    let url: String?
    let copy: String?
    let isArchive: Bool?

    enum CodingKeys: String, CodingKey {
        case title, body, sound, badge, icon, group, url, copy
        case isArchive = "isArchive"
    }

    init(
        title: String,
        body: String,
        sound: String? = nil,
        badge: Int? = nil,
        icon: String? = nil,
        group: String? = nil,
        url: String? = nil,
        copy: String? = nil,
        isArchive: Bool? = nil
    ) {
        self.title = title
        self.body = body
        self.sound = sound
        self.badge = badge
        self.icon = icon
        self.group = group
        self.url = url
        self.copy = copy
        self.isArchive = isArchive
    }
}

struct PushResponse: ResponseEncodable, Sendable {
    let code: Int
    let message: String
    let timestamp: Int
}
