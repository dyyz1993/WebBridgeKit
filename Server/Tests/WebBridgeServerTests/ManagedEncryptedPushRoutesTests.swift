import Crypto
import Foundation
import Hummingbird
import HummingbirdTesting
import NIOCore
import Testing

@testable import WebBridgeServer

@Suite("Managed encrypted push routes")
struct ManagedEncryptedPushRoutesTests {
  @Test("managed delivery limits one bearer capability without affecting other devices")
  func deliveryRateLimitIsPerDeviceCapability() async {
    let limiter = ManagedPushDeliveryLimiter(maxDeliveries: 1, window: 60)
    #expect(await limiter.allow(deviceKey: "device-a"))
    #expect(!(await limiter.allow(deviceKey: "device-a")))
    #expect(await limiter.allow(deviceKey: "device-b"))
  }

  @Test("managed descriptor describes an opaque signer and never a provider credential")
  func descriptorDescribesOpaqueSigner() async throws {
    let app = makeApplication()

    try await app.test(.router) { client in
      try await client.execute(uri: "/.well-known/drel-managed-push.json", method: .get) {
        response in
        #expect(response.status == .ok)
        let json = try responseJSON(response.body)
        #expect(json["schema"] as? String == "drel.managed-encrypted-push.v1")
        #expect(json["healthPath"] as? String == "/managed-push/health")
        #expect(json["recipientPath"] as? String == "/managed-push/recipients/{deviceKey}")
        #expect(json["deliveryPath"] as? String == "/managed-push/deliveries/{deviceKey}")
        let body = String(buffer: response.body)
        #expect(!body.localizedCaseInsensitiveContains("token"))
        #expect(!body.localizedCaseInsensitiveContains("private"))
        #expect(!body.localizedCaseInsensitiveContains("p8"))
      }
    }
  }

