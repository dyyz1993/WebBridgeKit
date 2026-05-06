import Foundation
import Hummingbird

enum HealthRoutes {
    static func register(on router: Router<some RequestContext>) {
        router.get("/health") { _, _ in
            HealthResponse(status: "ok", timestamp: Int(Date().timeIntervalSince1970))
        }

        router.get("api/v1/stats") { _, _ in
            StatsResponse(
                uptime: Int(ProcessInfo.processInfo.systemUptime),
                version: "1.0.0"
            )
        }
    }
}

private struct HealthResponse: ResponseEncodable, Sendable {
    let status: String
    let timestamp: Int
}

private struct StatsResponse: ResponseEncodable, Sendable {
    let uptime: Int
    let version: String
}
