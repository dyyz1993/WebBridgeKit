import Foundation
import Hummingbird

struct ManifestRoutes {
    let services: ServiceRegistry

    func register(on router: Router<some RequestContext>) {
        let apiGroup = router.group("api/v1/manifests")

        apiGroup.get { _, _ in
            await services.manifestService.list()
        }

        apiGroup.get("/:appId") { _, context in
            guard let appId = context.parameters.get("appId") else {
                throw HTTPError(.badRequest, message: "Missing appId")
            }
            return try await services.manifestService.get(appId: appId)
        }

        apiGroup.post { request, context in
            let manifest = try await request.decode(as: Manifest.self, context: context)
            await services.manifestService.save(manifest)
            return ManifestUploadResponse(code: 200, message: "Manifest saved", appId: manifest.appId)
        }

        apiGroup.get("/:appId/version") { _, context in
            guard let appId = context.parameters.get("appId") else {
                throw HTTPError(.badRequest, message: "Missing appId")
            }
            return try await services.manifestService.getVersion(appId: appId)
        }
    }
}

// MARK: - HTTP Error Helpers

enum HTTPStatusHelper {
    static func localizedString(forStatusCode statusCode: Int) -> String {
        switch statusCode {
        case 400...499:
            return "Client error (\(statusCode)) - Please check your request"
        case 500...599:
            return "Server error (\(statusCode)) - Backend service is unavailable. Please try again later."
        default:
            return "HTTP \(statusCode)"
        }
    }
}

private struct ManifestUploadResponse: ResponseEncodable, Sendable {
    let code: Int
    let message: String
    let appId: String
}
