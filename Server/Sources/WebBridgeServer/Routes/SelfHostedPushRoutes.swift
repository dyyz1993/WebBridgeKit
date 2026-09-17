import Foundation
import Hummingbird

enum SelfHostedPushRoutes {
  static func register(on router: Router<some RequestContext>, services: ServiceRegistry) {
    router.get("/.well-known/drel-push.json") { _, _ in
      SelfHostedPushDescriptor(
        name: services.configuration.selfHostedName,
        publicBaseURL: services.configuration.selfHostedPublicBaseURL,
        serverIdentityKeyID: services.configuration.selfHostedIdentityKeyID,
        serverIdentityPublicKey: services.configuration.selfHostedIdentityPublicKey
      )
    }

    router.post("/self-hosted/pairings") { _, _ in
      guard let ticket = await services.selfHostedPairingStore.issue() else {
        throw HTTPError(
          .tooManyRequests, message: "Too many outstanding pairing tickets; try again shortly")
      }
      let baseURL = services.configuration.selfHostedPublicBaseURL
        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let formatter = ISO8601DateFormatter()
      return SelfHostedPairingResponse(
        pairingToken: ticket.token,
        expiresAt: formatter.string(from: ticket.expiresAt),
        configurationURL:
          "drel://self-hosted-push?server=\(Self.urlQueryValue(baseURL))&token=\(ticket.token)"
      )
    }

    router.get("/self-hosted/recipients/:deviceKey") { _, context in
      guard let deviceKey = context.parameters.get("deviceKey"),
        !deviceKey.isEmpty,
        let publicKey = await services.tokenStore.encryptionPublicKey(forKey: deviceKey)
      else {
        throw HTTPError(.notFound, message: "No paired encrypted recipient for this device key")
      }
      return SelfHostedRecipientResponse(
        deviceKey: deviceKey,
        encryptionPublicKey: publicKey,
        pushPath: "/push"
      )
    }

    router.post("/self-hosted/register") { request, context in
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
      guard await services.selfHostedPairingStore.consume(registration.pairingToken) else {
        throw HTTPError(
          .unauthorized, message: "Pairing token is invalid, expired, or already used")
      }

      let stored = DeviceRegistration(
        deviceToken: registration.deviceToken,
        key: registration.deviceKey,
        platform: registration.platform ?? "ios",
        appVersion: registration.appVersion,
        encryptionPublicKey: registration.encryptionPublicKey,
        drelSourceChannel: Self.sourceChannelID(
          for: services.configuration.selfHostedPublicBaseURL)
      )
      do {
        try await services.apnsService.registerDevice(stored)
      } catch {
        throw HTTPError(.internalServerError, message: "Device registration could not be persisted")
      }

      let baseURL = services.configuration.selfHostedPublicBaseURL
        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return SelfHostedRegistrationResponse(
        deviceKey: registration.deviceKey,
        pushURL: "\(baseURL)/\(registration.deviceKey)",
        message: "Self-hosted encrypted push is ready"
      )
    }
  }

  private static func urlQueryValue(_ raw: String) -> String {
    raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
  }

  private static func sourceChannelID(for baseURL: String) -> String {
    let normalized = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return "drel.selfhosted.\(normalized.lowercased())"
  }
}
