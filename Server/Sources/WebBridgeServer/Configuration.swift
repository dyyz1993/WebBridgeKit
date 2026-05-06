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
    }
}

final class ServiceRegistry: Sendable {
    let apnsService: APNsService
    let manifestService: ManifestService
    let commandService: CommandService
    let tokenStore: TokenStore

    init(configuration: ServerConfiguration) {
        self.tokenStore = TokenStore()
        self.apnsService = APNsService(configuration: configuration, tokenStore: TokenStore())
        self.manifestService = ManifestService(dataDir: configuration.dataDir)
        self.commandService = CommandService()
    }
}
