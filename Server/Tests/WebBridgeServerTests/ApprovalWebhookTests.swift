import Foundation
import Testing

@testable import WebBridgeServer

@Suite("Approval v1 Webhook")
struct ApprovalWebhookTests {
    @Test("Webhook URL validation rejects local and private targets")
    func rejectsUnsafeTargets() throws {
        #expect(throws: (any Error).self) {
            try ApprovalWebhookService.validateResponseURL("http://example.com/callback")
        }
        #expect(throws: (any Error).self) {
            try ApprovalWebhookService.validateResponseURL("https://localhost/callback")
        }
        #expect(throws: (any Error).self) {
            try ApprovalWebhookService.validateResponseURL("https://127.0.0.1/callback")
        }
        #expect(throws: (any Error).self) {
            try ApprovalWebhookService.validateResponseURL("https://10.0.0.1/callback")
        }
        let safe = try ApprovalWebhookService.validateResponseURL("https://example.com/callback")
        #expect(safe.absoluteString == "https://example.com/callback")
    }

    @Test("Webhook HMAC signature is deterministic and versioned")
    func deterministicSignature() {
        let body = Data("{\"eventId\":\"evt-1\"}".utf8)
        let first = ApprovalWebhookService.signature(timestamp: "1786433400", body: body, secret: "key-1")
        let second = ApprovalWebhookService.signature(timestamp: "1786433400", body: body, secret: "key-1")
        let changed = ApprovalWebhookService.signature(timestamp: "1786433401", body: body, secret: "key-1")
        #expect(first == second)
        #expect(first.hasPrefix("v1="))
        #expect(first != changed)
    }

    @Test("Webhook payload contains no device key or callback URL")
    func payloadExcludesSecrets() throws {
        let record = ApprovalRecord(
            requestID: "approval-42",
            messageID: "approval-42",
            deviceKey: "secret-key",
            title: "Release?",
            body: "Version 2.4.0",
            state: .approved,
            revision: 2,
            expiresAt: nil,
            clientPayload: nil,
            configuration: ApprovalConfiguration(
                actions: [],
                responseMode: "webhook",
                responseURL: "https://example.com/callback"
            ),
            actionID: "approve",
            values: [:],
            respondedAt: "2026-08-11T15:30:00Z",
            createdAt: "2026-08-11T15:00:00Z",
            updatedAt: "2026-08-11T15:30:00Z",
            delivery: ApprovalDelivery(state: .pending, attempts: 0, lastAttemptAt: nil, lastError: nil)
        )
        let event = ApprovalWebhookEvent(record: record, eventID: "evt-1")
        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any]
        )
        #expect(object["deviceKey"] == nil)
        #expect(object["responseURL"] == nil)
        #expect(object["requestId"] as? String == "approval-42")
    }
}
