import Foundation
import Hummingbird
import NIOCore

actor ManifestService {
    private var manifests: [String: Manifest] = [:]
    private let dataDir: String

    init(dataDir: String) {
        self.dataDir = dataDir
    }

    func list() -> ManifestListResponse {
        let summaries = manifests.values.map { manifest in
            ManifestListResponse.ManifestSummary(
                appId: manifest.appId,
                version: manifest.version,
                buildNumber: manifest.buildNumber,
                updatedAt: manifest.updatedAt
            )
        }
        return ManifestListResponse(manifests: summaries)
    }

    func get(appId: String) throws -> Manifest {
        guard let manifest = manifests[appId] else {
            throw HTTPError(.notFound, message: "Manifest not found: \(appId)")
        }
        return manifest
    }

    func save(_ manifest: Manifest) {
        manifests[manifest.appId] = manifest
    }

    func getVersion(appId: String) throws -> ManifestVersionResponse {
        guard let manifest = manifests[appId] else {
            throw HTTPError(.notFound, message: "Manifest not found: \(appId)")
        }
        return ManifestVersionResponse(
            appId: manifest.appId,
            version: manifest.version,
            buildNumber: manifest.buildNumber
        )
    }

    func manifestCount() -> Int {
        manifests.count
    }
}
