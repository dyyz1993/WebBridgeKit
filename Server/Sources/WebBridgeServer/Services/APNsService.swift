import Foundation
import Hummingbird
import NIOCore
import NIOHTTP1
import AsyncHTTPClient

final class APNsService: Sendable {
    private let configuration: ServerConfiguration
    private let tokenStore: TokenStore
    private let httpClient: HTTPClient

    init(configuration: ServerConfiguration, tokenStore: TokenStore, httpClient: HTTPClient = .shared) {
        self.configuration = configuration
        self.tokenStore = tokenStore
        self.httpClient = httpClient
    }

    func sendPush(key: String, payload: PushPayload) async throws -> PushResponse {
        let devices = await tokenStore.getDevices(forKey: key)

        guard !devices.isEmpty || key == "test" || key == "test_resources" else {
            throw HTTPError(.notFound, message: "No devices registered for key: \(key)")
        }

        for device in devices {
            await sendToAPNs(deviceToken: device.deviceToken, payload: payload)
        }

        return PushResponse(
            code: 200,
            message: devices.isEmpty ? "Test notification acknowledged" : "Push sent to \(devices.count) device(s)",
            timestamp: Int(Date().timeIntervalSince1970)
        )
    }

    func registerDevice(_ registration: DeviceRegistration) async throws {
        try await tokenStore.register(registration)
    }

    private func sendToAPNs(deviceToken: String, payload: PushPayload) async {
        guard !configuration.apnsKeyID.isEmpty else { return }

        let apnsPayload = Self.makeAPNsPayload(payload)

        let host = configuration.apnsEnvironment == "production"
            ? "api.push.apple.com"
            : "api.sandbox.push.apple.com"
        let urlString = "https://\(host)/3/device/\(deviceToken)"

        guard let bodyData = try? JSONSerialization.data(withJSONObject: apnsPayload) else { return }

        guard var request = try? HTTPClient.Request(
            url: urlString,
            method: .POST,
            body: .data(bodyData)
        ) else { return }
        request.headers.add(name: "Content-Type", value: "application/json")

        do {
            let response = try await httpClient.execute(request: request).get()
            if response.status.code != 200 {
                print("APNs error: \(response.status.code)")
            }
        } catch {
            print("APNs send error: \(error)")
        }
    }

    /// Builds the exact JSON dictionary sent to APNs. Keeping this deterministic and
    /// testable prevents optional Push v2 fields from being accepted by the HTTP API
    /// and then silently discarded before device delivery.
    static func makeAPNsPayload(_ payload: PushPayload) -> [String: Any] {
        var alert: [String: Any] = [
            "title": payload.title,
            "body": payload.body,
        ]
        if let subtitle = payload.subtitle { alert["subtitle"] = subtitle }

        var aps: [String: Any] = [
            "alert": alert,
            "sound": payload.sound ?? "default",
        ]
        if let badge = payload.badge { aps["badge"] = badge }
        if let threadID = payload.threadID ?? payload.group { aps["thread-id"] = threadID }
        if let level = apnsInterruptionLevel(payload.level) { aps["interruption-level"] = level }

        var result: [String: Any] = [
            "aps": aps,
            // Duplicate the user-facing summary at the top level so the host can
            // persist the same envelope regardless of foreground/tap entry point.
            "title": payload.title,
            "body": payload.body,
        ]

        func add(_ key: String, _ value: Any?) {
            if let value { result[key] = value }
        }

        add("subtitle", payload.subtitle)
        add("category", payload.category)
        add("markdown", payload.markdown)
        add("sound", payload.sound)
        add("badge", payload.badge)
        add("icon", payload.icon)
        add("image", payload.image)
        add("group", payload.group)
        add("threadId", payload.threadID)
        add("url", payload.url)
        add("copy", payload.copy)
        add("isArchive", payload.isArchive)
        add("level", payload.level)
        add("volume", payload.volume)
        add("call", payload.isCall)
        add("autoCopy", payload.autoCopy)
        add("appId", payload.appID)
        add("route", payload.route)
        add("mode", payload.mode)
        add("display", payload.display)
        add("verificationCode", payload.verificationCode)
        add("expiresAt", payload.expiresAt)
        add("ttl", payload.ttl)
        add("id", payload.replacementID)
        add("delete", payload.isDeleted)
        add("actionState", payload.actionState)
        if payload.schema == "webbridgekit.message.v1" {
            add("state", payload.actionState)
        }
        add("requestId", payload.requestID)
        add("contentType", payload.contentType)
        add("qrPayload", payload.qrPayload)
        add("statePath", payload.statePath)
        add("revision", payload.revision)
        add("params", payload.params)
        add("schema", payload.schema)
        add("type", payload.type)
        add("presentation", payload.presentation)
        add("approval", payload.approval?.dictionary)

        return result
    }

    private static func apnsInterruptionLevel(_ value: String?) -> String? {
        switch value {
        case "passive": return "passive"
        case "active": return "active"
        case "timeSensitive", "time-sensitive": return "time-sensitive"
        case "critical": return "critical"
        default: return nil
        }
    }
}
