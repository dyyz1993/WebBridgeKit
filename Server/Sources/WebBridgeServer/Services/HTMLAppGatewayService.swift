import Crypto
import Foundation
import Hummingbird

actor HTMLAppGatewayService {
    private let gatewayID: String
    private let gatewayName: String
    private let publicBaseURL: String
    private let keyID: String
    private let privateKey: Curve25519.Signing.PrivateKey?
    private let storageURL: URL
    private var manifests: [String: HTMLAppPolicyManifest]

    init(
        dataDir: String,
        gatewayID: String,
        gatewayName: String,
        publicBaseURL: String,
        keyID: String,
        privateKeyValue: String
    ) {
        self.gatewayID = gatewayID
        self.gatewayName = gatewayName
        self.publicBaseURL = publicBaseURL
        self.keyID = keyID
        if let rawKey = Self.decodeBase64URL(privateKeyValue) {
            self.privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: rawKey)
        } else {
            self.privateKey = nil
        }
        self.storageURL = URL(fileURLWithPath: dataDir, isDirectory: true)
            .appendingPathComponent("html-apps.json")
        self.manifests = Self.load(from: storageURL)
    }

    func gatewayConfiguration() throws -> HTMLAppGatewayConfigurationResponse {
        let signingKey = try requireSigningKey()
        return HTMLAppGatewayConfigurationResponse(
            id: gatewayID,
            name: gatewayName,
            baseURL: publicBaseURL,
            healthPath: "/health",
            manifestPath: "/api/v1/html-apps",
            publicKeyID: keyID,
            publicKey: Self.base64URL(signingKey.publicKey.rawRepresentation)
        )
    }

    func list() throws -> HTMLAppPolicyManifestEnvelope {
        let signed = try manifests.values
            .sorted { $0.appId < $1.appId }
            .map(sign)
        return HTMLAppPolicyManifestEnvelope(manifests: signed)
    }

    func get(appID: String) throws -> HTMLAppPolicyManifest {
        guard let manifest = manifests[appID] else {
            throw HTTPError(.notFound, message: "HTML app manifest not found: \(appID)")
        }
        return try sign(manifest)
    }

    func save(_ manifest: HTMLAppPolicyManifest) async throws -> HTMLAppPolicyManifest {
        // Zero-friction onboarding: an empty display name is auto-filled from
        // the page's own manifest.webmanifest (discovered via <link rel=manifest>).
        var candidate = manifest
        if candidate.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let fetchedName = await Self.fetchWebManifestName(startURL: candidate.startURL) {
            candidate = HTMLAppPolicyManifest(
                schemaVersion: candidate.schemaVersion,
                appId: candidate.appId,
                name: fetchedName,
                startURL: candidate.startURL,
                allowedOrigins: candidate.allowedOrigins,
                capabilities: candidate.capabilities,
                routes: candidate.routes,
                cache: candidate.cache,
                signature: nil
            )
        }
        let unsigned = candidate.unsigned()
        if let validationError = unsigned.validationError() {
            throw HTTPError(.badRequest, message: validationError)
        }
        _ = try requireSigningKey()
        let previous = manifests[unsigned.appId]
        manifests[unsigned.appId] = unsigned
        do {
            try persist()
            return try sign(unsigned)
        } catch {
            manifests[unsigned.appId] = previous
            throw error
        }
    }

    func remove(appID: String) throws {
        guard let previous = manifests.removeValue(forKey: appID) else {
            throw HTTPError(.notFound, message: "HTML app manifest not found: \(appID)")
        }
        do {
            try persist()
        } catch {
            manifests[appID] = previous
            throw error
        }
    }

    /// Fetches the page, discovers `<link rel="manifest">`, and returns the
    /// webmanifest's name/short_name. Rides the system curl like APNsService:
    /// corelibs URLSession is unreliable against arbitrary hosts on Linux.
    private static func fetchWebManifestName(startURL: String) async -> String? {
        guard let pageHTML = curlGet(url: startURL) else { return nil }
        guard let href = firstManifestLink(in: pageHTML),
              let base = URL(string: startURL),
              let manifestURL = URL(string: href, relativeTo: base)?.absoluteString else {
            return nil
        }
        guard let manifestJSON = curlGet(url: manifestURL),
              let data = manifestJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let name = object["name"] as? String, !name.isEmpty { return name }
        if let shortName = object["short_name"] as? String, !shortName.isEmpty { return shortName }
        return nil
    }

    private static func firstManifestLink(in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<link[^>]*rel=[\"']manifest[\"'][^>]*>"),
              let match = regex.firstMatch(
                  in: html, range: NSRange(html.startIndex..., in: html)
              ) else { return nil }
        let tag = String(html[Range(match.range, in: html)!])
        let hrefPattern = "href=[\"']([^\"']+)[\"']"
        guard let hrefRegex = try? NSRegularExpression(pattern: hrefPattern),
              let hrefMatch = hrefRegex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)) else {
            return nil
        }
        return String(tag[Range(hrefMatch.range(at: 1), in: tag)!])
    }

    @discardableResult
    private static func curlGet(url: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["-sL", "--max-time", "8", url]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func sign(_ manifest: HTMLAppPolicyManifest) throws -> HTMLAppPolicyManifest {
        let signingKey = try requireSigningKey()
        let unsigned = manifest.unsigned()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(unsigned)
        let signature = try signingKey.signature(for: payload)
        return HTMLAppPolicyManifest(
            schemaVersion: unsigned.schemaVersion,
            appId: unsigned.appId,
            name: unsigned.name,
            startURL: unsigned.startURL,
            allowedOrigins: unsigned.allowedOrigins,
            capabilities: unsigned.capabilities,
            routes: unsigned.routes,
            cache: unsigned.cache,
            signature: .init(
                algorithm: "ed25519",
                keyId: keyID,
                value: Self.base64URL(signature)
            )
        )
    }

    private func requireSigningKey() throws -> Curve25519.Signing.PrivateKey {
        guard !keyID.isEmpty, let privateKey else {
            throw HTTPError(.serviceUnavailable, message: "Gateway signing key is not configured")
        }
        return privateKey
    }

    private func persist() throws {
        do {
            let directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(manifests.values.sorted { $0.appId < $1.appId })
            try data.write(to: storageURL, options: .atomic)
        } catch {
            throw HTTPError(.internalServerError, message: "Unable to persist HTML app manifests")
        }
    }

    private static func load(from url: URL) -> [String: HTMLAppPolicyManifest] {
        guard let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode([HTMLAppPolicyManifest].self, from: data) else {
            return [:]
        }
        return stored.reduce(into: [:]) { result, manifest in
            let unsigned = manifest.unsigned()
            guard unsigned.validationError() == nil else { return }
            result[unsigned.appId] = unsigned
        }
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        guard !value.isEmpty else { return nil }
        var base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64)
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
