import Foundation
import Hummingbird
import HummingbirdTesting
import HTTPTypes
import NIOCore
import Testing

@testable import WebBridgeServer

@Suite("Approval v1 Routes", .serialized)
struct ApprovalRoutesTests {
    @Test("Native approval can be created and polled without exposing callback URL")
    func createAndPoll() async throws {
        let fixture = try makeFixture()
        try await fixture.app.test(.router) { client in
            let createBody = ByteBuffer(string: nativeApprovalJSON(responseMode: "webhook"))
            try await client.execute(uri: "/push", method: .post, body: createBody) { response in
                #expect(response.status == .ok)
            }

            try await client.execute(
                uri: "/api/v1/approvals/approval-42",
                method: .get,
                headers: authorization("test")
            ) { response in
                #expect(response.status == .ok)
                let json = try responseJSON(response.body)
                #expect(json["schema"] as? String == "webbridgekit.approval-status.v1")
                #expect(json["state"] as? String == "pending")
                #expect(json["revision"] as? Int == 1)
                #expect(json["responseURL"] == nil)
            }
        }
    }

    @Test("First valid response wins and increments revision")
    func firstResponseWins() async throws {
        let fixture = try makeFixture()
        try await fixture.app.test(.router) { client in
            try await client.execute(
                uri: "/push",
                method: .post,
                body: ByteBuffer(string: nativeApprovalJSON(responseMode: "poll"))
            ) { response in
                #expect(response.status == .ok)
            }

            let approve = ByteBuffer(string: """
            {"actionId":"approve","expectedRevision":1,"values":{}}
            """)
            try await client.execute(
                uri: "/api/v1/approvals/approval-42/respond",
                method: .post,
                headers: authorization("test"),
                body: approve
            ) { response in
                #expect(response.status == .ok)
                let json = try responseJSON(response.body)
                #expect(json["state"] as? String == "approved")
                #expect(json["revision"] as? Int == 2)
                #expect(json["actionId"] as? String == "approve")
            }

            let reject = ByteBuffer(string: """
            {"actionId":"reject","expectedRevision":2,"values":{"reason":"late"}}
            """)
            try await client.execute(
                uri: "/api/v1/approvals/approval-42/respond",
                method: .post,
                headers: authorization("test"),
                body: reject
            ) { response in
                #expect(response.status == .conflict)
            }
        }
    }

    @Test("Reject action requires a reason")
    func reasonIsRequired() async throws {
        let fixture = try makeFixture()
        try await fixture.app.test(.router) { client in
            try await client.execute(
                uri: "/push",
                method: .post,
                body: ByteBuffer(string: nativeApprovalJSON(responseMode: "poll"))
            ) { response in
                #expect(response.status == .ok)
            }
            let body = ByteBuffer(string: """
            {"actionId":"reject","expectedRevision":1,"values":{}}
            """)
            try await client.execute(
                uri: "/api/v1/approvals/approval-42/respond",
                method: .post,
                headers: authorization("test"),
                body: body
            ) { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test("Web and PWA approvals require explicit safe routing fields")
    func routedApprovalContracts() async throws {
        let fixture = try makeFixture()
        try await fixture.app.test(.router) { client in
            let web = ByteBuffer(string: """
            {
              "schema":"webbridgekit.message.v1","type":"approval","deviceKey":"test",
              "id":"approval-web-1","requestId":"approval-web-1","revision":1,"state":"pending",
              "title":"Review","body":"Open web flow","presentation":"web",
              "url":"https://example.com/approvals/1","display":"sheet"
            }
            """)
            try await client.execute(uri: "/push", method: .post, body: web) { response in
                #expect(response.status == .ok)
            }

            let pwa = ByteBuffer(string: """
            {
              "schema":"webbridgekit.message.v1","type":"approval","deviceKey":"test",
              "id":"approval-pwa-1","requestId":"approval-pwa-1","revision":1,"state":"pending",
              "title":"Review","body":"Open PWA flow","presentation":"pwa",
              "appId":"com.example.approvals","route":"/requests/1","params":{"requestId":"approval-pwa-1"}
            }
            """)
            try await client.execute(uri: "/push", method: .post, body: pwa) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("Malformed Approval v1 payloads do not degrade into plain notifications")
    func malformedApprovalIsRejected() async throws {
        let fixture = try makeFixture()
        try await fixture.app.test(.router) { client in
            let missingActions = ByteBuffer(string: """
            {
              "schema":"webbridgekit.message.v1","type":"approval","deviceKey":"test",
              "id":"approval-invalid-1","requestId":"approval-invalid-1","revision":1,"state":"pending",
              "title":"Review","body":"Missing actions","presentation":"native"
            }
            """)
            try await client.execute(uri: "/push", method: .post, body: missingActions) { response in
                #expect(response.status == .badRequest)
            }

            let rawHTML = ByteBuffer(string: """
            {
              "schema":"webbridgekit.message.v1","type":"plain","deviceKey":"test",
              "title":"Unsafe","body":"Raw HTML","html":"<button>Approve</button>"
            }
            """)
            try await client.execute(uri: "/push", method: .post, body: rawHTML) { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    private func makeFixture() throws -> (app: Application<RouterResponder<BasicRequestContext>>, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("wbk-approval-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let router = Router()
        let config = ServerConfiguration()
        let store = ApprovalStore(fileURL: directory.appendingPathComponent("approvals.json"))
        let services = ServiceRegistry(configuration: config, approvalStore: store)
        PushRoutes.register(on: router, services: services)
        ApprovalRoutes(services: services).register(on: router)
        return (Application(router: router), directory)
    }

    private func nativeApprovalJSON(responseMode: String) -> String {
        let responseURL = responseMode == "webhook"
            ? ",\"responseURL\":\"https://example.com/webhooks/webbridgekit\""
            : ""
        return """
        {
          "schema":"webbridgekit.message.v1",
          "type":"approval",
          "deviceKey":"test",
          "id":"approval-42",
          "requestId":"approval-42",
          "revision":1,
          "state":"pending",
          "title":"Release?",
          "body":"Version 2.4.0",
          "presentation":"native",
          "approval":{
            "actions":[
              {"id":"approve","title":"Approve","style":"primary","resultState":"approved"},
              {"id":"reject","title":"Reject","style":"destructive","requiresReason":true,"resultState":"rejected"}
            ],
            "responseMode":"\(responseMode)"\(responseURL)
          }
        }
        """
    }

    private func authorization(_ key: String) -> HTTPFields {
        var headers = HTTPFields()
        headers[.authorization] = "Bearer \(key)"
        headers[.contentType] = "application/json"
        return headers
    }

    private func responseJSON(_ body: ByteBuffer) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: Data(String(buffer: body).utf8)) as? [String: Any]
        )
    }
}