  @Test("managed pairing and health use the managed contract")
  func pairingAndHealthUseManagedContract() async throws {
    let app = makeApplication()

    try await app.test(.router) { client in
      try await client.execute(uri: "/managed-push/health", method: .get) { response in
        let json = try responseJSON(response.body)
        #expect(json["apnsReady"] as? Bool == false)
      }
      try await client.execute(uri: "/managed-push/pairings", method: .post) { response in
        #expect(response.status == .ok)
        let json = try responseJSON(response.body)
        #expect(json["schema"] as? String == "drel.managed-encrypted-push-pairing.v1")
        #expect((json["configurationURL"] as? String)?.hasPrefix(
          "drel://managed-encrypted-push?") == true)
      }
    }
  }

  @Test("managed registration is single-use and recipient discovery hides the APNs token")
  func registrationIsSingleUseAndPrivateTokenStaysPrivate() async throws {
    let pairingStore = SelfHostedPairingStore(ttl: 60)
    let tokenStore = TokenStore()
    let app = makeApplication(tokenStore: tokenStore, pairingStore: pairingStore)
    let pairing = try #require(await pairingStore.issue())
    let publicKey = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    let body = """
      {"deviceToken":"private-apns-token","deviceKey":"managed-device-a","encryptionPublicKey":"\(publicKey)","pairingToken":"\(pairing.token)"}
      """

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/managed-push/register", method: .post,
        headers: [.contentType: "application/json"], body: .init(string: body)
      ) { response in
        #expect(response.status == .ok)
      }
      try await client.execute(
        uri: "/managed-push/register", method: .post,
        headers: [.contentType: "application/json"], body: .init(string: body)
      ) { response in
        #expect(response.status == .unauthorized)
      }
      try await client.execute(uri: "/managed-push/recipients/managed-device-a", method: .get) {
        response in
        #expect(response.status == .ok)
        let json = try responseJSON(response.body)
        #expect(json["deviceKey"] as? String == "managed-device-a")
        #expect(json["encryptionPublicKey"] as? String == publicKey)
        #expect(String(buffer: response.body).contains("private-apns-token") == false)
      }
    }
  }

  @Test("managed delivery rejects every plaintext wrapper before the signer is reached")
  func deliveryRejectsPlaintextWrapper() async throws {
    let recipient = Curve25519.KeyAgreement.PrivateKey()
    let envelope = try SelfHostedEnvelopeService.seal(
      payload: PushPayload(title: "Inner", body: "Code 482901"),
      recipientPublicKey: recipient.publicKey.rawRepresentation,
      messageID: "managed-message-42"
    )
    let app = makeApplication()

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/managed-push/deliveries/managed-device-a", method: .post,
        headers: [.contentType: "application/json"],
        body: .init(string: "{\"drelEnvelope\":\"\(envelope.encoded())\",\"title\":\"leaked\"}")
      ) { response in
        #expect(response.status == .badRequest)
      }
    }
  }

  @Test("managed delivery fails closed when the APNs signer is unavailable")
  func deliveryFailsClosedWithoutSigner() async throws {
    let recipient = Curve25519.KeyAgreement.PrivateKey()
    let envelope = try SelfHostedEnvelopeService.seal(
      payload: PushPayload(title: "Inner", body: "Code 482901"),
      recipientPublicKey: recipient.publicKey.rawRepresentation,
      messageID: "managed-message-availability"
    )
    let app = makeApplication()

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/managed-push/deliveries/managed-device-a", method: .post,
        headers: [.contentType: "application/json"],
        body: .init(string: "{\"drelEnvelope\":\"\(envelope.encoded())\"}")
      ) { response in
        #expect(response.status == .serviceUnavailable)
      }
    }
  }

  @Test("managed delivery payload is opaque to the signer and APNs")
  func opaqueDeliveryContainsNoBusinessPlaintext() throws {
    let recipient = Curve25519.KeyAgreement.PrivateKey()
    let envelope = try SelfHostedEnvelopeService.seal(
      payload: PushPayload(title: "Verification", body: "Code 482901"),
      recipientPublicKey: recipient.publicKey.rawRepresentation,
      messageID: "managed-message-42"
    )

    let payload = try APNsService.managedOpaqueDeliveryPayload(envelope: envelope.encoded())
    let apns = APNsService.makeAPNsPayload(payload)
    #expect(payload.title.isEmpty)
    #expect(payload.body.isEmpty)
    #expect(payload.messageID == "managed-message-42")
    let forwarded = try #require(apns["drelEnvelope"] as? String)
    let forwardedEnvelope = try #require(SelfHostedEncryptedEnvelope.decode(forwarded))
    #expect(forwardedEnvelope.messageID == envelope.messageID)
    #expect(forwardedEnvelope.ciphertext == envelope.ciphertext)
    #expect(String(describing: apns).contains("Verification") == false)
    #expect(String(describing: apns).contains("482901") == false)
  }

  @Test("managed removal revokes the public recipient capability")
  func removalRevokesRecipient() async throws {
    let pairingStore = SelfHostedPairingStore(ttl: 60)
    let tokenStore = TokenStore()
    let app = makeApplication(tokenStore: tokenStore, pairingStore: pairingStore)
    let pairing = try #require(await pairingStore.issue())
    let registration = """
      {"deviceToken":"device-token-a","deviceKey":"managed-device-a","encryptionPublicKey":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","pairingToken":"\(pairing.token)"}
      """

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/managed-push/register", method: .post,
        headers: [.contentType: "application/json"], body: .init(string: registration)
      ) { response in #expect(response.status == .ok) }
      try await client.execute(
        uri: "/managed-push/unregister", method: .post,
        headers: [.contentType: "application/json"],
        body: .init(string: "{\"deviceToken\":\"device-token-a\",\"deviceKey\":\"managed-device-a\"}")
      ) { response in #expect(response.status == .ok) }
      try await client.execute(uri: "/managed-push/recipients/managed-device-a", method: .get) {
        response in #expect(response.status == .notFound)
      }
    }
  }

  private func makeApplication(
    tokenStore: TokenStore = TokenStore(),
    pairingStore: SelfHostedPairingStore = SelfHostedPairingStore(ttl: 60)
  ) -> Application<RouterResponder<BasicRequestContext>> {
    let router = Router()
    let services = ServiceRegistry(
      configuration: ServerConfiguration(),
      managedPushTokenStore: tokenStore,
      managedPushPairingStore: pairingStore
    )
    ManagedEncryptedPushRoutes.register(on: router, services: services)
    return Application(router: router)
  }

  private func responseJSON(_ body: ByteBuffer) throws -> [String: Any] {
    let data = Data(String(buffer: body).utf8)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }
}
