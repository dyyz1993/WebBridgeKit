import Crypto
import Foundation
import Hummingbird
import HummingbirdTesting
import NIOCore
import Testing

@testable import WebBridgeServer

@Suite("Self-hosted Push Routes")
struct SelfHostedPushRoutesTests {
  @Test("descriptor advertises the versioned self-hosted Drel contract")
  func descriptorAdvertisesContract() async throws {
    let app = makeApplication()

    try await app.test(.router) { client in
      try await client.execute(uri: "/.well-known/drel-push.json", method: .get) { response in
        #expect(response.status == .ok)
        let json = try responseJSON(response.body)
        #expect(json["schema"] as? String == "drel.self-hosted-push.v1")
                #expect(json["registrationPath"] as? String == "/self-hosted/register")
                #expect(json["recipientPath"] as? String == "/self-hosted/recipients/{deviceKey}")
                #expect(json["pushPath"] as? String == "/push")
                #expect(json["healthPath"] as? String == "/health")
      }
    }
  }

  @Test("pairing token can register exactly one encryption public key")
  func pairingTokenIsSingleUse() async throws {
    let pairingStore = SelfHostedPairingStore(ttl: 60)
    let tokenStore = TokenStore()
    let services = ServiceRegistry(
      configuration: ServerConfiguration(),
      tokenStore: tokenStore,
      selfHostedPairingStore: pairingStore
    )
    let router = Router()
    SelfHostedPushRoutes.register(on: router, services: services)
    let app = Application(router: router)

    let pairing = try #require(await pairingStore.issue())
    let request = """
      {"deviceToken":"token-a","deviceKey":"device-key-a","encryptionPublicKey":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","pairingToken":"\(pairing.token)"}
      """

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/self-hosted/register",
        method: .post,
        headers: [.contentType: "application/json"],
        body: .init(string: request)
      ) { response in
        #expect(response.status == .ok)
        let json = try responseJSON(response.body)
        #expect(json["deviceKey"] as? String == "device-key-a")
        #expect((json["pushURL"] as? String)?.contains("device-key-a") == true)
      }

