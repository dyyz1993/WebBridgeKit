import Foundation
import Hummingbird

struct HTMLAppPolicyManifest: Codable, Equatable, Sendable, ResponseEncodable {
    static let supportedSchemaVersion = "1"

    let schemaVersion: String
    let appId: String
    let name: String
    let startURL: String
    let allowedOrigins: [String]
    let capabilities: [Capability]
    let routes: [String]
    let cache: CachePolicy
    let webManifest: WebManifestBinding?
    let drelOffline: DrelOfflineDeclaration?
    let signature: Signature?

    init(
        schemaVersion: String,
        appId: String,
        name: String,
        startURL: String,
        allowedOrigins: [String],
        capabilities: [Capability],
        routes: [String],
        cache: CachePolicy,
        webManifest: WebManifestBinding? = nil,
        drelOffline: DrelOfflineDeclaration? = nil,
        signature: Signature?
    ) {
        self.schemaVersion = schemaVersion
        self.appId = appId
        self.name = name
        self.startURL = startURL
        self.allowedOrigins = allowedOrigins
        self.capabilities = capabilities
        self.routes = routes
        self.cache = cache
        self.webManifest = webManifest
        self.drelOffline = drelOffline
        self.signature = signature
    }

    enum Capability: String, Codable, Sendable {
        case bluetooth
        case camera
        case clipboard
        case fileExport
        case fileImport
        case location
        case microphone
        case notification
        case photoLibrary
        case scan
        case share
    }

    struct CachePolicy: Codable, Equatable, Sendable {
        enum Strategy: String, Codable, Sendable {
            case manifest
            case networkOnly
        }

        let strategy: Strategy
        let version: String
        let persistent: Bool
        let resourceManifestURL: String?
        let resourceManifestSHA256: String?
        let restoresLastState: Bool

        init(
            strategy: Strategy,
            version: String,
            persistent: Bool,
            resourceManifestURL: String? = nil,
            resourceManifestSHA256: String? = nil,
            restoresLastState: Bool = true
        ) {
            self.strategy = strategy
            self.version = version
            self.persistent = persistent
            self.resourceManifestURL = resourceManifestURL
            self.resourceManifestSHA256 = resourceManifestSHA256
            self.restoresLastState = restoresLastState
        }

