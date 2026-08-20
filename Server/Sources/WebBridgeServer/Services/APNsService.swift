import Foundation
import Hummingbird
import NIOCore
import NIOHTTP1

/// Per-device message log with disk persistence. The app fetches messages
/// that arrived while it was backgrounded or killed. Bark does not have
/// server-side storage (device-local only via NSE + Realm); we add this as
/// a second recovery tier that survives app uninstall and NSE misses.
actor PushMessageLog {

    struct Entry: Sendable {
        var messageId: String?
        var title: String
        var body: String
        var timestamp: Int
        var fields: [String: String]
    }

    private var messages: [String: [Entry]] = [:]
    private let maxPerKey = 100
    private let maxAge: TimeInterval = 7 * 24 * 3600 // 7 days retention
    private let fileURL: URL?

    private struct StoredMessage: Codable {
        let k: String
        let t: String
        let b: String
        let ts: Int
        // Optional so history files written before rich-field logging
        // (messageId + custom fields) still decode.
        var m: String?
        var f: [String: String]?
    }

    init(dataDir: String) {
        self.fileURL = URL(fileURLWithPath: dataDir, isDirectory: true)
            .appendingPathComponent("message-log.json")

        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode([StoredMessage].self, from: data)
        else { return }

        let cutoff = Date().timeIntervalSince1970 - maxAge
        for item in stored where Double(item.ts) > cutoff {
            messages[item.k, default: []].append(Entry(
                messageId: item.m,
                title: item.t,
                body: item.b,
                timestamp: item.ts,
                fields: item.f ?? [:]
            ))
        }
    }

    func record(key: String, messageId: String?, title: String, body: String, fields: [String: String]) {
        var list = messages[key] ?? []
        list.append(Entry(
            messageId: messageId,
            title: title,
            body: body,
            timestamp: Int(Date().timeIntervalSince1970),
            fields: fields
        ))
        if list.count > maxPerKey {
            list.removeFirst(list.count - maxPerKey)
        }
        messages[key] = list
        try? persist()
    }

    func recent(key: String, since: Int = 0) -> [Entry] {
        (messages[key] ?? []).filter { $0.timestamp > since }
    }

    private func persist() {
        guard let fileURL else { return }
        let cutoff = Date().timeIntervalSince1970 - maxAge
        var stored: [StoredMessage] = []
        for (key, list) in messages {
            for msg in list where Double(msg.timestamp) > cutoff {
                stored.append(StoredMessage(k: key, t: msg.title, b: msg.body, ts: msg.timestamp, m: msg.messageId, f: msg.fields))
            }
        }
        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: fileURL)
        }
    }
}

final class APNsService: Sendable {
    let configuration: ServerConfiguration
    private let tokenStore: TokenStore
    private let jwtSigner: APNsJWTSigner?
    public let messageLog: PushMessageLog

    init(configuration: ServerConfiguration, tokenStore: TokenStore) {
        self.configuration = configuration
        self.tokenStore = tokenStore
        self.messageLog = PushMessageLog(dataDir: configuration.dataDir)
        self.jwtSigner = try? APNsJWTSigner(
            keyID: configuration.apnsKeyID,
            teamID: configuration.apnsTeamID,
            keyPath: configuration.apnsKeyPath
        )
    }

    func sendPush(key: String, payload: PushPayload) async throws -> PushResponse {
        // One id per push, shared by the APNs payload, the NSE plist the
        // device writes, and the server history — all three recovery paths
        // then dedupe against each other by id.
        var payload = payload
        payload.ensureMessageID()
        if configuration.messageHistoryEnabled {
            await messageLog.record(
                key: key,
                messageId: payload.messageID,
                title: payload.title,
                body: payload.body,
                fields: payload.customFields
            )
        }

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

        // A device token belongs to exactly one APNs environment (production for
        // TestFlight/App Store builds, sandbox for development-signed builds).
        // Single-user fleets flip between both, so a 400 on the configured host
        // means "wrong environment", not "dead token": retry the other host
        // once instead of silently dropping the push.
        let productionHost = "api.push.apple.com"
        let sandboxHost = "api.sandbox.push.apple.com"
        let hosts = configuration.apnsEnvironment == "production"
            ? [productionHost, sandboxHost]
            : [sandboxHost, productionHost]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: apnsPayload),
              let body = String(data: bodyData, encoding: .utf8) else { return }

        for (index, host) in hosts.enumerated() {
            let urlString = "https://\(host)/3/device/\(deviceToken)"

            for _ in 0...1 {
                guard let authorizationToken = try? jwtSigner.token() else { return }
                let status = Self.curlPost(
                    url: urlString,
                    body: body,
                    authorizationToken: authorizationToken,
                    topic: configuration.apnsTopic,
                    priority: payload.level == "passive" ? "5" : "10"
                )
                if status == 200 { return }
                // 429 TooManyProviderTokenUpdates: Apple is rate-limiting
                // provider-token MINTS. Minting a replacement would deepen the
                // penalty (~25 min lockout, learned 2026-08-20). Back off now
                // and keep the cached token for after the lockout clears.
                if status == 429 {
                    FileHandle.standardError.write(Data(
                        "[APNs] 429 provider-token penalty — backing off, cached token kept\n".utf8
                    ))
                    return
                }
                // 400 BadDeviceToken on the preferred host: the token lives in
                // the other environment — fall through to it.
                if status == 400, index == 0, hosts.count > 1 {
                    FileHandle.standardError.write(Data(
                        "[APNs] status=400 on \(host), trying \(hosts[1])\n".utf8
                    ))
                    break
                }
                FileHandle.standardError.write(Data("[APNs] status=\(status)\n".utf8))
                return
            }
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
        // Ciphertext-only pushes carry no plaintext alert; iOS hides
        // notifications whose alert is empty. Ship a placeholder the NSE
        // overwrites after decrypting — and that remains visible (instead
        // of an invisible fallback) if the NSE never runs.
        let hasPlaintextAlert = !payload.title.isEmpty || !payload.body.isEmpty
        let isCiphertextOnly = payload.ciphertext?.isEmpty == false && !hasPlaintextAlert
        var alert: [String: Any] = [
            "title": isCiphertextOnly ? "加密消息" : payload.title,
            "body": isCiphertextOnly ? "🔒 已加密内容，设备将自动解密" : payload.body,
        ]
        if let subtitle = payload.subtitle { alert["subtitle"] = subtitle }

        var aps: [String: Any] = [
            "alert": alert,
            // Wakes the NotificationServiceExtension (icon attachments and
            // call=1 30-second loops are produced there, as in Bark).
            "mutable-content": 1,
        ]
        // passive 静默投递：iOS 会照播 payload 里显式存在的 sound 键，
        // 「不响铃」的承诺要求 passive 推送根本不带该键（Bark 同语义）。
        if apnsInterruptionLevel(payload.level) != "passive" {
            aps["sound"] = apsSound(payload)
        }
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

        add("messageId", payload.messageID)
        add("ciphertext", payload.ciphertext)
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
