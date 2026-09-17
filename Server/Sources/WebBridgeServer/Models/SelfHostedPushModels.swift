import Foundation
import Hummingbird

/// Public description fetched by Drel before a self-hosted server is trusted.
/// It intentionally contains no APNs token, private key, or pairing secret.
struct SelfHostedPushDescriptor: ResponseEncodable, Sendable {
  let schema = "drel.self-hosted-push.v1"
  let name: String
  let publicBaseURL: String
  let registrationPath = "/self-hosted/register"
  let pairingPath = "/self-hosted/pairings"
  /// Returns only an installation's X25519 *public* key so a sender can
  /// encrypt before posting. It never exposes the APNs token.
  let recipientPath = "/self-hosted/recipients/{deviceKey}"
  let pushPath = "/push"
  let healthPath = "/health"
  let serverIdentityKeyID: String?
  let serverIdentityPublicKey: String?
}

struct SelfHostedPairingTicket: Codable, Sendable {
  let token: String
  let expiresAt: Date
}

struct SelfHostedPairingResponse: ResponseEncodable, Sendable {
  let schema = "drel.self-hosted-pairing.v1"
  let pairingToken: String
  let expiresAt: String
  let configurationURL: String
}

struct SelfHostedRegistrationRequest: Codable, Sendable {
  let deviceToken: String
  let deviceKey: String
  let encryptionPublicKey: String
  let pairingToken: String
  let platform: String?
  let appVersion: String?

  func validatedPublicKey() -> Data? {
    guard let data = Self.base64URLDecoded(encryptionPublicKey), data.count == 32 else {
      return nil
    }
    return data
  }

  private static func base64URLDecoded(_ value: String) -> Data? {
    var base64 =
      value
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
    return Data(base64Encoded: base64)
  }
}

struct SelfHostedRegistrationResponse: ResponseEncodable, Sendable {
  let schema = "drel.self-hosted-registration.v1"
  let deviceKey: String
  let pushURL: String
  let message: String
}

/// Public sender bootstrap material. `deviceKey` remains a bearer push
/// address; the key here is deliberately public and cannot decrypt a message.
struct SelfHostedRecipientResponse: ResponseEncodable, Sendable {
  let schema = "drel.self-hosted-recipient.v1"
  let deviceKey: String
  let encryptionPublicKey: String
  let pushPath: String
  let envelopeSchema = "drel.push-envelope.v1"
}
