import Foundation
import Hummingbird

struct Manifest: Codable, Sendable, ResponseEncodable {
    let appId: String
    let version: String
    let buildNumber: Int
    let resources: [ManifestResource]
    let integrity: ManifestIntegrity
    let createdAt: String
    let updatedAt: String

    struct ManifestResource: Codable, Sendable {
        let path: String
        let url: String
        let hash: String
        let size: Int
    }

    struct ManifestIntegrity: Codable, Sendable {
        let algorithm: String
        let manifestHash: String
    }
}

struct ManifestListResponse: ResponseEncodable, Sendable {
    let manifests: [ManifestSummary]

    struct ManifestSummary: ResponseEncodable, Sendable {
        let appId: String
        let version: String
        let buildNumber: Int
        let updatedAt: String
    }
}

struct ManifestVersionResponse: ResponseEncodable, Sendable {
    let appId: String
    let version: String
    let buildNumber: Int
}
