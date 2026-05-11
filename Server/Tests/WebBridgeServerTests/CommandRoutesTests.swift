import Foundation
import Hummingbird
import HummingbirdTesting
import Testing
import NIOCore

@testable import WebBridgeServer

@Suite("Command Routes")
struct CommandRoutesTests {
    private func createApplication() -> Application<RouterResponder<BasicRequestContext>> {
        let router = Router()
        let config = ServerConfiguration()
        let services = ServiceRegistry(configuration: config)
        CommandRoutes(services: services).register(on: router)
        return Application(router: router)
    }

    @Test("Generate command token")
    func generateCommand() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            let body = ByteBuffer(string: """
            {"type": "urlScheme", "data": "webbridgekit://action/test"}
            """)
            try await client.execute(uri: "/api/v1/commands", method: .post, body: body) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("Generate and resolve command")
    func generateAndResolve() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            let body = ByteBuffer(string: """
            {"type": "plainText", "data": "hello world"}
            """)
            var generatedId: String?

            try await client.execute(uri: "/api/v1/commands", method: .post, body: body) { response in
                #expect(response.status == .ok)
                let responseData = String(buffer: response.body)
                if let data = responseData.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let id = json["id"] as? String {
                    generatedId = id
                }
            }

            guard let id = generatedId else {
                Issue.record("Failed to extract command ID from response")
                return
            }

            try await client.execute(uri: "/api/v1/commands/\(id)", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("Resolve non-existent command returns 404")
    func resolveNonExistent() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            try await client.execute(uri: "/api/v1/commands/nonexistent", method: .get) { response in
                #expect(response.status == .notFound)
            }
        }
    }

    @Test("Generate with custom format")
    func generateWithFormat() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            let body = ByteBuffer(string: """
            {"type": "base64", "data": "SGVsbG8gV29ybGQ=", "format": "base64"}
            """)
            try await client.execute(uri: "/api/v1/commands", method: .post, body: body) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("Share a command token")
    func testShareCommand() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            let body = ByteBuffer(string: """
            {"type": "plainText", "data": "shared content"}
            """)
            var generatedId: String?
            var generatedToken: String?

            try await client.execute(uri: "/api/v1/commands", method: .post, body: body) { response in
                #expect(response.status == .ok)
                let responseData = String(buffer: response.body)
                if let data = responseData.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let id = json["id"] as? String,
                   let token = json["token"] as? String {
                    generatedId = id
                    generatedToken = token
                }
            }

            guard let id = generatedId, let token = generatedToken else {
                Issue.record("Failed to extract command ID/token from response")
                return
            }

            // First share
            try await client.execute(uri: "/api/v1/commands/\(id)/share", method: .post) { response in
                #expect(response.status == .ok)
                let responseData = String(buffer: response.body)
                if let data = responseData.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    #expect(json["shareCount"] as? Int == 1)
                    #expect((json["shareURL"] as? String)?.isEmpty == false)
                    if let shareText = json["shareText"] as? String {
                        #expect(shareText.contains("webbridgekit://command/"))
                    }
                }
            }

            // Second share
            try await client.execute(uri: "/api/v1/commands/\(id)/share", method: .post) { response in
                #expect(response.status == .ok)
                let responseData = String(buffer: response.body)
                if let data = responseData.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    #expect(json["shareCount"] as? Int == 2)
                }
            }

            // Verify token format
            #expect(token.contains("."))
        }
    }
}
