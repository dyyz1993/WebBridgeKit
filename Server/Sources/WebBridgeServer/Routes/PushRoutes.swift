import Foundation
import Hummingbird
import NIOCore

enum PushRoutes {
    static func register(on router: Router<some RequestContext>, services: ServiceRegistry) {
        router.post("/:key/:title/:body") { request, context in
            try await Self.handleBarkPush(request: request, context: context, services: services)
        }
        router.get("/:key/:title/:body") { request, context in
            try await Self.handleBarkPush(request: request, context: context, services: services)
        }
        router.post("/push") { request, context in
            try await Self.handleJSONPush(request: request, context: context, services: services)
        }
        router.post("/register") { request, context in
            try await Self.handleRegister(request: request, context: context, services: services)
        }

        // Test endpoint for local verification
        // Usage: curl -X POST http://localhost:8080/api/v1/push/test \
        //   -H "Content-Type: application/json" \
        //   -d '{"device_key":"test-key","title":"Test","body":"Test notification"}'
        router.post("/test") { request, context in
            try await Self.handleTestPush(request: request, context: context, services: services)
        }
    }

    private static func handleBarkPush(
        request: Request,
        context: some RequestContext,
        services: ServiceRegistry
    ) async throws -> PushResponse {
        guard let key = context.parameters.get("key"),
              let title = context.parameters.get("title")?.removingPercentEncoding,
              let body = context.parameters.get("body")?.removingPercentEncoding else {
            throw HTTPError(.badRequest, message: "Missing key, title, or body")
        }

        let payload = PushPayload(
            title: title,
            body: body,
            subtitle: extractQueryParam(from: request.uri.query, name: "subtitle"),
            category: extractQueryParam(from: request.uri.query, name: "category"),
            markdown: markdownContent(from: request.uri.query, body: body),
            sound: extractQueryParam(from: request.uri.query, name: "sound"),
            badge: intQueryParam(from: request.uri.query, name: "badge"),
            icon: extractQueryParam(from: request.uri.query, name: "icon"),
            image: extractQueryParam(from: request.uri.query, name: "image"),
            group: extractQueryParam(from: request.uri.query, name: "group"),
            threadID: extractQueryParam(from: request.uri.query, name: "threadId"),
            url: extractQueryParam(from: request.uri.query, name: "url"),
            copy: extractQueryParam(from: request.uri.query, name: "copy"),
            isArchive: boolQueryParam(from: request.uri.query, name: "isArchive"),
            level: extractQueryParam(from: request.uri.query, name: "level"),
            volume: doubleQueryParam(from: request.uri.query, name: "volume"),
            isCall: boolQueryParam(from: request.uri.query, name: "call"),
            autoCopy: boolQueryParam(from: request.uri.query, name: "autoCopy")
                ?? boolQueryParam(from: request.uri.query, name: "automaticallyCopy"),
            appID: extractQueryParam(from: request.uri.query, name: "appId")
                ?? extractQueryParam(from: request.uri.query, name: "appid"),
            route: extractQueryParam(from: request.uri.query, name: "route"),
            mode: extractQueryParam(from: request.uri.query, name: "mode"),
            display: extractQueryParam(from: request.uri.query, name: "display"),
            verificationCode: extractQueryParam(from: request.uri.query, name: "verificationCode"),
            expiresAt: extractQueryParam(from: request.uri.query, name: "expiresAt"),
            ttl: doubleQueryParam(from: request.uri.query, name: "ttl"),
            replacementID: extractQueryParam(from: request.uri.query, name: "id"),
            isDeleted: boolQueryParam(from: request.uri.query, name: "delete"),
            actionState: extractQueryParam(from: request.uri.query, name: "actionState"),
            requestID: extractQueryParam(from: request.uri.query, name: "requestId"),
            contentType: extractQueryParam(from: request.uri.query, name: "contentType"),
            qrPayload: extractQueryParam(from: request.uri.query, name: "qrPayload"),
            statePath: extractQueryParam(from: request.uri.query, name: "statePath"),
            revision: intQueryParam(from: request.uri.query, name: "revision")
        )

        return try await services.apnsService.sendPush(key: key, payload: payload)
    }

