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
  private let maxAge: TimeInterval = 7 * 24 * 3600  // 7 days retention
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
      messages[item.k, default: []].append(
        Entry(
          messageId: item.m,
          title: item.t,
          body: item.b,
          timestamp: item.ts,
          fields: item.f ?? [:]
        ))
    }
  }

  func record(
    key: String, messageId: String?, title: String, body: String, fields: [String: String]
  ) {
    var list = messages[key] ?? []
    list.append(
      Entry(
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
        stored.append(
          StoredMessage(
            k: key, t: msg.title, b: msg.body, ts: msg.timestamp, m: msg.messageId, f: msg.fields))
      }
    }
    if let data = try? JSONEncoder().encode(stored) {
      try? data.write(to: fileURL)
    }
  }
}

final class APNsService: Sendable {
  static let maximumAPNsPayloadSize = 4096
  static let maximumAPNsExpiration = 30 * 24 * 3600
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

  /// Readiness is deliberately based on an initialized signer rather than
  /// just non-empty environment variables: a missing or malformed .p8 must
  /// keep a public self-hosted service from advertising a false-ready state.
  var isReady: Bool { jwtSigner != nil }

  func sendPush(key: String, payload: PushPayload) async throws -> PushResponse {
    // One id per push, shared by the APNs payload, the NSE plist the
    // device writes, and the server history — all three recovery paths
    // then dedupe against each other by id.
    var payload = payload
    payload.ensureMessageID()
    let devices = await tokenStore.getDevices(forKey: key)
    let hasSelfHostedRecipients = devices.contains { $0.encryptionPublicKey?.isEmpty == false }
    if configuration.messageHistoryEnabled, !hasSelfHostedRecipients {
      await messageLog.record(
        key: key,
        messageId: payload.messageID,
        title: payload.title,
        body: payload.body,
        fields: payload.customFields
      )
    }

    guard !devices.isEmpty || key == "test" || key == "test_resources" else {
      throw HTTPError(.notFound, message: "No devices registered for key: \(key)")
    }

    var accepted = 0
    var expired = 0
    var payloadTooLarge = false
    for device in devices {
      var deliveryPayload: PushPayload
      if let publicKey = device.encryptionPublicKey, !publicKey.isEmpty {
        deliveryPayload = try Self.selfHostedDeliveryPayload(
          source: payload,
          recipientPublicKey: publicKey
        )
      } else {
        deliveryPayload = payload
      }
      deliveryPayload.drelSourceChannel = device.drelSourceChannel
      switch await sendToAPNs(deviceToken: device.deviceToken, payload: deliveryPayload) {
      case .accepted:
        accepted += 1
      case .expired:
        expired += 1
        // APNs 410 means this token is no longer associated with the app.
        // Remove only this key/token pair so a rotated identity on the same
        // phone is never accidentally revoked.
        _ = try? await tokenStore.unregister(token: device.deviceToken, key: key)
      case .payloadTooLarge:
        payloadTooLarge = true
      case .rejected, .unavailable:
        break
      }
    }

    return PushResponse(
      code:
        accepted > 0 || (devices.isEmpty && (key == "test" || key == "test_resources"))
        ? 200 : (payloadTooLarge ? 413 : 503),
      message: Self.deliveryMessage(
        attempted: devices.count,
        accepted: accepted,
        expired: expired,
        payloadTooLarge: payloadTooLarge,
        isTestAcknowledgement: devices.isEmpty && (key == "test" || key == "test_resources")
      ),
      timestamp: Int(Date().timeIntervalSince1970),
      attempted: devices.count,
      accepted: accepted,
      expired: expired
    )
  }

  /// Sends a pre-encrypted envelope through the managed APNs signer. The
  /// public route is intentionally stricter than the Bark-compatible API: a
  /// provider unavailable to deliver must fail closed, and no outer title/body
  /// may enter this service.
  func sendManagedOpaquePush(key: String, envelope: String) async throws -> PushResponse {
    guard isReady else {
      throw HTTPError(
        .serviceUnavailable,
        message: "Managed encrypted signer is temporarily unavailable")
    }
    let payload = try Self.managedOpaqueDeliveryPayload(envelope: envelope)
    return try await sendPush(key: key, payload: payload)
  }

  /// A single source of truth for the managed-encrypted wire contract. It is
  /// pure so tests can assert that APNs never receives business plaintext.
  static func managedOpaqueDeliveryPayload(envelope: String) throws -> PushPayload {
    guard let decoded = SelfHostedEnvelopeService.validatePassthroughEnvelope(envelope) else {
      throw HTTPError(.badRequest, message: "Invalid or expired drelEnvelope")
    }
    return PushPayload(
      title: "",
      body: "",
      messageID: decoded.messageID,
      drelEnvelope: envelope
    )
  }

