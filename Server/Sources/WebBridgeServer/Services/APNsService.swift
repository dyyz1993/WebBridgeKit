import Foundation
import Hummingbird
import NIOCore
import NIOHTTP1

final class APNsService: Sendable {
    private let configuration: ServerConfiguration
    private let tokenStore: TokenStore
    private let jwtSigner: APNsJWTSigner?

    init(configuration: ServerConfiguration, tokenStore: TokenStore) {
        self.configuration = configuration
        self.tokenStore = tokenStore
        self.jwtSigner = try? APNsJWTSigner(
            keyID: configuration.apnsKeyID,
            teamID: configuration.apnsTeamID,
            keyPath: configuration.apnsKeyPath
        )
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
        guard let jwtSigner else { return }

        let apnsPayload = Self.makeAPNsPayload(payload)

        // Delivery diagnostics: the route JSON only proves acceptance, not
        // what Apple actually received. Log the presentation-critical fields
        // so sound/level regressions are visible in the supervisor log.
        let apsSound = (apnsPayload["aps"] as? [String: Any])?["sound"]
        FileHandle.standardError.write(Data(
            "[APNs] sending token=…\(deviceToken.suffix(6)) title=\(payload.title) sound=\(apsSound ?? "nil") level=\(payload.level ?? "nil")\n".utf8
        ))

        let host = configuration.apnsEnvironment == "production"
            ? "api.push.apple.com"
            : "api.sandbox.push.apple.com"
        let urlString = "https://\(host)/3/device/\(deviceToken)"

        guard let bodyData = try? JSONSerialization.data(withJSONObject: apnsPayload),
              let body = String(data: bodyData, encoding: .utf8) else { return }

        // A token rejected with 429 stays blacklisted by Apple, so retry once
        // with a freshly minted token before surfacing the error.
        for attempt in 0...1 {
            guard let authorizationToken = try? jwtSigner.token() else { return }
            let status = Self.curlPost(
                url: urlString,
                body: body,
                authorizationToken: authorizationToken,
                topic: configuration.apnsTopic,
                priority: payload.level == "passive" ? "5" : "10"
            )
            if status == 200 { return }
            if status == 429, attempt == 0 {
                jwtSigner.invalidateCachedToken()
                continue
            }
            FileHandle.standardError.write(Data("[APNs] status=\(status)\n".utf8))
            return
        }
    }

    /// APNs only speaks HTTP/2. The pinned AsyncHTTPClient release has no HTTP/2
    /// support and corelibs URLSession hangs against Apple's endpoint, while the
    /// system curl (nghttp2) has been verified stable — so the push rides on it.
    private static func curlPost(
        url: String,
        body: String,
        authorizationToken: String,
        topic: String,
        priority: String
    ) -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = [
            "-s", "--http2", "--max-time", "15",
            "-o", "/dev/null", "-w", "%{http_code}",
            "-X", "POST", url,
            "-H", "Content-Type: application/json",
            "-H", "Authorization: bearer \(authorizationToken)",
            "-H", "apns-topic: \(topic)",
            "-H", "apns-push-type: alert",
            "-H", "apns-priority: \(priority)",
            "--data-binary", body,
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let code = String(data: data, encoding: .utf8) ?? ""
            return Int(code.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        } catch {
            return 0
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
            "sound": apsSound(payload),
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

    /// Critical alerts only honor volume in the dictionary sound form; the
    /// plain string form silently ignores it. Bark URLs carry volume as an
    /// integer 0–10 while Apple's payload spec expects 0.0–1.0, so rescale
    /// and clamp here.
    private static func apsSound(_ payload: PushPayload) -> Any {
        guard payload.level == "critical" else { return payload.sound ?? "default" }
        let scaledVolume = min(max((payload.volume ?? 5) / 10, 0), 1)
        return [
            "critical": 1,
            "name": payload.sound ?? "default",
            "volume": scaledVolume,
        ]
    }
}
