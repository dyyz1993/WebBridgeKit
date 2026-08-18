import Hummingbird

/// Response for `GET /api/v1/messages/{key}` — per-device message history.
/// `messageId` + `fields` let the client rebuild full-fidelity messages
/// (image, qr, route, approval…) with the same id the live push carried,
/// so history imports dedupe against banner taps and NSE plists.
struct MessageHistoryResponse: ResponseEncodable, Sendable {
    struct Item: Codable, Sendable {
        let messageId: String?
        let title: String
        let body: String
        let timestamp: Int
        let fields: [String: String]
    }

    let messages: [Item]
}