    private static func handleJSONPush(
        request: Request,
        context: some RequestContext,
        services: ServiceRegistry
    ) async throws -> PushResponse {
        let pushRequest = try await request.decode(as: JSONPushRequest.self, context: context)

        guard !pushRequest.deviceKey.isEmpty else {
            throw HTTPError(.badRequest, message: "deviceKey or device_key is required")
        }
        try pushRequest.validateMessageContract()

        if let approval = pushRequest.nativeApproval {
            _ = try await services.approvalStore.upsert(
                deviceKey: pushRequest.deviceKey,
                messageID: approval.messageID,
                requestID: approval.requestID,
                title: pushRequest.title,
                body: pushRequest.body,
                state: approval.state,
                revision: approval.revision,
                expiresAt: pushRequest.expiresAt,
                clientPayload: pushRequest.payload,
                configuration: approval.configuration
            )
        }

        return try await services.apnsService.sendPush(key: pushRequest.deviceKey, payload: pushRequest.payload)
    }

    private static func handleRegister(
        request: Request,
        context: some RequestContext,
        services: ServiceRegistry
    ) async throws -> RegistrationResponse {
        let registration = try await request.decode(as: DeviceRegistration.self, context: context)
        do {
            try await services.apnsService.registerDevice(registration)
        } catch {
            throw HTTPError(.internalServerError, message: "Device registration could not be persisted")
        }
        return RegistrationResponse(code: 200, message: "Device registered", deviceToken: registration.deviceToken)
    }

    private static func extractQueryParam(from query: String?, name: String) -> String? {
        guard let query else { return nil }
        return query.split(separator: "&")
            .compactMap { param -> String? in
                let parts = param.split(separator: "=", maxSplits: 1)
                guard parts.count == 2, parts[0] == name else { return nil }
                return String(parts[1]).removingPercentEncoding
            }
            .first
    }

    private static func boolQueryParam(from query: String?, name: String) -> Bool? {
        guard let value = extractQueryParam(from: query, name: name)?.lowercased() else { return nil }
        if value == "1" || value == "true" { return true }
        if value == "0" || value == "false" { return false }
        return nil
    }

    private static func intQueryParam(from query: String?, name: String) -> Int? {
        extractQueryParam(from: query, name: name).flatMap(Int.init)
    }

    private static func doubleQueryParam(from query: String?, name: String) -> Double? {
        extractQueryParam(from: query, name: name).flatMap(Double.init)
    }

    private static func markdownContent(from query: String?, body: String) -> String? {
        guard let markdown = extractQueryParam(from: query, name: "markdown"), !markdown.isEmpty else { return nil }
        return markdown == "1" || markdown.lowercased() == "true" ? body : markdown
    }

    /// Test endpoint for local push verification
    /// - Parameters:
    ///   - request: HTTP request
    ///   - context: Request context
    ///   - services: Service registry
    /// - Returns: Test push response
    /// - Discussion: This endpoint logs the received payload for verification purposes
    private static func handleTestPush(
        request: Request,
        context: some RequestContext,
        services: ServiceRegistry
    ) async throws -> TestPushResponse {
        let testRequest = try await request.decode(as: JSONPushRequest.self, context: context)

        NSLog("🧪 [PushRoutes] TEST ENDPOINT - Received push payload:")
        NSLog("   - Device Key: %@", testRequest.deviceKey)
        NSLog("   - Title: %@", testRequest.title)
        NSLog("   - Body: %@", testRequest.body)
        NSLog("   - Sound: %@", testRequest.sound ?? "default")
        NSLog("   - Group: %@", testRequest.group ?? "default")
        NSLog("   - URL: %@", testRequest.url ?? "none")

        // Attempt to send push if device is registered
        do {
            _ = try await services.apnsService.sendPush(key: testRequest.deviceKey, payload: testRequest.payload)

            NSLog("✅ [PushRoutes] TEST ENDPOINT - Push sent successfully")

            return TestPushResponse(
                success: true,
                message: "Test push sent successfully",
                deviceKey: testRequest.deviceKey,
                timestamp: makeISO8601DateFormatter().string(from: Date())
            )
        } catch {
            NSLog("❌ [PushRoutes] TEST ENDPOINT - Push failed: %@", error.localizedDescription)

            // Return success for test purposes even if push fails (device might not be registered)
            return TestPushResponse(
                success: false,
                message: "Test push failed: \(error.localizedDescription)",
                deviceKey: testRequest.deviceKey,
                timestamp: makeISO8601DateFormatter().string(from: Date())
            )
        }
    }

