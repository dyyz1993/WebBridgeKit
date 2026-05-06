import Hummingbird
import HummingbirdTesting
import Testing
import NIOCore

@testable import WebBridgeServer

@Suite("Push Routes")
struct PushRoutesTests {
    private func createApplication() -> Application<RouterResponder<BasicRequestContext>> {
        let router = Router()
        let config = ServerConfiguration()
        let services = ServiceRegistry(configuration: config)
        PushRoutes.register(on: router, services: services)
        return Application(router: router)
    }

    @Test("Bark-compatible GET push")
    func barkGetPush() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            try await client.execute(uri: "/testkey/hello/world", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("Bark-compatible POST push")
    func barkPostPush() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            try await client.execute(uri: "/testkey/title/body", method: .post) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("JSON push endpoint")
    func jsonPush() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            let body = ByteBuffer(string: """
            {"device_key": "testkey", "title": "Hello", "body": "World"}
            """)
            try await client.execute(uri: "/push", method: .post, body: body) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("Device registration")
    func deviceRegistration() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            let body = ByteBuffer(string: """
            {"deviceToken": "abc123", "key": "mykey"}
            """)
            try await client.execute(uri: "/register", method: .post, body: body) { response in
                #expect(response.status == .ok)
            }
        }
    }
}
