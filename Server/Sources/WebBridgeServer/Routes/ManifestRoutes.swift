import Foundation
import Hummingbird

struct ManifestRoutes {
    let services: ServiceRegistry

    func register(on router: Router<some RequestContext>) {
        let apiGroup = router.group("api/v1/manifests")

        apiGroup.get { _, _ in
            try await services.manifestService.list()
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

private struct ManifestUploadResponse: ResponseEncodable, Sendable {
    let code: Int
    let message: String
    let appId: String
}
