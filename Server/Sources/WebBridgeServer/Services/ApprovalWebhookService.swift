import AsyncHTTPClient
import Crypto
import Foundation
import Hummingbird
import NIOCore
import NIOHTTP1

struct ApprovalWebhookEvent: Codable, Sendable {
    let schema: String
    let eventID: String
    let requestID: String
    let revision: Int
    let actionID: String
    let values: [String: String]
    let respondedAt: String

    enum CodingKeys: String, CodingKey {
        case schema, revision, values, respondedAt
        case eventID = "eventId"
        case requestID = "requestId"
        case actionID = "actionId"
    }

    init(record: ApprovalRecord, eventID: String = "evt-\(UUID().uuidString.lowercased())") {
        schema = "webbridgekit.approval-response.v1"
        self.eventID = eventID
        requestID = record.requestID
        revision = record.revision
        actionID = record.actionID ?? ""
        values = record.values
        respondedAt = record.respondedAt ?? ISO8601DateFormatter().string(from: Date())
    }
}

final class ApprovalWebhookService: Sendable {
    private let store: ApprovalStore
    private let httpClient: HTTPClient
    private let maximumAttempts: Int

    init(store: ApprovalStore, httpClient: HTTPClient = .shared, maximumAttempts: Int = 3) {
        self.store = store
        self.httpClient = httpClient
        self.maximumAttempts = maximumAttempts
    }

    func deliver(record: ApprovalRecord) async {
        guard record.configuration.responseMode == "webhook",
              let responseURL = record.configuration.responseURL else { return }
        let event = ApprovalWebhookEvent(record: record)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let body = try? encoder.encode(event),
              let url = try? Self.validateResponseURL(responseURL) else {
            try? await store.updateDelivery(
                requestID: record.requestID,
                delivery: ApprovalDelivery(
                    state: .failed,
                    attempts: 0,
                    lastAttemptAt: Self.timestamp(),
                    lastError: "Invalid responseURL"
                )
            )
            return
        }

        var lastError = "Webhook delivery failed"
        for attempt in 1...maximumAttempts {
            do {
                try await send(url: url, body: body, secret: record.deviceKey, eventID: event.eventID)
                try await store.updateDelivery(
                    requestID: record.requestID,
                    delivery: ApprovalDelivery(
                        state: .delivered,
                        attempts: attempt,
                        lastAttemptAt: Self.timestamp(),
                        lastError: nil
                    )
                )
                return
            } catch {
                lastError = error.localizedDescription
                try? await store.updateDelivery(
                    requestID: record.requestID,
                    delivery: ApprovalDelivery(
                        state: attempt == maximumAttempts ? .failed : .pending,
                        attempts: attempt,
                        lastAttemptAt: Self.timestamp(),
                        lastError: lastError
                    )
                )
                if attempt < maximumAttempts {
                    try? await Task.sleep(for: .seconds(attempt))
                }
            }
        }
    }

    private func send(url: URL, body: Data, secret: String, eventID: String) async throws {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        var request = try HTTPClient.Request(url: url.absoluteString, method: .POST, body: .data(body))
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "X-WBK-Delivery-Id", value: eventID)
        request.headers.add(name: "X-WBK-Timestamp", value: timestamp)
        request.headers.add(name: "X-WBK-Signature", value: Self.signature(timestamp: timestamp, body: body, secret: secret))
        let response = try await httpClient.execute(request: request).get()
        guard (200...299).contains(response.status.code) else {
            throw HTTPError(.badGateway, message: "Webhook returned HTTP \(response.status.code)")
        }
    }

    static func signature(timestamp: String, body: Data, secret: String) -> String {
        var message = Data("\(timestamp).".utf8)
        message.append(body)
        let key = SymmetricKey(data: Data(secret.utf8))
        let code = HMAC<SHA256>.authenticationCode(for: message, using: key)
        return "v1=" + code.map { String(format: "%02x", $0) }.joined()
    }

    static func validateResponseURL(_ value: String) throws -> URL {
        guard let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.user == nil,
              url.password == nil,
              let host = url.host?.lowercased(),
              !host.isEmpty,
              !isPrivateHost(host) else {
            throw HTTPError(.badRequest, message: "responseURL must be a public HTTPS URL")
        }
        return url
    }

    private static func isPrivateHost(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") || host.hasSuffix(".internal") {
            return true
        }
        if host == "::1" || host.hasPrefix("fc") || host.hasPrefix("fd") || host.hasPrefix("fe80:") {
            return true
        }
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        let first = parts[0]
        let second = parts[1]
        return first == 0
            || first == 10
            || first == 127
            || (first == 100 && (64...127).contains(second))
            || (first == 169 && second == 254)
            || (first == 172 && (16...31).contains(second))
            || (first == 192 && second == 168)
            || first >= 224
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
