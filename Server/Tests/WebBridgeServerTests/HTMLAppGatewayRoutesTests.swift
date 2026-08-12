import Crypto
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import NIOCore
import Testing

@testable import WebBridgeServer

@Suite("HTML App Gateway Routes")
struct HTMLAppGatewayRoutesTests {
    private let rawPrivateKey = Data(repeating: 7, count: 32)

    @Test("Signs manifests and persists unsigned source")
    func signsAndPersists() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = makeService(dataDir: directory.path)

        let signed = try await service.save(manifest())
        let signature = try #require(signed.signature)
        #expect(signature.algorithm == "ed25519")
        #expect(signature.keyId == "test-key")

        let gateway = try await service.gatewayConfiguration()
        let publicKeyData = try #require(decodeBase64URL(gateway.publicKey))
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        let signatureData = try #require(decodeBase64URL(signature.value))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(publicKey.isValidSignature(signatureData, for: try encoder.encode(signed.unsigned())))

        let restored = makeService(dataDir: directory.path)
        let restoredList = try await restored.list()
        #expect(restoredList.manifests.count == 1)
        #expect(restoredList.manifests.first?.appId == signed.appId)
        let restoredManifest = try #require(restoredList.manifests.first)
        let restoredSignature = try #require(restoredManifest.signature)
        let restoredSignatureData = try #require(decodeBase64URL(restoredSignature.value))
        #expect(publicKey.isValidSignature(
            restoredSignatureData,
            for: try encoder.encode(restoredManifest.unsigned())
        ))
    }

    @Test("Rejects an invalid policy manifest")
    func rejectsInvalidManifest() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = makeService(dataDir: directory.path)
        let invalid = HTMLAppPolicyManifest(
            schemaVersion: "1",
            appId: "com.example.invalid",
            name: "Invalid",
            startURL: "https://attacker.example/index.html",
            allowedOrigins: ["https://apps.example.com"],
            capabilities: [.notification],
            routes: ["/"],
            cache: .init(strategy: .manifest, version: "1", persistent: true),
            signature: nil
        )

        await #expect(throws: HTTPError.self) {
            try await service.save(invalid)
        }
    }

    @Test("Ignores invalid persisted manifests and tolerates duplicate app IDs")
    func loadsPersistedManifestsDefensively() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let replacement = HTMLAppPolicyManifest(
            schemaVersion: "1",
            appId: "com.example.chat",
            name: "Replacement Chat",
            startURL: "https://apps.example.com/replacement.html",
            allowedOrigins: ["https://apps.example.com"],
            capabilities: [.notification],
            routes: ["/replacement.html"],
            cache: .init(strategy: .manifest, version: "2", persistent: true),
            signature: nil
        )
        let invalid = HTMLAppPolicyManifest(
            schemaVersion: "1",
            appId: "com.example.invalid",
            name: "Invalid",
            startURL: "https://attacker.example/index.html",
            allowedOrigins: ["https://apps.example.com"],
            capabilities: [],
            routes: ["/"],
            cache: .init(strategy: .manifest, version: "1", persistent: true),
            signature: nil
        )
        let data = try JSONEncoder().encode([manifest(), replacement, invalid])
        try data.write(to: directory.appendingPathComponent("html-apps.json"), options: .atomic)

        let restored = try await makeService(dataDir: directory.path).list()

        #expect(restored.manifests.count == 1)
        #expect(restored.manifests.first?.appId == "com.example.chat")
        #expect(restored.manifests.first?.name == "Replacement Chat")
    }

    @Test("Public reads work and writes require the admin key")
    func routeAuthentication() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let router = Router()
        router.add(middleware: AuthMiddleware<BasicRequestContext>(apiKey: "test-admin-key"))
        let services = ServiceRegistry(
            configuration: ServerConfiguration(),
            htmlAppGatewayService: makeService(dataDir: directory.path)
        )
        HTMLAppGatewayRoutes(services: services).register(on: router)
        let app = Application(router: router)
        let encodedManifest = try JSONEncoder().encode(manifest())
        let body = ByteBuffer(string: String(decoding: encodedManifest, as: UTF8.self))

        try await app.test(.router) { client in
            try await client.execute(uri: "/api/v1/gateway", method: .get) { response in
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "/api/v1/html-apps", method: .get) { response in
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "/api/v1/html-apps", method: .post, body: body) { response in
                #expect(response.status == .unauthorized)
            }

            var headers = HTTPFields()
            headers[.authorization] = "Bearer test-admin-key"
            headers[.contentType] = "application/json"
            try await client.execute(
                uri: "/api/v1/html-apps",
                method: .post,
                headers: headers,
                body: body
            ) { response in
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "/api/v1/html-apps", method: .get) { response in
                #expect(String(buffer: response.body).contains("com.example.chat"))
            }
        }
    }

    private func makeService(dataDir: String) -> HTMLAppGatewayService {
        HTMLAppGatewayService(
            dataDir: dataDir,
            gatewayID: "test-gateway",
            gatewayName: "Test Gateway",
            publicBaseURL: "https://gateway.example.com",
            keyID: "test-key",
            privateKeyValue: base64URL(rawPrivateKey)
        )
    }

    private func manifest() -> HTMLAppPolicyManifest {
        HTMLAppPolicyManifest(
            schemaVersion: "1",
            appId: "com.example.chat",
            name: "Chat",
            startURL: "https://apps.example.com/chat/index.html",
            allowedOrigins: ["https://apps.example.com"],
            capabilities: [.notification],
            routes: ["/chat/index.html", "/chat/:id"],
            cache: .init(
                strategy: .manifest,
                version: "1",
                persistent: true,
                restoresLastState: true
            ),
            signature: nil
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("webbridgekit-gateway-tests-\(UUID().uuidString)", isDirectory: true)
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64)
    }
}
