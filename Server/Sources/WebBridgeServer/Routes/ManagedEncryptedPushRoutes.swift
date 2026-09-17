import Foundation
import Hummingbird
import NIOCore

/// Sender-side encrypted delivery through a Drel-operated APNs signer.
///
/// The signer sees the recipient token and opaque envelope, never the message
/// title, body, URL, or attachment metadata. It is intentionally not a
/// "self-hosted direct APNs" route: only an Apple-authorized provider can sign
/// for the stock Drel App ID.
enum ManagedEncryptedPushRoutes {
  static func register(on router: Router<some RequestContext>, services: ServiceRegistry) {
    router.get("/.well-known/drel-managed-push.json") { _, _ in
      ManagedEncryptedPushDescriptor(
        name: services.configuration.managedPushName,
        publicBaseURL: services.configuration.managedPushPublicBaseURL
      )
    }

    router.get("/managed-push/health") { _, _ in
      let apnsReady = services.managedAPNsService.isReady
      return ManagedEncryptedPushHealthResponse(
        status: apnsReady ? "ok" : "unavailable",
        apnsReady: apnsReady
      )
    }

    router.post("/managed-push/pairings") { _, _ in
      guard let ticket = await services.managedPushPairingStore.issue() else {
        throw HTTPError(
          .tooManyRequests, message: "Too many outstanding pairing tickets; try again shortly")
      }
      let baseURL = services.configuration.managedPushPublicBaseURL
        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let formatter = ISO8601DateFormatter()
      return ManagedEncryptedPushPairingResponse(
        pairingToken: ticket.token,
        expiresAt: formatter.string(from: ticket.expiresAt),
        configurationURL:
          "drel://managed-encrypted-push?server=\(Self.urlQueryValue(baseURL))&token=\(ticket.token)"
      )
    }

    router.get("/managed-push/recipients/:deviceKey") { _, context in
      guard let deviceKey = context.parameters.get("deviceKey"),
        !deviceKey.isEmpty,
        let publicKey = await services.managedPushTokenStore.encryptionPublicKey(forKey: deviceKey)
      else {
        throw HTTPError(.notFound, message: "No managed encrypted recipient for this device key")
      }
      return ManagedEncryptedPushRecipientResponse(
        deviceKey: deviceKey,
        encryptionPublicKey: publicKey,
        deliveryPath: "/managed-push/deliveries/\(deviceKey)"
      )
    }

    router.post("/managed-push/register") { request, context in
      let registration = try await request.decode(
        as: SelfHostedRegistrationRequest.self, context: context)
      guard !registration.deviceToken.isEmpty,
        !registration.deviceKey.isEmpty,
        registration.validatedPublicKey() != nil
      else {
        throw HTTPError(
          .badRequest,
          message: "A device token, device key, and 32-byte encryption public key are required")
      }
      guard await services.managedPushPairingStore.consume(registration.pairingToken) else {
        throw HTTPError(.unauthorized, message: "Pairing token is invalid, expired, or already used")
      }
      do {
        try await services.managedAPNsService.registerDevice(
          DeviceRegistration(
            deviceToken: registration.deviceToken,
            key: registration.deviceKey,
            platform: registration.platform ?? "ios",
            appVersion: registration.appVersion,
            encryptionPublicKey: registration.encryptionPublicKey
          ))
      } catch {
        throw HTTPError(.internalServerError, message: "Managed encrypted registration could not persist")
      }
      return ManagedEncryptedPushRegistrationResponse(
        deviceKey: registration.deviceKey,
        recipientPath: "/managed-push/recipients/\(registration.deviceKey)",
        deliveryPath: "/managed-push/deliveries/\(registration.deviceKey)",
        message: "Managed encrypted push is ready"
      )
    }

    router.post("/managed-push/deliveries/:deviceKey") { request, context in
      guard let deviceKey = context.parameters.get("deviceKey"), !deviceKey.isEmpty else {
        throw HTTPError(.badRequest, message: "deviceKey is required")
      }
      let envelope = try await Self.strictEnvelope(from: request)
      guard await services.managedPushDeliveryLimiter.allow(deviceKey: deviceKey) else {
        throw HTTPError(.tooManyRequests, message: "Managed encrypted delivery rate limit exceeded")
      }
      return try await services.managedAPNsService.sendManagedOpaquePush(
        key: deviceKey, envelope: envelope)
    }

    router.post("/managed-push/unregister") { request, context in
      let unregistration = try await request.decode(
        as: ManagedEncryptedPushUnregistrationRequest.self, context: context)
      guard !unregistration.deviceToken.isEmpty, !unregistration.deviceKey.isEmpty else {
        throw HTTPError(.badRequest, message: "deviceToken and deviceKey are required")
      }
      do {
        let removed = try await services.managedAPNsService.unregisterDevice(
          token: unregistration.deviceToken, key: unregistration.deviceKey)
        return ManagedEncryptedPushUnregistrationResponse(code: 200, removed: removed)
      } catch {
        throw HTTPError(.internalServerError, message: "Managed encrypted registration could not be removed")
      }
    }
  }

  /// Parsing the raw JSON object before decoding is deliberate: Codable ignores
  /// unknown keys, whereas this endpoint must reject a stray plaintext wrapper
  /// rather than silently accept/log it beside the encrypted envelope.
  private static func strictEnvelope(from request: Request) async throws -> String {
    let body = try await request.body.collect(upTo: 256 * 1024)
    let data = Data(body.readableBytesView)
    guard let object = try? JSONSerialization.jsonObject(with: data),
      let fields = object as? [String: Any],
      Set(fields.keys) == Set(["drelEnvelope"]),
      let value = fields["drelEnvelope"] as? String,
      !value.isEmpty,
      SelfHostedEnvelopeService.validatePassthroughEnvelope(value) != nil
    else {
      throw HTTPError(
        .badRequest,
        message: "Managed encrypted delivery accepts exactly one valid drelEnvelope field")
    }
    return value
  }

  private static func urlQueryValue(_ raw: String) -> String {
    raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
  }
}