  /// Normalizes every encrypted self-hosted delivery to an opaque outer APNs
  /// payload. Kept internal so the wire-level privacy invariant is unit tested
  /// without needing APNs credentials.
  static func selfHostedDeliveryPayload(
    source payload: PushPayload,
    recipientPublicKey: String
  ) throws -> PushPayload {
    if let envelopeValue = payload.drelEnvelope, !envelopeValue.isEmpty {
      let opaquePayload = try managedOpaqueDeliveryPayload(envelope: envelopeValue)
      // Do not forward request wrapper fields. A sender-side envelope is true
      // end-to-end encryption: this relay and APNs only receive the opaque
      // value and a delivery id.
      return opaquePayload
    }
    if let ciphertext = payload.ciphertext, !ciphertext.isEmpty {
      // Preserve the legacy encrypted contract without leaking accidental
      // title/body wrapper values to APNs.
      return PushPayload(
        title: "",
        body: "",
        messageID: payload.messageID,
        ciphertext: ciphertext
      )
    }
    guard let publicKeyData = SelfHostedEnvelopeService.base64URLDecoded(recipientPublicKey) else {
      throw HTTPError(.badRequest, message: "Registered self-hosted encryption key is invalid")
    }
    let envelope = try SelfHostedEnvelopeService.seal(
      payload: payload,
      recipientPublicKey: publicKeyData,
      messageID: payload.messageID ?? UUID().uuidString
    )
    return PushPayload(
      title: "",
      body: "",
      messageID: payload.messageID,
      drelEnvelope: envelope.encoded()
    )
  }

  func registerDevice(_ registration: DeviceRegistration) async throws {
    try await tokenStore.register(registration)
  }

  @discardableResult
  func unregisterDevice(token: String, key: String) async throws -> Bool {
    try await tokenStore.unregister(token: token, key: key)
  }

  private enum APNsDeliveryOutcome {
    case accepted
    case expired
    case rejected
    case unavailable
    case payloadTooLarge
  }

  private static func deliveryMessage(
    attempted: Int,
    accepted: Int,
    expired: Int,
    payloadTooLarge: Bool,
    isTestAcknowledgement: Bool
  ) -> String {
    if isTestAcknowledgement { return "Test notification acknowledged" }
    if accepted > 0 {
      return "APNs accepted push for \(accepted) of \(attempted) device(s)" +
        (expired > 0 ? "; removed \(expired) expired registration(s)" : "")
    }
    if payloadTooLarge {
      return "APNs payload too large: serialized delivery exceeds \(maximumAPNsPayloadSize) bytes"
    }
    return "No active device accepted the push" +
      (expired > 0 ? "; removed \(expired) expired registration(s)" : "")
  }

  private func sendToAPNs(deviceToken: String, payload: PushPayload) async -> APNsDeliveryOutcome {
    let apnsPayload = Self.makeAPNsPayload(payload)

    // Delivery diagnostics: the route JSON only proves acceptance, not
    // what Apple actually received. Log the presentation-critical fields
    // so sound/level regressions are visible in the supervisor log.
    let apsSound = (apnsPayload["aps"] as? [String: Any])?["sound"]
    FileHandle.standardError.write(
      Data(
        "[APNs] sending token=…\(deviceToken.suffix(6)) title=\(payload.title) sound=\(apsSound ?? "nil") level=\(payload.level ?? "nil")\n"
          .utf8
      ))

    // A device token belongs to exactly one APNs environment (production for
    // TestFlight/App Store builds, sandbox for development-signed builds).
    // Single-user fleets flip between both, so a 400 on the configured host
    // means "wrong environment", not "dead token": try the other host
    // once instead of silently dropping the push. Do not retry the same
    // alert request: a transport timeout can occur *after* Apple accepted
    // it, and a second request would become a delayed duplicate alert.
    let productionHost = "api.push.apple.com"
    let sandboxHost = "api.sandbox.push.apple.com"
    let hosts =
      configuration.apnsEnvironment == "production"
      ? [productionHost, sandboxHost]
      : [sandboxHost, productionHost]

    guard let bodyData = try? JSONSerialization.data(withJSONObject: apnsPayload),
      let body = String(data: bodyData, encoding: .utf8)
    else { return .rejected }
    // APNs rejects the complete HTTP/2 request body (not the source JSON)
    // above 4 KB. Rejecting locally gives senders an actionable error before
    // a provider request can accept or partially process the notification.
    guard bodyData.count <= Self.maximumAPNsPayloadSize else {
      FileHandle.standardError.write(
        Data(
          "[APNs] payload too large: \(bodyData.count) bytes (limit \(Self.maximumAPNsPayloadSize))\n"
            .utf8))
      return .payloadTooLarge
    }

    guard let jwtSigner else { return .unavailable }

    for (index, host) in hosts.enumerated() {
      let urlString = "https://\(host)/3/device/\(deviceToken)"

      guard let authorizationToken = try? jwtSigner.token() else { return .unavailable }
      let response = Self.curlPost(
        url: urlString,
        body: body,
        authorizationToken: authorizationToken,
        topic: configuration.apnsTopic,
        priority: payload.level == "passive" ? "5" : "10",
        collapseID: Self.apnsCollapseID(payload.replacementID),
        expiration: Self.apnsExpiration(payload.ttl)
      )
      let status = response.status
      if status == 200 { return .accepted }
      // 429 TooManyProviderTokenUpdates: Apple is rate-limiting
      // provider-token MINTS. Minting a replacement would deepen the
      // penalty (~25 min lockout, learned 2026-08-20). Back off now
      // and keep the cached token for after the lockout clears.
      if status == 429 {
        FileHandle.standardError.write(
          Data(
            "[APNs] 429 provider-token penalty — backing off, cached token kept\n".utf8
          ))
        return .rejected
      }
      // 400 BadDeviceToken on the preferred host: the token lives in
      // the other environment — this is the only safe retry because the
      // rejected endpoint could not have delivered the alert.
      if status == 400, index == 0, hosts.count > 1 {
        FileHandle.standardError.write(
          Data(
            "[APNs] status=400 on \(host), trying \(hosts[1])\n".utf8
          ))
        continue
      }
      if status == 410 { return .expired }
      FileHandle.standardError.write(
        Data("[APNs] status=\(status) reason=\(response.reason); not retrying alert\n".utf8))
      return .rejected
    }
    return .rejected
  }

