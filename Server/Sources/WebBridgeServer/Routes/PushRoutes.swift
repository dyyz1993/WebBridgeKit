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
