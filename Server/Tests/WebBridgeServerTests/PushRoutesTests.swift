import Foundation
import Hummingbird
import HummingbirdTesting
import Testing
import NIOCore
import Crypto

@testable import WebBridgeServer

@Suite("Push Routes")
struct PushRoutesTests {
    @Test("APNs JWT contains the team and key identifiers and verifies with ES256")
    func apnsJWTIsSigned() throws {
        let privateKey = P256.Signing.PrivateKey()
        let signer = try APNsJWTSigner(
            keyID: "KEY1234567",
            teamID: "TEAM123456",
            pemRepresentation: privateKey.pemRepresentation
        )

        let token = try signer.token(at: Date(timeIntervalSince1970: 1_700_000_000))
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        #expect(parts.count == 3)

        let header = try #require(Self.decodeBase64URL(String(parts[0])))
        let claims = try #require(Self.decodeBase64URL(String(parts[1])))
        let signatureData = try #require(Self.decodeBase64URL(String(parts[2])))
        let headerJSON = try #require(JSONSerialization.jsonObject(with: header) as? [String: String])
        let claimsJSON = try #require(JSONSerialization.jsonObject(with: claims) as? [String: Any])
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: signatureData)

        #expect(headerJSON["alg"] == "ES256")
        #expect(headerJSON["kid"] == "KEY1234567")
        #expect(claimsJSON["iss"] as? String == "TEAM123456")
        #expect(claimsJSON["iat"] as? Int == 1_700_000_000)
        #expect(privateKey.publicKey.isValidSignature(signature, for: Data("\(parts[0]).\(parts[1])".utf8)))
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64)
    }

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

    @Test("device registration returns a controlled server error when persistence fails")
    func registrationPersistenceFailureIsControlled() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("webbridgekit-register-failure-\(UUID().uuidString)")
        try Data("parent-is-a-file".utf8).write(to: directory)
        let tokenStore = TokenStore(fileURL: directory.appendingPathComponent("registrations.json"))
        let config = ServerConfiguration()
        let services = ServiceRegistry(configuration: config, tokenStore: tokenStore)
        let router = Router()
        PushRoutes.register(on: router, services: services)
        let app = Application(router: router)

        try await app.test(.router) { client in
            let body = ByteBuffer(string: #"{"deviceToken":"token-a","key":"key-a"}"#)
            try await client.execute(uri: "/register", method: .post, body: body) { response in
                #expect(response.status == .internalServerError)
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

    @Test("Push v2 fields survive APNs payload construction")
    func pushV2FieldsSurviveAPNsPayloadConstruction() throws {
        let payload = PushPayload(
            schema: "webbridgekit.message.v1",
            type: "approval",
            title: "Production release",
            body: "Review the deployment",
            subtitle: "Agent Console",
            category: "approval",
            markdown: "## Deployment",
            sound: "default",
            badge: 2,
            icon: "https://example.com/icon.png",
            image: "https://example.com/image.png",
            group: "agent-approvals",
            threadID: "approval-thread",
            url: "https://example.com/approvals/42",
            copy: "approval-42",
            isArchive: true,
            level: "timeSensitive",
            volume: 7,
            isCall: false,
            autoCopy: false,
            appID: "agent-console",
            route: "/approvals/approval-42",
            mode: "modal",
            display: "sheet",
            verificationCode: "482901",
            expiresAt: "2026-08-12T21:30:00Z",
            ttl: 300,
            replacementID: "approval-42",
            isDeleted: false,
            actionState: "pending",
            requestID: "approval-42",
            contentType: "approval",
            qrPayload: "webbridgekit://login/42",
            statePath: "/api/approvals/approval-42",
            revision: 17,
            params: ["requestId": "approval-42"]
        )

        let apns = APNsService.makeAPNsPayload(payload)
        let aps = try #require(apns["aps"] as? [String: Any])
        let alert = try #require(aps["alert"] as? [String: Any])

        #expect(alert["title"] as? String == "Production release")
        #expect(alert["subtitle"] as? String == "Agent Console")
        #expect(aps["thread-id"] as? String == "approval-thread")
        #expect(aps["interruption-level"] as? String == "time-sensitive")
        #expect(apns["category"] as? String == "approval")
        #expect(apns["appId"] as? String == "agent-console")
        #expect(apns["route"] as? String == "/approvals/approval-42")
        #expect(apns["display"] as? String == "sheet")
        #expect(apns["actionState"] as? String == "pending")
        #expect(apns["state"] as? String == "pending")
        #expect(apns["verificationCode"] as? String == "482901")
        #expect(apns["qrPayload"] as? String == "webbridgekit://login/42")
        #expect(apns["params"] as? [String: String] == ["requestId": "approval-42"])

        let resolved = payload.updatingApprovalState(.approved, revision: 18)
        #expect(resolved.group == payload.group)
        #expect(resolved.approval == payload.approval)
        #expect(resolved.actionState == "approved")
        #expect(resolved.revision == 18)
    }

    @Test("Critical level promotes aps.sound to the dictionary form with scaled volume")
    func criticalLevelBuildsDictionarySound() throws {
        let critical = PushPayload(
            title: "Critical",
            body: "Something happened",
            sound: "alarm",
            level: "critical",
            volume: 5
        )
        let apns = APNsService.makeAPNsPayload(critical)
        let aps = try #require(apns["aps"] as? [String: Any])
        let sound = try #require(aps["sound"] as? [String: Any])
        #expect(sound["critical"] as? Int == 1)
        #expect(sound["name"] as? String == "alarm")
        #expect(sound["volume"] as? Double == 0.5)
    }

    @Test("Critical dictionary sound defaults and clamps Bark volume")
    func criticalDictionarySoundDefaultsAndClampsVolume() throws {
        let noVolume = APNsService.makeAPNsPayload(PushPayload(
            title: "Critical", body: "No volume", level: "critical"
        ))
        let noVolumeAps = try #require(noVolume["aps"] as? [String: Any])
        let defaultSound = try #require(noVolumeAps["sound"] as? [String: Any])
        #expect(defaultSound["name"] as? String == "default")
        #expect(defaultSound["volume"] as? Double == 0.5)

        let loud = APNsService.makeAPNsPayload(PushPayload(
            title: "Critical", body: "Too loud", level: "critical", volume: 15
        ))
        let loudAps = try #require(loud["aps"] as? [String: Any])
        let loudSound = try #require(loudAps["sound"] as? [String: Any])
        #expect(loudSound["volume"] as? Double == 1.0)
    }

    @Test("Non-critical levels keep the plain string sound")
    func nonCriticalLevelsKeepStringSound() throws {
        let active = APNsService.makeAPNsPayload(PushPayload(
            title: "Hello", body: "World", sound: "bell", level: "timeSensitive", volume: 8
        ))
        let aps = try #require(active["aps"] as? [String: Any])
        #expect(aps["sound"] as? String == "bell")

        let unspecified = APNsService.makeAPNsPayload(PushPayload(title: "Hello", body: "World"))
        let unspecifiedAps = try #require(unspecified["aps"] as? [String: Any])
        #expect(unspecifiedAps["sound"] as? String == "default")
    }

    @Test("Bark POST accepts empty body when title or action fields are present")
    func barkPostAcceptsBodylessActionPushes() async throws {
        let app = createApplication()
        try await app.test(.router) { client in
            // push-render-catalog 清角标/撤回 cards carry no body but do
            // carry a title or action fields — they must not be rejected.
            let payloads = [
                #"{"title":"清角标","body":"","badge":0}"#,
                #"{"id":"demo-replace-1","title":"撤回","body":"","delete":true}"#,
                #"{"title":"只有标题"}"#
            ]
            for payload in payloads {
                try await client.execute(
                    uri: "/test_resources",
                    method: .post,
                    headers: [.contentType: "application/json"],
                    body: ByteBuffer(string: payload)
                ) { response in
                    #expect(response.status == .ok)
                }
            }

            // No title, no body, no action — still rejected.
            try await client.execute(
                uri: "/test_resources",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: "{}")
            ) { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test("Passive level omits the aps sound key entirely")
    func passiveLevelOmitsSound() throws {
        let passive = APNsService.makeAPNsPayload(PushPayload(
            title: "被动通知", body: "不打扰", level: "passive"
        ))
        let aps = try #require(passive["aps"] as? [String: Any])
        #expect(aps["sound"] == nil)
        #expect(aps["interruption-level"] as? String == "passive")

        // Even an explicit sound must be suppressed for passive delivery —
        // iOS honors a present sound key over the passive interruption level.
        let explicit = APNsService.makeAPNsPayload(PushPayload(
            title: "被动通知", body: "不打扰", sound: "alarm", level: "passive"
        ))
        let explicitAps = try #require(explicit["aps"] as? [String: Any])
        #expect(explicitAps["sound"] == nil)

        // Non-passive levels keep the default-sound fallback.
        let active = APNsService.makeAPNsPayload(PushPayload(
            title: "普通", body: "内容", level: "active"
        ))
        let activeAps = try #require(active["aps"] as? [String: Any])
        #expect(activeAps["sound"] as? String == "default")
    }

    @Test("JSON Push v2 request maps canonical and Bark-compatible aliases")
    func jsonPushV2RequestMapsAliases() throws {
        let data = Data("""
        {
          "device_key": "test",
          "title": "Approval",
          "body": "Review it",
          "appid": "agent-console",
          "route": "/approvals/42",
          "display": "sheet",
          "category": "approval",
          "actionState": "pending",
          "requestId": "approval-42",
          "contentType": "approval",
          "params": {"requestId": "approval-42"}
        }
        """.utf8)

        let request = try JSONDecoder().decode(JSONPushRequest.self, from: data)
        let payload = request.payload

        #expect(request.deviceKey == "test")
        #expect(payload.appID == "agent-console")
        #expect(payload.route == "/approvals/42")
        #expect(payload.display == "sheet")
        #expect(payload.actionState == "pending")
        #expect(payload.requestID == "approval-42")
        #expect(payload.params == ["requestId": "approval-42"])
    }

    @Test("Canonical message types require their rendering fields")
    func canonicalMessageTypesValidateRenderingFields() async throws {
        let app = createApplication()
        let validPayloads = [
            #"{"schema":"webbridgekit.message.v1","type":"plain","deviceKey":"test","title":"Plain","body":"Readable body"}"#,
            "{\"schema\":\"webbridgekit.message.v1\",\"type\":\"markdown\",\"deviceKey\":\"test\",\"title\":\"Markdown\",\"body\":\"Summary\",\"markdown\":\"## Result\"}",
            #"{"schema":"webbridgekit.message.v1","type":"image","deviceKey":"test","title":"Image","body":"Preview","image":"https://example.com/preview.png"}"#,
            #"{"schema":"webbridgekit.message.v1","type":"qr","deviceKey":"test","title":"QR","body":"Scan","qrPayload":"webbridgekit://login/42"}"#,
            #"{"schema":"webbridgekit.message.v1","type":"otp","deviceKey":"test","title":"OTP","body":"Use code","verificationCode":"482901"}"#,
            #"{"schema":"webbridgekit.message.v1","type":"chat","deviceKey":"test","title":"Chat","body":"New reply","appId":"team-chat","route":"/conversations/42","params":{"conversationId":"42"}}"#,
        ]

        try await app.test(.router) { client in
            for payload in validPayloads {
                try await client.execute(uri: "/push", method: .post, body: ByteBuffer(string: payload)) { response in
                    #expect(response.status == .ok)
                }
            }

            let invalidPayloads = [
                #"{"schema":"webbridgekit.message.v1","type":"markdown","deviceKey":"test","title":"Markdown","body":"Missing markdown"}"#,
                #"{"schema":"webbridgekit.message.v1","type":"image","deviceKey":"test","title":"Image","body":"Missing image"}"#,
                #"{"schema":"webbridgekit.message.v1","type":"qr","deviceKey":"test","title":"QR","body":"Missing payload"}"#,
                #"{"schema":"webbridgekit.message.v1","type":"otp","deviceKey":"test","title":"OTP","body":"Missing code"}"#,
                #"{"schema":"webbridgekit.message.v1","type":"chat","deviceKey":"test","title":"Chat","body":"Missing route"}"#,
            ]
            for payload in invalidPayloads {
                try await client.execute(uri: "/push", method: .post, body: ByteBuffer(string: payload)) { response in
                    #expect(response.status == .badRequest)
                }
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