  /// APNs only speaks HTTP/2. The pinned AsyncHTTPClient release has no HTTP/2
  /// support and corelibs URLSession hangs against Apple's endpoint, while the
  /// system curl (nghttp2) has been verified stable — so the push rides on it.
  private struct APNsHTTPResponse {
    let status: Int
    let reason: String
  }

  private static func curlPost(
    url: String,
    body: String,
    authorizationToken: String,
    topic: String,
    priority: String,
    collapseID: String?,
    expiration: Int?
  ) -> APNsHTTPResponse {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
    let errorBodyPath = NSTemporaryDirectory() + "drel-apns-error-\(UUID().uuidString).json"
    var arguments = [
      "-s", "--http2", "--max-time", "15",
      "-X", "POST", url,
      "-H", "Content-Type: application/json",
      "-H", "Authorization: bearer \(authorizationToken)",
      "-H", "apns-topic: \(topic)",
      "-H", "apns-push-type: alert",
      "-H", "apns-priority: \(priority)",
      "--data-binary", body,
      "-o", errorBodyPath,
      "-w", "%{http_code}",
    ]
    if let collapseID {
      arguments.insert(
        contentsOf: ["-H", "apns-collapse-id: \(collapseID)"], at: arguments.count - 2)
    }
    if let expiration {
      arguments.insert(
        contentsOf: ["-H", "apns-expiration: \(expiration)"], at: arguments.count - 4)
    }
    // Keep Apple's diagnostic reason out of the successful-response body while
    // retaining it for failures. The path is unique and removed immediately.
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      process.waitUntilExit()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let code = String(data: data, encoding: .utf8) ?? ""
      let status = Int(code.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
      let reason = Self.apnsReason(at: errorBodyPath, success: status == 200)
      try? FileManager.default.removeItem(atPath: errorBodyPath)
      return APNsHTTPResponse(status: status, reason: reason)
    } catch {
      try? FileManager.default.removeItem(atPath: errorBodyPath)
      return APNsHTTPResponse(status: 0, reason: "curl-failed")
    }
  }

  private static func apnsReason(at path: String, success: Bool) -> String {
    guard !success,
      let data = FileManager.default.contents(atPath: path),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let reason = object["reason"] as? String
    else { return "unavailable" }
    return reason
  }

  private static func apnsExpiration(_ ttl: TimeInterval?) -> Int? {
    guard let ttl, ttl > 0 else { return nil }
    return Int(Date().timeIntervalSince1970 + min(ttl, TimeInterval(maximumAPNsExpiration)))
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
    let isCiphertextOnly =
      (payload.ciphertext?.isEmpty == false || payload.drelEnvelope?.isEmpty == false)
      && !hasPlaintextAlert
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
    if payload.copy?.isEmpty == false {
      aps["category"] = "DREL_COPY"
    }
    if payload.isDeleted == true {
      aps["content-available"] = 1
    }

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
    add("drelEnvelope", payload.drelEnvelope)
    add("drelSourceChannel", payload.drelSourceChannel)
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
    // Drel 1.0 does not have Apple's separately approved Critical Alerts
    // entitlement. Never claim to bypass mute/Focus: old Bark-compatible
    // `level=critical` callers get the closest supported presentation.
    case "critical": return "time-sensitive"
    default: return nil
    }
  }

  /// Drel 1.0 ships only regular and time-sensitive notifications. Critical
  /// dictionary sounds require an Apple-approved entitlement and must not be
  /// emitted until that entitlement is available in the signed App ID.
  private static func apsSound(_ payload: PushPayload) -> Any {
    payload.sound ?? "default"
  }

  static func apnsCollapseID(_ value: String?) -> String? {
    guard let value,
      !value.isEmpty,
      value.lengthOfBytes(using: .utf8) <= 64,
      value.rangeOfCharacter(from: .controlCharacters) == nil
    else {
      return nil
    }
    return value
  }
}