    /// ISO8601 date formatter
    private static func makeISO8601DateFormatter() -> ISO8601DateFormatter {
        let formatter = Foundation.ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}

// MARK: - Test Response Models

private struct TestPushResponse: ResponseEncodable, Sendable {
    let success: Bool
    let message: String
    let deviceKey: String
    let timestamp: String
}

struct JSONPushRequest: Codable, Sendable {
    private let canonicalDeviceKey: String?
    private let legacyDeviceKey: String?
    var deviceKey: String { canonicalDeviceKey ?? legacyDeviceKey ?? "" }
    let schema: String?
    let type: String?
    let title: String
    let body: String
    let subtitle: String?
    let category: String?
    let markdown: String?
    let sound: String?
    let badge: Int?
    let icon: String?
    let image: String?
    let group: String?
    let threadID: String?
    let url: String?
    let copy: String?
    let isArchive: Bool?
    let level: String?
    let volume: Double?
    let isCall: Bool?
    let autoCopy: Bool?
    let appID: String?
    let legacyAppID: String?
    let route: String?
    let mode: String?
    let display: String?
    let verificationCode: String?
    let expiresAt: String?
    let ttl: TimeInterval?
    let replacementID: String?
    let isDeleted: Bool?
    let actionState: String?
    let requestID: String?
    let contentType: String?
    let qrPayload: String?
    let statePath: String?
    let revision: Int?
    let params: [String: String]?
    let presentation: String?
    let state: String?
    let approval: ApprovalConfiguration?
    let html: String?

    enum CodingKeys: String, CodingKey {
        case schema, type, title, body, subtitle, category, markdown, sound, badge, icon, image
        case group, url, copy, level, volume, route, mode, display, verificationCode, expiresAt, ttl
        case actionState, contentType, qrPayload, statePath, revision, params, presentation, state, approval, html
        case canonicalDeviceKey = "deviceKey"
        case legacyDeviceKey = "device_key"
        case threadID = "threadId"
        case isCall = "call"
        case autoCopy
        case appID = "appId"
        case legacyAppID = "appid"
        case replacementID = "id"
        case isDeleted = "delete"
        case requestID = "requestId"
        case isArchive = "isArchive"
    }

    var payload: PushPayload {
        PushPayload(
            schema: schema,
            type: type,
            title: title,
            body: body,
            subtitle: subtitle,
            category: category,
            markdown: markdown,
            sound: sound,
            badge: badge,
            icon: icon,
            image: image,
            group: group,
            threadID: threadID,
            url: url,
            copy: copy,
            isArchive: isArchive,
            level: level,
            volume: volume,
            isCall: isCall,
            autoCopy: autoCopy,
            appID: appID ?? legacyAppID,
            route: route,
            mode: mode,
            display: display,
            verificationCode: verificationCode,
            expiresAt: expiresAt,
            ttl: ttl,
            replacementID: replacementID,
            isDeleted: isDeleted,
            actionState: state ?? actionState,
            requestID: requestID,
            contentType: type ?? contentType,
            qrPayload: qrPayload,
            statePath: statePath,
            revision: revision,
            params: params,
            presentation: presentation,
            approval: approval?.clientPayload
        )
    }

