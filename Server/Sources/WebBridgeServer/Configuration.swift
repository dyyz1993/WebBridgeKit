import Foundation
import Hummingbird

struct ServerConfiguration: Sendable {
  let host: String
  let port: Int
  let adminAPIKey: String
  let apnsKeyID: String
  let apnsTeamID: String
  let apnsKeyPath: String
  let apnsTopic: String
  let apnsEnvironment: String
  let dataDir: String
  let allowedCORSOrigins: [String]
  let gatewayID: String
  let gatewayName: String
  let gatewayPublicBaseURL: String
  let gatewayKeyID: String
  let gatewayPrivateKey: String
  /// Server-side message history is OFF by default, matching Bark's
  /// privacy stance (the server never stores message content). Self-hosters
  /// who want reinstall/multi-device recovery opt in with MESSAGE_HISTORY_ENABLED=1.
  let messageHistoryEnabled: Bool
  let selfHostedName: String
  let selfHostedPublicBaseURL: String
  let selfHostedIdentityKeyID: String?
  let selfHostedIdentityPublicKey: String?
  /// Off by default so a generic self-hosted deployment never accidentally
  /// exposes Drel's managed signer contract. This mode is for the operator of
  /// the Apple-authorized Drel APNs credential only.
  let managedPushEnabled: Bool
  let managedPushName: String
  let managedPushPublicBaseURL: String
  let managedPushMaxDeliveriesPerMinute: Int

  init() {
    let env = Environment()
    self.host = env.get("SERVER_HOST") ?? "0.0.0.0"
    self.port = env.get("SERVER_PORT").flatMap(Int.init) ?? 8080
    self.adminAPIKey = env.get("ADMIN_API_KEY") ?? "changeme-admin-api-key"
    self.apnsKeyID = env.get("APNS_KEY_ID") ?? ""
    self.apnsTeamID = env.get("APNS_TEAM_ID") ?? ""
    self.apnsKeyPath = env.get("APNS_KEY_PATH") ?? ""
    self.apnsTopic = env.get("APNS_TOPIC") ?? "com.webbridgekit.superapp"
    self.apnsEnvironment = env.get("APNS_ENVIRONMENT") ?? "sandbox"
    self.dataDir = env.get("DATA_DIR") ?? "./data"
    self.gatewayID = env.get("GATEWAY_ID") ?? "webbridgekit-gateway"
    self.gatewayName = env.get("GATEWAY_NAME") ?? "WebBridgeKit Gateway"
    self.gatewayPublicBaseURL =
      env.get("GATEWAY_PUBLIC_BASE_URL") ?? "http://localhost:\(self.port)"
    self.gatewayKeyID = env.get("GATEWAY_KEY_ID") ?? ""
    self.gatewayPrivateKey = env.get("GATEWAY_PRIVATE_KEY") ?? ""
    self.messageHistoryEnabled = env.get("MESSAGE_HISTORY_ENABLED") == "1"
    self.selfHostedName = env.get("DREL_SELF_HOSTED_NAME") ?? "Drel Self-hosted Push"
    self.selfHostedPublicBaseURL =
      env.get("DREL_SELF_HOSTED_PUBLIC_BASE_URL")
      ?? "http://localhost:\(self.port)"
    self.selfHostedIdentityKeyID = env.get("DREL_SELF_HOSTED_IDENTITY_KEY_ID")
    self.selfHostedIdentityPublicKey = env.get("DREL_SELF_HOSTED_IDENTITY_PUBLIC_KEY")
    self.managedPushEnabled = env.get("DREL_MANAGED_PUSH_ENABLED") == "1"
    self.managedPushName = env.get("DREL_MANAGED_PUSH_NAME") ?? "Drel Managed Encrypted Push"
    self.managedPushPublicBaseURL =
      env.get("DREL_MANAGED_PUSH_PUBLIC_BASE_URL") ?? "http://localhost:\(self.port)"
    self.managedPushMaxDeliveriesPerMinute =
      max(1, env.get("DREL_MANAGED_PUSH_MAX_DELIVERIES_PER_MINUTE").flatMap(Int.init) ?? 60)
    let originsRaw: String? = env.get("CORS_ALLOWED_ORIGINS")
    self.allowedCORSOrigins =
      originsRaw.map {
        $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter {
          !$0.isEmpty
        }
      } ?? []
  }

