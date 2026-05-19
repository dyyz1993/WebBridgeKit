import Hummingbird
import Logging
import NIOCore
import NIOPosix

@main
struct WebBridgeServer {
    static func main() async throws {
        let config = ServerConfiguration()
        let router = Router()
        let services = ServiceRegistry(configuration: config)
        let logger = Logger(label: "WebBridgeServer")

        // 🔒 Security: CORS Configuration
        // WARNING: allowOrigin: .all is for development only!
        // Production should use specific origins to prevent CSRF attacks.
        // Example: allowOrigin: .custom("https://example.com")
        let cors = Hummingbird.CORSMiddleware<BasicRequestContext>(
            allowOrigin: .all,  // ⚠️ TODO: Change to specific origin(s) in production
            allowHeaders: [.accept, .authorization, .contentType, .origin],
            allowMethods: [.get, .post, .put, .delete, .head, .options, .patch]
        )
        router.add(middleware: cors)
        logger.warning("CORS configured with allowOrigin: .all (DEVELOPMENT MODE - change to specific origins in production)")
        router.add(middleware: AuthMiddleware<BasicRequestContext>(apiKey: config.adminAPIKey))

        HealthRoutes.register(on: router)
        PushRoutes.register(on: router, services: services)
        ManifestRoutes(services: services).register(on: router)
        CommandRoutes(services: services).register(on: router)

        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname(config.host, port: config.port),
                serverName: "WebBridgeServer"
            ),
            logger: Logger(label: "WebBridgeServer")
        )

        try await app.runService()
    }
}
