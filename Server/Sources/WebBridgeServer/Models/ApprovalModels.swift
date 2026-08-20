import Foundation
import Hummingbird

enum ApprovalState: String, Codable, Sendable {
    case pending
    case approved
    case rejected
    case cancelled
    case expired
}

struct ApprovalAction: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let style: String?
    let requiresReason: Bool?
    let resultState: ApprovalState?

    var resolvedState: ApprovalState? {
        if let resultState { return resultState }
        switch id.lowercased() {
        case "approve", "approved", "confirm", "yes": return .approved
        case "reject", "rejected", "deny", "no": return .rejected
        case "cancel", "cancelled": return .cancelled
        default: return nil
        }
    }
}

struct ApprovalConfiguration: Codable, Equatable, Sendable {
    let actions: [ApprovalAction]
    let responseMode: String
    let responseURL: String?

    var clientPayload: ApprovalClientPayload {
        ApprovalClientPayload(actions: actions)
    }
}

struct ApprovalClientPayload: Codable, Equatable, Sendable {
    let actions: [ApprovalAction]

    var dictionary: [String: Any] {
        [
            "actions": actions.map { action in
                var value: [String: Any] = [
                    "id": action.id,
                    "title": action.title,
                ]
                if let style = action.style { value["style"] = style }
                if let requiresReason = action.requiresReason { value["requiresReason"] = requiresReason }
                if let resultState = action.resultState { value["resultState"] = resultState.rawValue }
                return value
            },
        ]
    }
}

struct ApprovalResponseSubmission: Codable, Sendable {
    let actionID: String
    let expectedRevision: Int
    let values: [String: String]?

    enum CodingKeys: String, CodingKey {
        case actionID = "actionId"
        case expectedRevision, values
    }
}

enum ApprovalDeliveryState: String, Codable, Sendable {
    case notRequested
    case pending
    case delivered
    case failed
}

struct ApprovalDelivery: Codable, Sendable {
    var state: ApprovalDeliveryState
    var attempts: Int
    var lastAttemptAt: String?
    var lastError: String?

    static let notRequested = ApprovalDelivery(
        state: .notRequested,
        attempts: 0,
        lastAttemptAt: nil,
        lastError: nil
    )
}

struct ApprovalRecord: Codable, Sendable {
    let requestID: String
    let messageID: String
    let deviceKey: String
    let title: String
    let body: String
    var state: ApprovalState
    var revision: Int
    let expiresAt: String?
    let clientPayload: PushPayload?
    let configuration: ApprovalConfiguration
    var actionID: String?
    var values: [String: String]
    var respondedAt: String?
    let createdAt: String
    var updatedAt: String
    var delivery: ApprovalDelivery
}

struct ApprovalStatusResponse: Codable, ResponseEncodable, Sendable {
    let schema: String
    let requestID: String
    let state: ApprovalState
    let revision: Int
    let actionID: String?
    let values: [String: String]
    let respondedAt: String?
    let createdAt: String
    let updatedAt: String
    let delivery: ApprovalDelivery

    enum CodingKeys: String, CodingKey {
        case schema, state, revision, values, respondedAt, createdAt, updatedAt, delivery
        case requestID = "requestId"
        case actionID = "actionId"
    }

    init(record: ApprovalRecord) {
        schema = "webbridgekit.approval-status.v1"
        requestID = record.requestID
        state = record.state
        revision = record.revision
        actionID = record.actionID
        values = record.values
        respondedAt = record.respondedAt
        createdAt = record.createdAt
        updatedAt = record.updatedAt
        delivery = record.delivery
    }
}