    var nativeApproval: NativeApprovalCreation? {
        guard (type ?? contentType) == "approval",
              (presentation ?? "native") == "native",
              let configuration = approval,
              let requestID = requestID ?? replacementID else { return nil }
        let messageID = replacementID ?? requestID
        return NativeApprovalCreation(
            messageID: messageID,
            requestID: requestID,
            state: ApprovalState(rawValue: state ?? actionState ?? "pending") ?? .pending,
            revision: revision ?? 1,
            configuration: configuration
        )
    }

    func validateMessageContract() throws {
        guard html == nil else {
            throw HTTPError(.badRequest, message: "Raw HTML is not accepted; use presentation web with url")
        }

        guard schema == "webbridgekit.message.v1" || schema == nil else {
            throw HTTPError(.badRequest, message: "Unsupported message schema")
        }
        if schema == "webbridgekit.message.v1" {
            let supportedTypes = ["plain", "markdown", "image", "qr", "otp", "chat", "approval"]
            guard let type, supportedTypes.contains(type) else {
                throw HTTPError(.badRequest, message: "Unsupported message type")
            }

            switch type {
            case "markdown":
                guard markdown?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                    throw HTTPError(.badRequest, message: "Markdown messages require markdown content")
                }
            case "image":
                guard let image,
                      let components = URLComponents(string: image),
                      components.scheme?.lowercased() == "https",
                      components.host?.isEmpty == false else {
                    throw HTTPError(.badRequest, message: "Image messages require an HTTPS image URL")
                }
            case "qr":
                guard qrPayload?.isEmpty == false else {
                    throw HTTPError(.badRequest, message: "QR messages require qrPayload")
                }
            case "otp":
                guard verificationCode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                    throw HTTPError(.badRequest, message: "OTP messages require verificationCode")
                }
            case "chat":
                guard let appID = appID ?? legacyAppID,
                      !appID.isEmpty,
                      let route,
                      route.hasPrefix("/") else {
                    throw HTTPError(.badRequest, message: "Chat messages require appId and an absolute route")
                }
            default:
                break
            }
        }

        guard type == "approval" else { return }
        guard let replacementID, Self.isSafeIdentifier(replacementID),
              let requestID, Self.isSafeIdentifier(requestID),
              let revision, revision >= 1,
              let state, ApprovalState(rawValue: state) != nil,
              let presentation else {
            throw HTTPError(.badRequest, message: "Approval requires valid id, requestId, revision, state, and presentation")
        }

        switch presentation {
        case "native":
            guard approval != nil else {
                throw HTTPError(.badRequest, message: "Native approval requires approval actions")
            }
        case "web":
            guard approval == nil,
                  let url,
                  let components = URLComponents(string: url),
                  components.scheme?.lowercased() == "https",
                  components.host?.isEmpty == false else {
                throw HTTPError(.badRequest, message: "Web approval requires an HTTPS url and no native approval object")
            }
        case "pwa":
            guard approval == nil,
                  let appID = appID ?? legacyAppID,
                  !appID.isEmpty,
                  let route,
                  route.hasPrefix("/") else {
                throw HTTPError(.badRequest, message: "PWA approval requires appId and an absolute route")
            }
        default:
            throw HTTPError(.badRequest, message: "Approval presentation must be native, web, or pwa")
        }
    }

    private static func isSafeIdentifier(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9._:-]{1,128}$"#, options: .regularExpression) != nil
    }
}

struct NativeApprovalCreation: Sendable {
    let messageID: String
    let requestID: String
    let state: ApprovalState
    let revision: Int
    let configuration: ApprovalConfiguration
}

private struct RegistrationResponse: ResponseEncodable, Sendable {
    let code: Int
    let message: String
    let deviceToken: String
}
