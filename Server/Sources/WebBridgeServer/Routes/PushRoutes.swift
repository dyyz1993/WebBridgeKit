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
            sound: extractQueryParam(from: request.uri.query, name: "sound"),
            group: extractQueryParam(from: request.uri.query, name: "group"),
            url: extractQueryParam(from: request.uri.query, name: "url")
        )

        return try await services.apnsService.sendPush(key: key, payload: payload)
    }

    private static func handleJSONPush(
        request: Request,
        context: some RequestContext,
        services: ServiceRegistry
    ) async throws -> PushResponse {
        let pushRequest = try await request.decode(as: JSONPushRequest.self, context: context)

        let payload = PushPayload(
            title: pushRequest.title,
            body: pushRequest.body,
            sound: pushRequest.sound,
            badge: pushRequest.badge,
            icon: pushRequest.icon,
            group: pushRequest.group,
            url: pushRequest.url,
            copy: pushRequest.copy,
            isArchive: pushRequest.isArchive
        )

        return try await services.apnsService.sendPush(key: pushRequest.deviceKey, payload: payload)
    }

    private static func handleRegister(
        request: Request,
        context: some RequestContext,
        services: ServiceRegistry
    ) async throws -> RegistrationResponse {
        let registration = try await request.decode(as: DeviceRegistration.self, context: context)
        await services.apnsService.registerDevice(registration)
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
        NSLog("   - Device Key: \(testRequest.deviceKey)")
        NSLog("   - Title: \(testRequest.title)")
        NSLog("   - Body: \(testRequest.body)")
        NSLog("   - Sound: \(testRequest.sound ?? "default")")
        NSLog("   - Group: \(testRequest.group ?? "default")")
        NSLog("   - URL: \(testRequest.url ?? "none")")

        // Attempt to send push if device is registered
        do {
            let payload = PushPayload(
                title: testRequest.title,
                body: testRequest.body,
                sound: testRequest.sound,
                badge: testRequest.badge,
                icon: testRequest.icon,
                group: testRequest.group,
                url: testRequest.url,
                copy: testRequest.copy,
                isArchive: testRequest.isArchive
            )

            _ = try await services.apnsService.sendPush(key: testRequest.deviceKey, payload: payload)

            NSLog("✅ [PushRoutes] TEST ENDPOINT - Push sent successfully")

            return TestPushResponse(
                success: true,
                message: "Test push sent successfully",
                deviceKey: testRequest.deviceKey,
                timestamp: makeISO8601DateFormatter().string(from: Date())
            )
        } catch {
            NSLog("❌ [PushRoutes] TEST ENDPOINT - Push failed: \(error.localizedDescription)")

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

private struct JSONPushRequest: Codable, Sendable {
    let deviceKey: String
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
        case deviceKey = "device_key"
        case isArchive = "isArchive"
    }
}

private struct RegistrationResponse: ResponseEncodable, Sendable {
    let code: Int
    let message: String
    let deviceToken: String
}
