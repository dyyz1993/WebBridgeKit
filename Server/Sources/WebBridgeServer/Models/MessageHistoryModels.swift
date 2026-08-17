import Hummingbird

/// Response for `GET /api/v1/messages/{key}` — per-device message history.
struct MessageHistoryResponse: ResponseEncodable, Sendable {
    struct Item: Codable, Sendable {
        let title: String
        let body: String
        let timestamp: Int
    }

    let messages: [Item]
}
