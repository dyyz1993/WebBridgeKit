import HTTPTypes
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

        let allowedHeaders: [HTTPField.Name] = [.accept, .authorization, .contentType, .origin]
        let allowedMethods: [HTTPRequest.Method] = [.get, .post, .put, .delete, .head, .options, .patch]

        if config.allowedCORSOrigins.isEmpty {
            let cors = Hummingbird.CORSMiddleware<BasicRequestContext>(
                allowOrigin: .all,
                allowHeaders: allowedHeaders,
                allowMethods: allowedMethods,
                maxAge: .seconds(3600)
            )
            router.add(middleware: cors)
            logger.warning("CORS: allowOrigin .all (DEVELOPMENT MODE — set CORS_ALLOWED_ORIGINS for production)")
        } else {
            let cors = CORSWhitelistMiddleware<BasicRequestContext>(
                allowedOrigins: config.allowedCORSOrigins,
                allowHeaders: allowedHeaders,
                allowMethods: allowedMethods,
                maxAge: .seconds(3600)
            )
            router.add(middleware: cors)
            logger.info("CORS: whitelist active with \(config.allowedCORSOrigins.count) origin(s)")
        }
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