        private enum CodingKeys: String, CodingKey {
            case strategy, version, persistent, resourceManifestURL, resourceManifestSHA256, restoresLastState
        }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            strategy = try values.decode(Strategy.self, forKey: .strategy)
            version = try values.decode(String.self, forKey: .version)
            persistent = try values.decode(Bool.self, forKey: .persistent)
            resourceManifestURL = try values.decodeIfPresent(String.self, forKey: .resourceManifestURL)
            resourceManifestSHA256 = try values.decodeIfPresent(String.self, forKey: .resourceManifestSHA256)
            restoresLastState = try values.decodeIfPresent(Bool.self, forKey: .restoresLastState) ?? true
        }
    }

    struct WebManifestBinding: Codable, Equatable, Sendable {
        let url: String
        let sha256: String
    }

    struct DrelOfflineDeclaration: Codable, Equatable, Sendable {
        let version: String
        let resourceManifestURL: String
        let resourceManifestSHA256: String

        private enum CodingKeys: String, CodingKey {
            case version
            case resourceManifestURL = "resource_manifest"
            case resourceManifestSHA256 = "resource_manifest_sha256"
        }
    }

    struct Signature: Codable, Equatable, Sendable {
        let algorithm: String
        let keyId: String
        let value: String
    }

    func unsigned() -> HTMLAppPolicyManifest {
        HTMLAppPolicyManifest(
            schemaVersion: schemaVersion,
            appId: appId,
            name: name,
            startURL: startURL,
            allowedOrigins: allowedOrigins,
            capabilities: capabilities,
            routes: routes,
            cache: cache,
            webManifest: webManifest,
            drelOffline: drelOffline,
            signature: nil
        )
    }

    func validationError() -> String? {
        guard schemaVersion == Self.supportedSchemaVersion else {
            return "Unsupported schemaVersion: \(schemaVersion)"
        }
        let appIDCharacters = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
        )
        guard !appId.isEmpty, appId.count <= 64,
              appId.unicodeScalars.allSatisfy(appIDCharacters.contains) else {
            return "Invalid appId"
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Name is required"
        }
        guard !allowedOrigins.isEmpty,
              let startOrigin = Self.origin(forDocumentURL: startURL) else {
            return "Invalid startURL or missing allowedOrigins"
        }
        let canonicalOrigins = allowedOrigins.compactMap(Self.exactOrigin)
        guard canonicalOrigins.count == allowedOrigins.count,
              Set(canonicalOrigins).count == canonicalOrigins.count,
              canonicalOrigins.contains(startOrigin) else {
            return "allowedOrigins must be unique exact origins containing startURL"
        }
        guard !routes.isEmpty, routes.allSatisfy(Self.isValidRoute) else {
            return "Invalid routes"
        }
        guard !cache.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Cache version is required"
        }
        if let resourceManifestURL = cache.resourceManifestURL {
            guard let resourceOrigin = Self.origin(forDocumentURL: resourceManifestURL),
                  canonicalOrigins.contains(resourceOrigin) else {
                return "resourceManifestURL must use an allowed origin"
            }
        }
        if let digest = cache.resourceManifestSHA256, !Self.isValidSHA256(digest) {
            return "Invalid resourceManifestSHA256"
        }
        if (cache.resourceManifestURL == nil) != (cache.resourceManifestSHA256 == nil) {
            return "resourceManifestURL and resourceManifestSHA256 must be declared together"
        }
        if let webManifest {
            guard let manifestOrigin = Self.origin(forHTTPSDocumentURL: webManifest.url),
                  canonicalOrigins.contains(manifestOrigin) else {
                return "webManifest URL must use HTTPS on an allowed origin"
            }
            guard Self.isValidSHA256(webManifest.sha256) else {
                return "Invalid webManifest SHA-256"
            }
        }
        if let drelOffline {
            guard !drelOffline.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return "drel_offline version is required"
            }
            guard let resourceOrigin = Self.origin(forHTTPSDocumentURL: drelOffline.resourceManifestURL),
                  canonicalOrigins.contains(resourceOrigin) else {
                return "drel_offline resource manifest must use HTTPS on an allowed origin"
            }
            guard Self.isValidSHA256(drelOffline.resourceManifestSHA256) else {
                return "Invalid drel_offline resource manifest SHA-256"
            }
            let cacheDeclaresResource = cache.resourceManifestURL != nil || cache.resourceManifestSHA256 != nil
            if cacheDeclaresResource,
               (cache.strategy != .manifest
                || !cache.persistent
                || cache.version != drelOffline.version
                || cache.resourceManifestURL != drelOffline.resourceManifestURL
                || cache.resourceManifestSHA256 != drelOffline.resourceManifestSHA256) {
                return "cache and drel_offline declarations must match"
            }
        }
        return nil
    }

    private static func isValidSHA256(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }

    private static func exactOrigin(_ value: String) -> String? {
        guard let components = URLComponents(string: value),
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            return nil
        }
        return canonicalOrigin(components)
    }

    private static func origin(forDocumentURL value: String) -> String? {
        guard let components = URLComponents(string: value),
              components.user == nil,
              components.password == nil else {
            return nil
        }
        return canonicalOrigin(components)
    }

    private static func origin(forHTTPSDocumentURL value: String) -> String? {
        guard let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              components.user == nil,
              components.password == nil else {
            return nil
        }
        return canonicalOrigin(components)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, appId, name, startURL, allowedOrigins, capabilities, routes, cache, webManifest
        case drelOffline = "drel_offline"
        case signature
    }

    private static func canonicalOrigin(_ components: URLComponents) -> String? {
        guard let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            return nil
        }
        let defaultPort = scheme == "https" ? 443 : 80
        let port = components.port.flatMap { $0 == defaultPort ? nil : $0 }
        return port.map { "\(scheme)://\(host):\($0)" } ?? "\(scheme)://\(host)"
    }

    private static func isValidRoute(_ route: String) -> Bool {
        guard route.hasPrefix("/"),
              !route.hasPrefix("//"),
              !route.contains("?"),
              !route.contains("#"),
              !route.contains("\\"),
              let decoded = route.removingPercentEncoding else {
            return false
        }
        guard !decoded.split(separator: "/", omittingEmptySubsequences: false).contains("..") else {
            return false
        }
        return decoded.split(separator: "/", omittingEmptySubsequences: true).allSatisfy { component in
            if component.hasPrefix(":") {
                return component.count > 1 && !component.dropFirst().contains(":")
            }
            return !component.contains(":") && !component.contains("*")
        }
    }
}

struct HTMLAppPolicyManifestEnvelope: Codable, Sendable, ResponseEncodable {
    let manifests: [HTMLAppPolicyManifest]
}

struct HTMLAppGatewayConfigurationResponse: Codable, Sendable, ResponseEncodable {
    let id: String
    let name: String
    let baseURL: String
    let healthPath: String
    let manifestPath: String
    let publicKeyID: String
    let publicKey: String
}
