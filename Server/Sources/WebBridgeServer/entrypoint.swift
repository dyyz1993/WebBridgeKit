import Foundation
import HTTPTypes
import Hummingbird
import Logging
import NIOCore
import NIOPosix

private enum SelfHostedStartupError: LocalizedError {
  case apnsCredentialUnavailable
  case managedAPNsCredentialUnavailable

  var errorDescription: String? {
    switch self {
    case .apnsCredentialUnavailable:
      return
        "A public Drel self-hosted endpoint requires a readable APNs .p8, APNS_KEY_ID, and APNS_TEAM_ID."
    case .managedAPNsCredentialUnavailable:
      return
        "Drel managed encrypted push requires a readable APNs .p8, APNS_KEY_ID, and APNS_TEAM_ID."
    }
  }
}

@main
struct WebBridgeServer {
  static func main() async throws {
    let config = ServerConfiguration()
    let router = Router()
    let services = ServiceRegistry(configuration: config)
    let logger = Logger(label: "WebBridgeServer")

    guard !config.requiresSelfHostedAPNs || services.apnsService.isReady else {
      logger.critical(
        "Refusing to start public Drel self-hosted push without a usable APNs provider credential")
      throw SelfHostedStartupError.apnsCredentialUnavailable
    }
    guard !config.managedPushEnabled || services.managedAPNsService.isReady else {
      logger.critical(
        "Refusing to enable managed encrypted push without a usable APNs provider credential")
      throw SelfHostedStartupError.managedAPNsCredentialUnavailable
    }

    let allowedHeaders: [HTTPField.Name] = [.accept, .authorization, .contentType, .origin]
    let allowedMethods: [HTTPRequest.Method] = [
      .get, .post, .put, .delete, .head, .options, .patch,
    ]

    if config.allowedCORSOrigins.isEmpty {
      let cors = Hummingbird.CORSMiddleware<BasicRequestContext>(
        allowOrigin: .all,
        allowHeaders: allowedHeaders,
        allowMethods: allowedMethods,
        maxAge: .seconds(3600)
      )
      router.add(middleware: cors)
      logger.warning(
        "CORS: allowOrigin .all (DEVELOPMENT MODE — set CORS_ALLOWED_ORIGINS for production)")
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

    HealthRoutes.register(on: router, services: services)
    SelfHostedPushRoutes.register(on: router, services: services)
    if config.managedPushEnabled {
      ManagedEncryptedPushRoutes.register(on: router, services: services)
      logger.info("Managed opaque APNs signer routes enabled")
    }
    PushRoutes.register(on: router, services: services)
    ManifestRoutes(services: services).register(on: router)
    HTMLAppGatewayRoutes(services: services).register(on: router)
    CommandRoutes(services: services).register(on: router)
    ApprovalRoutes(services: services).register(on: router)

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
