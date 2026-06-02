import Foundation
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
            try await client.execute(uri: "/test_resources/hello/world", method: .get) { response in
                #expect(response.status == .ok)
                let json = try responseJSON(response.body)
                #expect(json["code"] as? Int == 200)
            }
        }
    }

    @Test("Bark-compatible GET supports encoded title/body and query parameters")
    func barkGetPushWithEncodedQuery() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            let uri = [
                "/test_resources/Codex%20%E4%B8%AD%E6%96%87%20%E6%A0%87%E9%A2%98",
                "/route%20check%20%2F%20%E4%B8%AD%E6%96%87%20body",
                "?sound=bell&group=Codex%20Group",
                "&url=webbridgekit%3A%2F%2Fopen%3Furl%3Dhttps%253A%252F%252Fexample.com%252Ffrom-bark"
            ].joined()
            try await client.execute(uri: uri, method: .get) { response in
                #expect(response.status == .ok)
                let json = try responseJSON(response.body)
                #expect(json["code"] as? Int == 200)
            }
        }
    }

    @Test("Bark-compatible POST push")
    func barkPostPush() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            try await client.execute(uri: "/test_resources/title/body", method: .post) { response in
                #expect(response.status == .ok)
                let json = try responseJSON(response.body)
                #expect(json["code"] as? Int == 200)
            }
        }
    }

    @Test("JSON push endpoint")
    func jsonPush() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            let body = ByteBuffer(string: """
            {"device_key": "test", "title": "Hello", "body": "World"}
            """)
            try await client.execute(uri: "/push", method: .post, body: body) { response in
                #expect(response.status == .ok)
                let json = try responseJSON(response.body)
                #expect(json["code"] as? Int == 200)
            }
        }
    }

    @Test("JSON push endpoint accepts Bark optional payload fields")
    func jsonPushWithOptionalFields() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            let body = ByteBuffer(string: """
            {
              "device_key": "test",
              "title": "Hello",
              "body": "World",
              "sound": "bell",
              "badge": 1,
              "icon": "https://example.com/icon.png",
              "group": "Codex Group",
              "url": "webbridgekit://open?url=https%3A%2F%2Fexample.com",
              "copy": "copy payload",
              "isArchive": false
            }
            """)
            try await client.execute(uri: "/push", method: .post, body: body) { response in
                #expect(response.status == .ok)
                let json = try responseJSON(response.body)
                #expect(json["code"] as? Int == 200)
            }
        }
    }

    @Test("Test push endpoint reports semantic success")
    func testPushEndpointReportsSuccess() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            let body = ByteBuffer(string: """
            {
              "device_key": "test",
              "title": "Hello",
              "body": "World",
              "sound": "bell",
              "group": "Codex Group",
              "url": "webbridgekit://open?url=https%3A%2F%2Fexample.com"
            }
            """)
            try await client.execute(uri: "/test", method: .post, body: body) { response in
                #expect(response.status == .ok)
                let json = try responseJSON(response.body)
                #expect(json["success"] as? Bool == true)
                #expect(json["deviceKey"] as? String == "test")
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
                let json = try responseJSON(response.body)
                #expect(json["code"] as? Int == 200)
            }
        }
    }

    private func responseJSON(_ body: ByteBuffer) throws -> [String: Any] {
        let responseData = String(buffer: body)
        let data = Data(responseData.utf8)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
