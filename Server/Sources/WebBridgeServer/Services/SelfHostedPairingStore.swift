import Crypto
import Foundation

/// One-time pairing tickets protect the registration endpoint from accidental
/// or unauthorised enrollment. A ticket never contains a device token or key.
actor SelfHostedPairingStore {
    private var tickets: [String: Date] = [:]
    private let ttl: TimeInterval
    private let maxTickets: Int
    private let fileURL: URL?

    init(fileURL: URL? = nil, ttl: TimeInterval = 10 * 60, maxTickets: Int = 256) {
        self.fileURL = fileURL
        self.ttl = ttl
        self.maxTickets = max(1, maxTickets)
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let persisted = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return }
        let now = Date()
        self.tickets = Dictionary(
            uniqueKeysWithValues: persisted.filter { $0.value > now }.prefix(self.maxTickets)
                .map { ($0.key, $0.value) }
        )
    }

    func issue(now: Date = Date()) -> SelfHostedPairingTicket? {
        removeExpired(now: now)
        guard tickets.count < maxTickets else { return nil }
        let ticket = SelfHostedPairingTicket(
            token: Self.randomToken(),
            expiresAt: now.addingTimeInterval(ttl)
        )
        tickets[tokenDigest(ticket.token)] = ticket.expiresAt
        persist()
        return ticket
    }

    /// Atomically verifies and consumes a ticket. Replays return false.
    func consume(_ token: String, now: Date = Date()) -> Bool {
        removeExpired(now: now)
        guard let expiry = tickets.removeValue(forKey: tokenDigest(token)), expiry > now else {
            return false
        }
        persist()
        return true
    }

    private func removeExpired(now: Date) {
        let expired = tickets.filter { $0.value <= now }.map(\.key)
        guard !expired.isEmpty else { return }
        for token in expired { tickets.removeValue(forKey: token) }
        persist()
    }

    private func persist() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(tickets)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Pairing is convenience state. A write failure must not log the
            // ticket itself or any registration material.
        }
    }

    private static func randomToken() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<24).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// The persistence file must not be enough to redeem a still-valid QR
    /// ticket. Store a SHA-256 digest, while the original random token exists
    /// only in the deployment response and the scanning device.
    private func tokenDigest(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
