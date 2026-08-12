import Foundation
import Hummingbird

actor ApprovalStore {
    private let fileURL: URL
    private var records: [String: ApprovalRecord]

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.records = Self.load(from: fileURL)
    }

    // The transport contract intentionally mirrors the flat approval payload.
    // swiftlint:disable:next function_parameter_count
    func upsert(
        deviceKey: String,
        messageID: String,
        requestID: String,
        title: String,
        body: String,
        state: ApprovalState,
        revision: Int,
        expiresAt: String?,
        clientPayload: PushPayload?,
        configuration: ApprovalConfiguration
    ) throws -> ApprovalRecord {
        guard Self.isSafeIdentifier(messageID), Self.isSafeIdentifier(requestID) else {
            throw HTTPError(.badRequest, message: "Approval id and requestId contain unsupported characters")
        }
        guard revision >= 1 else {
            throw HTTPError(.badRequest, message: "Approval revision must be at least 1")
        }
        try validate(configuration: configuration)
        let now = Self.timestamp()
        if var existing = records[requestID] {
            guard existing.deviceKey == deviceKey else {
                throw HTTPError(.conflict, message: "Approval requestId belongs to another device key")
            }
            guard revision >= existing.revision else {
                throw HTTPError(.conflict, message: "Approval revision is older than the stored revision")
            }
            if revision == existing.revision { return existing }
            existing.state = state
            existing.revision = revision
            existing.updatedAt = now
            records[requestID] = existing
            try persist()
            return existing
        }

        let record = ApprovalRecord(
            requestID: requestID,
            messageID: messageID,
            deviceKey: deviceKey,
            title: title,
            body: body,
            state: state,
            revision: revision,
            expiresAt: expiresAt,
            clientPayload: clientPayload,
            configuration: configuration,
            actionID: nil,
            values: [:],
            respondedAt: nil,
            createdAt: now,
            updatedAt: now,
            delivery: configuration.responseMode == "webhook"
                ? ApprovalDelivery(state: .pending, attempts: 0, lastAttemptAt: nil, lastError: nil)
                : .notRequested
        )
        records[requestID] = record
        try persist()
        return record
    }

    func status(requestID: String, deviceKey: String) throws -> ApprovalStatusResponse {
        let record = try authorizedRecord(requestID: requestID, deviceKey: deviceKey)
        return ApprovalStatusResponse(record: effectiveRecord(record))
    }

    func respond(
        requestID: String,
        deviceKey: String,
        submission: ApprovalResponseSubmission
    ) throws -> ApprovalRecord {
        var record = try authorizedRecord(requestID: requestID, deviceKey: deviceKey)
        record = effectiveRecord(record)
        guard record.state == .pending else {
            records[requestID] = record
            try persist()
            throw HTTPError(.conflict, message: "Approval has already been resolved")
        }
        guard submission.expectedRevision == record.revision else {
            throw HTTPError(.conflict, message: "Approval revision conflict")
        }
        guard let action = record.configuration.actions.first(where: { $0.id == submission.actionID }) else {
            throw HTTPError(.badRequest, message: "Unknown approval action")
        }
        let values = submission.values ?? [:]
        if action.requiresReason == true,
           values["reason"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            throw HTTPError(.badRequest, message: "This action requires a reason")
        }
        guard let resultState = action.resolvedState else {
            throw HTTPError(.badRequest, message: "Approval action is missing resultState")
        }

        let now = Self.timestamp()
        record.state = resultState
        record.revision += 1
        record.actionID = action.id
        record.values = values
        record.respondedAt = now
        record.updatedAt = now
        records[requestID] = record
        try persist()
        return record
    }

    func record(requestID: String) -> ApprovalRecord? {
        records[requestID]
    }

    func updateDelivery(requestID: String, delivery: ApprovalDelivery) throws {
        guard var record = records[requestID] else { return }
        record.delivery = delivery
        record.updatedAt = Self.timestamp()
        records[requestID] = record
        try persist()
    }

    private func authorizedRecord(requestID: String, deviceKey: String) throws -> ApprovalRecord {
        guard let record = records[requestID] else {
            throw HTTPError(.notFound, message: "Approval not found")
        }
        guard record.deviceKey == deviceKey else {
            throw HTTPError(.unauthorized, message: "Invalid device key")
        }
        return record
    }

    private func effectiveRecord(_ source: ApprovalRecord) -> ApprovalRecord {
        guard source.state == .pending,
              let expiresAt = source.expiresAt,
              let date = ISO8601DateFormatter().date(from: expiresAt),
              date <= Date() else { return source }
        var record = source
        record.state = .expired
        record.revision += 1
        record.updatedAt = Self.timestamp()
        records[source.requestID] = record
        try? persist()
        return record
    }

    private func validate(configuration: ApprovalConfiguration) throws {
        guard !configuration.actions.isEmpty, configuration.actions.count <= 5 else {
            throw HTTPError(.badRequest, message: "Approval requires 1 to 5 actions")
        }
        guard Set(configuration.actions.map(\.id)).count == configuration.actions.count else {
            throw HTTPError(.badRequest, message: "Approval action ids must be unique")
        }
        guard configuration.actions.allSatisfy({ action in
            Self.isSafeActionID(action.id)
                && !action.title.isEmpty
                && action.title.count <= 40
                && action.resolvedState != nil
                && (action.style == nil || ["primary", "default", "destructive"].contains(action.style ?? ""))
        }) else {
            throw HTTPError(.badRequest, message: "Approval actions require a safe id, title, style, and result state")
        }
        guard ["poll", "webhook"].contains(configuration.responseMode) else {
            throw HTTPError(.badRequest, message: "responseMode must be poll or webhook")
        }
        if configuration.responseMode == "webhook" {
            guard let value = configuration.responseURL else {
                throw HTTPError(.badRequest, message: "Webhook mode requires an HTTPS responseURL")
            }
            _ = try ApprovalWebhookService.validateResponseURL(value)
        }
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func load(from fileURL: URL) -> [String: ApprovalRecord] {
        guard let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder().decode([String: ApprovalRecord].self, from: data) else {
            return [:]
        }
        return records
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func isSafeIdentifier(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9._:-]{1,128}$"#, options: .regularExpression) != nil
    }

    private static func isSafeActionID(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9._-]{1,64}$"#, options: .regularExpression) != nil
    }
}
