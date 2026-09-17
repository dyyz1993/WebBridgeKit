import Foundation
import Hummingbird

enum HealthRoutes {
  static func register(on router: Router<some RequestContext>, services: ServiceRegistry) {
    // Bark-compatible liveness response used by Drel before it starts a
    // richer self-hosted pairing flow.
    router.get("/ping") { _, _ in "pong" }
    router.get("/health") { _, _ in
      HealthResponse(
        status: "ok",
        version: ServerVersion.current,
        timestamp: Int(Date().timeIntervalSince1970),
        apnsReady: services.apnsService.isReady
      )
    }

    router.get("api/v1/stats") { _, _ in
      StatsResponse(
        uptime: Int(ProcessInfo.processInfo.systemUptime),
        version: ServerVersion.current
      )
    }
  }
}

private struct HealthResponse: ResponseEncodable, Sendable {
  let status: String
  let version: String
  let timestamp: Int
  /// False is meaningful for a locally started server without a provider
  /// credential. The Drel app refuses that endpoint during self-hosted
  /// pairing instead of registering a device to a non-delivering server.
  let apnsReady: Bool
}

private struct StatsResponse: ResponseEncodable, Sendable {
  let uptime: Int
  let version: String
}
