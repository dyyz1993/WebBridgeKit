import Hummingbird
import HummingbirdTesting
import Testing
import NIOCore

@testable import WebBridgeServer

@Suite("Manifest Routes")
struct ManifestRoutesTests {
    private func createApplication() -> Application<RouterResponder<BasicRequestContext>> {
        let router = Router()
        let config = ServerConfiguration()
        let services = ServiceRegistry(configuration: config)
        ManifestRoutes(services: services).register(on: router)
        return Application(router: router)
    }

    @Test("List manifests returns empty list")
    func listEmptyManifests() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            try await client.execute(uri: "/api/v1/manifests", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("Upload and retrieve manifest")
    func uploadAndRetrieve() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            let manifestJSON = """
            {
                "appId": "com.test.app",
                "version": "1.0.0",
                "buildNumber": 1,
                "resources": [],
                "integrity": {"algorithm": "sha256", "manifestHash": "abc123"},
                "createdAt": "2025-01-01T00:00:00Z",
                "updatedAt": "2025-01-01T00:00:00Z"
            }
            """
            let body = ByteBuffer(string: manifestJSON)

            try await client.execute(uri: "/api/v1/manifests", method: .post, body: body) { response in
                #expect(response.status == .ok)
            }

            try await client.execute(uri: "/api/v1/manifests/com.test.app", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("Get non-existent manifest returns 404")
    func getNonExistent() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            try await client.execute(uri: "/api/v1/manifests/nonexistent", method: .get) { response in
                #expect(response.status == .notFound)
            }
        }
    }

    @Test("Get manifest version")
    func getManifestVersion() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            let manifestJSON = """
            {
                "appId": "com.test.version",
                "version": "2.1.0",
                "buildNumber": 42,
                "resources": [],
                "integrity": {"algorithm": "sha256", "manifestHash": "def456"},
                "createdAt": "2025-01-01T00:00:00Z",
                "updatedAt": "2025-01-01T00:00:00Z"
            }
            """
            let body = ByteBuffer(string: manifestJSON)
            try await client.execute(uri: "/api/v1/manifests", method: .post, body: body) { response in
                #expect(response.status == .ok)
            }

            try await client.execute(uri: "/api/v1/manifests/com.test.version/version", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }
}
