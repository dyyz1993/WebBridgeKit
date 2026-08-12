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

    init() {
        let env = Environment()
        self.host = env.get("SERVER_HOST") ?? "0.0.0.0"
        self.port = env.get("SERVER_PORT").flatMap(Int.init) ?? 8080
        self.adminAPIKey = env.get("ADMIN_API_KEY") ?? "changeme-admin-api-key"
        self.apnsKeyID = env.get("APNS_KEY_ID") ?? ""
        self.apnsTeamID = env.get("APNS_TEAM_ID") ?? ""
        self.apnsKeyPath = env.get("APNS_KEY_PATH") ?? ""
        self.apnsTopic = env.get("APNS_TOPIC") ?? "com.webbridgekit.app"
        self.apnsEnvironment = env.get("APNS_ENVIRONMENT") ?? "sandbox"
        self.dataDir = env.get("DATA_DIR") ?? "./data"
        self.gatewayID = env.get("GATEWAY_ID") ?? "webbridgekit-gateway"
        self.gatewayName = env.get("GATEWAY_NAME") ?? "WebBridgeKit Gateway"
        self.gatewayPublicBaseURL = env.get("GATEWAY_PUBLIC_BASE_URL") ?? "http://localhost:\(self.port)"
        self.gatewayKeyID = env.get("GATEWAY_KEY_ID") ?? ""
        self.gatewayPrivateKey = env.get("GATEWAY_PRIVATE_KEY") ?? ""
        let originsRaw: String? = env.get("CORS_ALLOWED_ORIGINS")
        self.allowedCORSOrigins = originsRaw.map {
            $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        } ?? []
    }
}

final class ServiceRegistry: Sendable {
    let apnsService: APNsService
    let manifestService: ManifestService
    let commandService: CommandService
    let tokenStore: TokenStore
    let htmlAppGatewayService: HTMLAppGatewayService
    let approvalStore: ApprovalStore
    let approvalWebhookService: ApprovalWebhookService

    init(
        configuration: ServerConfiguration,
        htmlAppGatewayService: HTMLAppGatewayService? = nil,
        approvalStore: ApprovalStore? = nil
    ) {
        self.tokenStore = TokenStore()
        self.apnsService = APNsService(configuration: configuration, tokenStore: TokenStore())
        self.manifestService = ManifestService(dataDir: configuration.dataDir)
        self.commandService = CommandService()
        self.htmlAppGatewayService = htmlAppGatewayService ?? HTMLAppGatewayService(
            dataDir: configuration.dataDir,
            gatewayID: configuration.gatewayID,
            gatewayName: configuration.gatewayName,
            publicBaseURL: configuration.gatewayPublicBaseURL,
            keyID: configuration.gatewayKeyID,
            privateKeyValue: configuration.gatewayPrivateKey
        )
        let resolvedApprovalStore = approvalStore ?? ApprovalStore(
            fileURL: URL(fileURLWithPath: configuration.dataDir, isDirectory: true)
                .appendingPathComponent("approvals.json")
        )
        self.approvalStore = resolvedApprovalStore
        self.approvalWebhookService = ApprovalWebhookService(store: resolvedApprovalStore)
    }
}