      try await client.execute(
        uri: "/self-hosted/register",
        method: .post,
        headers: [.contentType: "application/json"],
        body: .init(string: request)
      ) { response in
        #expect(response.status == .unauthorized)
      }
    }

    let registered = await tokenStore.getDevices(forKey: "device-key-a")
    #expect(registered.count == 1)
    #expect(registered.first?.encryptionPublicKey == "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
  }

  @Test("registration rejects an invalid encryption public key before persistence")
  func registrationRejectsInvalidPublicKey() async throws {
    let pairingStore = SelfHostedPairingStore(ttl: 60)
    let tokenStore = TokenStore()
    let services = ServiceRegistry(
      configuration: ServerConfiguration(),
      tokenStore: tokenStore,
      selfHostedPairingStore: pairingStore
    )
    let router = Router()
    SelfHostedPushRoutes.register(on: router, services: services)
    let app = Application(router: router)
    let pairing = try #require(await pairingStore.issue())

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/self-hosted/register",
        method: .post,
        headers: [.contentType: "application/json"],
        body: .init(
          string:
            "{\"deviceToken\":\"token-a\",\"deviceKey\":\"device-key-a\",\"encryptionPublicKey\":\"not-a-key\",\"pairingToken\":\"\(pairing.token)\"}"
        )
      ) { response in
        #expect(response.status == .badRequest)
      }
    }

    #expect(await tokenStore.getDevices(forKey: "device-key-a").isEmpty)
  }

  @Test("recipient discovery exposes only the sender encryption public key")
  func recipientDiscoveryExcludesAPNsToken() async throws {
    let pairingStore = SelfHostedPairingStore(ttl: 60)
    let tokenStore = TokenStore()
    let services = ServiceRegistry(
      configuration: ServerConfiguration(),
      tokenStore: tokenStore,
      selfHostedPairingStore: pairingStore
    )
    let router = Router()
    SelfHostedPushRoutes.register(on: router, services: services)
    let app = Application(router: router)
    let pairing = try #require(await pairingStore.issue())
    let publicKey = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    let registration = """
      {"deviceToken":"private-apns-token","deviceKey":"device-key-a","encryptionPublicKey":"\(publicKey)","pairingToken":"\(pairing.token)"}
      """

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/self-hosted/register",
        method: .post,
        headers: [.contentType: "application/json"],
        body: .init(string: registration)
      ) { response in
        #expect(response.status == .ok)
      }
      try await client.execute(uri: "/self-hosted/recipients/device-key-a", method: .get) {
        response in
        #expect(response.status == .ok)
        let json = try responseJSON(response.body)
        #expect(json["encryptionPublicKey"] as? String == publicKey)
        #expect(json["deviceKey"] as? String == "device-key-a")
        #expect(json["pushPath"] as? String == "/push")
        #expect(String(buffer: response.body).contains("private-apns-token") == false)
      }
    }
  }

  @Test("persisted pairing state never contains the redeemable ticket")
  func pairingPersistenceStoresOnlyDigest() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("drel-pairing-test-\(UUID().uuidString)", isDirectory: true)
    let fileURL = directory.appendingPathComponent("pairings.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = SelfHostedPairingStore(fileURL: fileURL, ttl: 60)
    let ticket = try #require(await store.issue())
    let raw = try String(contentsOf: fileURL, encoding: .utf8)
    #expect(!raw.contains(ticket.token))
    #expect(await store.consume(ticket.token))
    #expect(!(await store.consume(ticket.token)))
  }

  @Test("pairing issuance stays bounded when public requests are flooded")
  func pairingIssuanceIsBounded() async throws {
    let store = SelfHostedPairingStore(ttl: 60, maxTickets: 1)
    #expect(await store.issue() != nil)
    #expect(await store.issue() == nil)
  }

  @Test("self-hosted envelope decrypts only with the paired device private key")
  func envelopeUsesPerDeviceKeyAndKeepsPlaintextOutOfAPNs() throws {
    let recipient = Curve25519.KeyAgreement.PrivateKey()
    let payload = PushPayload(title: "Verification", body: "Code 482901", ttl: 120)

    let envelope = try SelfHostedEnvelopeService.seal(
      payload: payload,
      recipientPublicKey: recipient.publicKey.rawRepresentation,
      messageID: "message-42",
      now: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let recovered = try SelfHostedEnvelopeService.open(
      envelope,
      recipientPrivateKey: recipient,
      now: Date(timeIntervalSince1970: 1_700_000_001)
    )
    #expect(recovered.title == "Verification")
    #expect(recovered.body == "Code 482901")

    let outer = APNsService.makeAPNsPayload(
      PushPayload(
        title: "",
        body: "",
        messageID: "message-42",
        drelEnvelope: envelope.encoded()
      ))
    let aps = try #require(outer["aps"] as? [String: Any])
    let alert = try #require(aps["alert"] as? [String: Any])
    #expect(alert["title"] as? String == "加密消息")
    let encodedEnvelope = try #require(outer["drelEnvelope"] as? String)
    let outerEnvelope = try #require(SelfHostedEncryptedEnvelope.decode(encodedEnvelope))
    #expect(outerEnvelope.schema == envelope.schema)
    #expect(outerEnvelope.messageID == envelope.messageID)
    #expect(outerEnvelope.createdAt == envelope.createdAt)
    #expect(outerEnvelope.expiresAt == envelope.expiresAt)
    #expect(outerEnvelope.ephemeralPublicKey == envelope.ephemeralPublicKey)
    #expect(outerEnvelope.ciphertext == envelope.ciphertext)
    #expect(outer["body"] as? String == "")
  }

  @Test("pre-encrypted sender envelope strips every plaintext wrapper before APNs")
  func senderSideEnvelopeNeverForwardsPlaintextWrapper() throws {
    let recipient = Curve25519.KeyAgreement.PrivateKey()
    let envelope = try SelfHostedEnvelopeService.seal(
      payload: PushPayload(title: "Inner title", body: "Inner code 482901"),
      recipientPublicKey: recipient.publicKey.rawRepresentation,
      messageID: "sender-message-42"
    )
    let delivery = try APNsService.selfHostedDeliveryPayload(
      source: PushPayload(
        title: "Leaked wrapper title",
        body: "Leaked wrapper body",
        drelEnvelope: envelope.encoded()
      ),
      recipientPublicKey: SelfHostedEnvelopeService.base64URLEncoded(
        recipient.publicKey.rawRepresentation)
    )
    let apns = APNsService.makeAPNsPayload(delivery)
    #expect(delivery.title.isEmpty)
    #expect(delivery.body.isEmpty)
    #expect(delivery.messageID == "sender-message-42")
    #expect(apns["title"] as? String == "")
    #expect(apns["body"] as? String == "")
    #expect(String(describing: apns).contains("Leaked wrapper") == false)
    #expect(String(describing: apns).contains("Inner code 482901") == false)
  }

  @Test("Node sender reference envelope decrypts with the iPhone-compatible contract")
  func nodeSenderEnvelopeCrossRuntimeVector() throws {
    // Generated by Server/examples/drel-encrypt-and-push.mjs. This locks
    // the Node.js reference sender to CryptoKit's nonce|ciphertext|tag
    // combined representation used by the iOS notification extension.
    let privateKey = try #require(
      SelfHostedEnvelopeService.base64URLDecoded(
        "AHkC4jkVbK9JNRaYFduGfM5St2OFDyeOhjxfNqZFS34"
      ))
    // swiftlint:disable line_length
    let encoded =
      "eyJzY2hlbWEiOiJkcmVsLnB1c2gtZW52ZWxvcGUudjEiLCJtZXNzYWdlSUQiOiJub2RlLXZlY3Rvci00MiIsImNyZWF0ZWRBdCI6MTcwMDAwMDAwMCwiZXhwaXJlc0F0IjoxNzAwMDAzNjAwLCJlcGhlbWVyYWxQdWJsaWNLZXkiOiJlbnVaSG1wY3A3bm9EUDZ0RDBpMDh1MUdGaDA2QjVSblQzY2VBbnRrVUIwIiwiY2lwaGVydGV4dCI6ImE0akpDaktwaGdWR2dJYmpjQmpaekVFbHFUNmlSZ3ZXYXMya3poQUFQbWxpbzdyZUI3WUduNWI2Smg0MXFDbm4tbHp4aDM0ZWdmdG1naEN5SEtrMGJLLS1BdWd5c2lQdFp2eXl0emxEanljRXNQZ29BUDZERE5oUVU0bzNGTkNKU2NSS1FINWNWYzkzQlpfaUpkUFlvLXZSMU1pTEVvQmlrNUJuXzdPcE01UVB2WWt3RTI3VHlMcWxtdHRfIn0"
    // swiftlint:enable line_length
    let envelope = try #require(SelfHostedEncryptedEnvelope.decode(encoded))
    let recipient = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
    let recovered = try SelfHostedEnvelopeService.open(
      envelope,
      recipientPrivateKey: recipient,
      now: Date(timeIntervalSince1970: 1_700_000_001)
    )
    #expect(recovered.title == "Node sender")
    #expect(recovered.body == "Cross-runtime code 482901")
    #expect(recovered.url == "https://drel.app/")
    #expect(recovered.messageID == "node-vector-42")
  }

  private func makeApplication() -> Application<RouterResponder<BasicRequestContext>> {
    let router = Router()
    SelfHostedPushRoutes.register(
      on: router,
      services: ServiceRegistry(configuration: ServerConfiguration(), tokenStore: TokenStore())
    )
    return Application(router: router)
  }

  private func responseJSON(_ body: ByteBuffer) throws -> [String: Any] {
    let responseData = String(buffer: body)
    let data = Data(responseData.utf8)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }
}