  /// A public HTTPS self-hosted endpoint must never start in a state where it
  /// can accept pairings but silently drop every APNs notification.
  var requiresSelfHostedAPNs: Bool {
    URL(string: selfHostedPublicBaseURL)?.scheme?.lowercased() == "https"
  }
}

final class ServiceRegistry: Sendable {
  let configuration: ServerConfiguration
  let apnsService: APNsService
  let manifestService: ManifestService
  let commandService: CommandService
  let tokenStore: TokenStore
  let htmlAppGatewayService: HTMLAppGatewayService
  let approvalStore: ApprovalStore
  let approvalWebhookService: ApprovalWebhookService
  let selfHostedPairingStore: SelfHostedPairingStore
  /// Dedicated persistence for the managed signer. It must never share a
  /// registration file with a third-party direct self-hosted relay, otherwise
  /// an operator could accidentally make a managed APNs token visible to a
  /// separate deployment lifecycle.
  let managedPushTokenStore: TokenStore
  let managedAPNsService: APNsService
  let managedPushPairingStore: SelfHostedPairingStore
  let managedPushDeliveryLimiter: ManagedPushDeliveryLimiter

  init(
    configuration: ServerConfiguration,
    htmlAppGatewayService: HTMLAppGatewayService? = nil,
    approvalStore: ApprovalStore? = nil,
    tokenStore: TokenStore? = nil,
    selfHostedPairingStore: SelfHostedPairingStore? = nil,
    managedPushTokenStore: TokenStore? = nil,
    managedPushPairingStore: SelfHostedPairingStore? = nil,
    managedPushDeliveryLimiter: ManagedPushDeliveryLimiter? = nil
  ) {
    self.configuration = configuration
    let resolvedTokenStore =
      tokenStore
      ?? TokenStore(
        fileURL: URL(fileURLWithPath: configuration.dataDir, isDirectory: true)
          .appendingPathComponent("device-registrations.json")
      )
    self.tokenStore = resolvedTokenStore
    self.apnsService = APNsService(configuration: configuration, tokenStore: resolvedTokenStore)
    self.manifestService = ManifestService(dataDir: configuration.dataDir)
    self.commandService = CommandService()
    self.htmlAppGatewayService =
      htmlAppGatewayService
      ?? HTMLAppGatewayService(
        dataDir: configuration.dataDir,
        gatewayID: configuration.gatewayID,
        gatewayName: configuration.gatewayName,
        publicBaseURL: configuration.gatewayPublicBaseURL,
        keyID: configuration.gatewayKeyID,
        privateKeyValue: configuration.gatewayPrivateKey
      )
    let resolvedApprovalStore =
      approvalStore
      ?? ApprovalStore(
        fileURL: URL(fileURLWithPath: configuration.dataDir, isDirectory: true)
          .appendingPathComponent("approvals.json")
      )
    self.approvalStore = resolvedApprovalStore
    self.approvalWebhookService = ApprovalWebhookService(store: resolvedApprovalStore)
    self.selfHostedPairingStore =
      selfHostedPairingStore
      ?? SelfHostedPairingStore(
        fileURL: URL(fileURLWithPath: configuration.dataDir, isDirectory: true)
          .appendingPathComponent("self-hosted-pairings.json")
      )
    let resolvedManagedPushTokenStore =
      managedPushTokenStore
      ?? TokenStore(
        fileURL: URL(fileURLWithPath: configuration.dataDir, isDirectory: true)
          .appendingPathComponent("managed-encrypted-device-registrations.json")
      )
    self.managedPushTokenStore = resolvedManagedPushTokenStore
    self.managedAPNsService = APNsService(
      configuration: configuration, tokenStore: resolvedManagedPushTokenStore)
    self.managedPushPairingStore =
      managedPushPairingStore
      ?? SelfHostedPairingStore(
        fileURL: URL(fileURLWithPath: configuration.dataDir, isDirectory: true)
          .appendingPathComponent("managed-encrypted-pairings.json")
      )
    self.managedPushDeliveryLimiter =
      managedPushDeliveryLimiter
      ?? ManagedPushDeliveryLimiter(
        maxDeliveries: configuration.managedPushMaxDeliveriesPerMinute,
        window: 60
      )
  }
}
