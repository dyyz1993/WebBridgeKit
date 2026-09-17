import Foundation
import Hummingbird

/// Public contract for Drel's optional managed signer. This is deliberately
/// separate from `drel.self-hosted-push.v1`: the managed service owns an APNs
/// credential, while a direct self-hosted server is operated with its own
/// Apple-authorized credential.
struct ManagedEncryptedPushDescriptor: ResponseEncodable, Sendable {
  let schema = "drel.managed-encrypted-push.v1"
  let name: String
  let publicBaseURL: String
  let registrationPath = "/managed-push/register"
  let pairingPath = "/managed-push/pairings"
  let recipientPath = "/managed-push/recipients/{deviceKey}"
  let deliveryPath = "/managed-push/deliveries/{deviceKey}"
  let unregisterPath = "/managed-push/unregister"
  let healthPath = "/managed-push/health"
  let envelopeSchema = "drel.push-envelope.v1"
}

struct ManagedEncryptedPushPairingResponse: ResponseEncodable, Sendable {
  let schema = "drel.managed-encrypted-push-pairing.v1"
  let pairingToken: String
  let expiresAt: String
  let configurationURL: String
}

struct ManagedEncryptedPushHealthResponse: ResponseEncodable, Sendable {
  let status: String
  let apnsReady: Bool
}

struct ManagedEncryptedPushRegistrationResponse: ResponseEncodable, Sendable {
  let schema = "drel.managed-encrypted-push-registration.v1"
  let deviceKey: String
  let recipientPath: String
  let deliveryPath: String
  let message: String
}

struct ManagedEncryptedPushRecipientResponse: ResponseEncodable, Sendable {
  let schema = "drel.managed-encrypted-push-recipient.v1"
  let deviceKey: String
  /// X25519 public material only. A sender needs this to encrypt, but it
  /// cannot decrypt the delivered envelope or impersonate the APNs provider.
  let encryptionPublicKey: String
  let deliveryPath: String
  let envelopeSchema = "drel.push-envelope.v1"
}

struct ManagedEncryptedPushUnregistrationRequest: Codable, Sendable {
  let deviceToken: String
  let deviceKey: String
}

struct ManagedEncryptedPushUnregistrationResponse: ResponseEncodable, Sendable {
  let code: Int
  let removed: Bool
}
