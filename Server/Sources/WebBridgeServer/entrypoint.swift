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

        let cors = Hummingbird.CORSMiddleware<BasicRequestContext>(
            allowOrigin: .all,
            allowHeaders: [.accept, .authorization, .contentType, .origin],
            allowMethods: [.get, .post, .put, .delete, .head, .options, .patch]
        )
        router.add(middleware: cors)
        router.add(middleware: AuthMiddleware<BasicRequestContext>(apiKey: config.adminAPIKey))

        HealthRoutes.register(on: router)
        PushRoutes.register(on: router, services: services)
        ManifestRoutes.register(on: router, services: services)
        CommandRoutes.register(on: router, services: services)

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
