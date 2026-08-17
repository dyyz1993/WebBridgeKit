//
//  HTMLAppGatewayConfiguration.swift
//  WebBridgeKit
//
//  Portable, user-controlled configuration for compatible HTML app gateways.
//

import Foundation

/// First-party gateway metadata bundled with the official app. This is public
/// trust material, not user-imported configuration and contains no credentials.
public enum HTMLAppGatewayDefaults {
    /// Self-hosted production gateway on shanbox. The original tx gateway
    /// (cloak.xbrowser.dev:5801) is retired; this gateway serves the same
    /// contract and is verified to be reachable from China.
    public static let official = HTMLAppGatewayConfiguration(
        id: "webbridgekit-gateway",
        name: "WebBridgeKit 官方服务",
        baseURL: "https://wbk.shanbox.19930810.xyz:8443",
        healthPath: "/health",
        manifestPath: "/api/v1/html-apps",
        publicKeyID: "wbk-self-hosted-20260816",
        publicKey: "h860-f-Vu_IC9DNoOrGrMpnXydSZHjNqb2HprCJIcm8"
    )
}

public struct HTMLAppGatewayConfiguration: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let baseURL: String
    public let healthPath: String
    public let manifestPath: String
    public let publicKeyID: String?
    public let publicKey: String?

    public init(
        id: String = UUID().uuidString.lowercased(),
        name: String,
        baseURL: String,
        healthPath: String = "/health",
        manifestPath: String = "/manifest",
        publicKeyID: String? = nil,
        publicKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.healthPath = healthPath
        self.manifestPath = manifestPath
        self.publicKeyID = publicKeyID
        self.publicKey = publicKey
    }

    public var manifestURL: URL? {
        guard let baseURL = URL(string: baseURL) else { return nil }
        return URL(string: manifestPath, relativeTo: baseURL)?.absoluteURL
    }

    public var healthURL: URL? {
        guard let baseURL = URL(string: baseURL) else { return nil }
        return URL(string: healthPath, relativeTo: baseURL)?.absoluteURL
    }

    public func validate(allowsDevelopmentHTTP: Bool = false) -> HTMLAppGatewayConfigurationValidationResult {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid(.missingName)
        }
        guard let url = URL(string: baseURL),
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil,
              url.path.isEmpty || url.path == "/",
              let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased(),
              !host.isEmpty else {
            return .invalid(.invalidBaseURL)
        }
        if scheme != "https" {
            let isLocalHost = host == "localhost" || host == "127.0.0.1" || host == "::1"
            guard allowsDevelopmentHTTP && scheme == "http" && isLocalHost else {
                return .invalid(.insecureBaseURL)
            }
        }
        guard Self.isValidEndpointPath(healthPath, relativeTo: url),
              Self.isValidEndpointPath(manifestPath, relativeTo: url) else {
            return .invalid(.invalidManifestPath)
        }
        if (publicKeyID == nil) != (publicKey == nil) {
            return .invalid(.incompleteTrustAnchor)
        }
        if let publicKey, Self.decodeBase64URL(publicKey)?.count != 32 {
            return .invalid(.invalidPublicKey)
        }
        return .valid
    }

    public static func importPayload(
        _ payload: String,
        allowsDevelopmentHTTP: Bool = false
    ) throws -> HTMLAppGatewayConfiguration {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HTMLAppGatewayConfigurationImportError.emptyPayload }

        if trimmed.first == "{" {
            guard let data = trimmed.data(using: .utf8) else {
                throw HTMLAppGatewayConfigurationImportError.unsupportedPayload
            }
            return try importJSON(data, allowsDevelopmentHTTP: allowsDevelopmentHTTP)
        }

        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "webbridgekit",
              components.host?.lowercased() == "gateway" else {
            throw HTMLAppGatewayConfigurationImportError.unsupportedPayload
        }
        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard values[item.name] == nil else {
                throw HTMLAppGatewayConfigurationImportError.duplicateField(item.name)
            }
            values[item.name] = item.value ?? ""
        }
        try rejectSecretFields(in: values)
        let canonical = values["schemaVersion"] != nil || values["displayName"] != nil || values["baseURL"] != nil
        if let version = values["schemaVersion"], version != "1" {
            throw HTMLAppGatewayConfigurationImportError.unsupportedSchemaVersion(version)
        }
        let baseURL = try requiredValue(canonical ? "baseURL" : "url", in: values)
        let name = try requiredValue(canonical ? "displayName" : "name", in: values)
        if canonical {
            for field in ["healthEndpoint", "manifestEndpoint", "publicKeyId", "publicKey"] {
                _ = try requiredValue(field, in: values)
            }
        }
        let configuration = HTMLAppGatewayConfiguration(
            id: values["id"]?.isEmpty == false ? values["id"]! : UUID().uuidString.lowercased(),
            name: name,
            baseURL: baseURL,
            healthPath: values[canonical ? "healthEndpoint" : "healthPath"]?.isEmpty == false
                ? values[canonical ? "healthEndpoint" : "healthPath"]! : "/health",
            manifestPath: values[canonical ? "manifestEndpoint" : "manifestPath"]?.isEmpty == false
                ? values[canonical ? "manifestEndpoint" : "manifestPath"]! : "/manifest",
            publicKeyID: values[canonical ? "publicKeyId" : "keyId"]?.isEmpty == false
                ? values[canonical ? "publicKeyId" : "keyId"] : nil,
            publicKey: values["publicKey"]?.isEmpty == false ? values["publicKey"] : nil
        )
        return try validateImported(configuration, allowsDevelopmentHTTP: allowsDevelopmentHTTP)
    }

    private static func importJSON(
        _ data: Data,
        allowsDevelopmentHTTP: Bool
    ) throws -> HTMLAppGatewayConfiguration {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let values = object as? [String: Any] else {
            throw HTMLAppGatewayConfigurationImportError.unsupportedPayload
        }
        try rejectSecretFields(in: values)
        let canonical = values["schemaVersion"] != nil || values["displayName"] != nil || values["healthEndpoint"] != nil
        if let rawVersion = values["schemaVersion"] {
            guard let version = rawVersion as? String else {
                throw HTMLAppGatewayConfigurationImportError.invalidField("schemaVersion")
            }
            guard version == "1" else {
                throw HTMLAppGatewayConfigurationImportError.unsupportedSchemaVersion(version)
            }
        }

        func string(_ key: String) throws -> String? {
            guard let value = values[key] else { return nil }
            guard let string = value as? String else {
                throw HTMLAppGatewayConfigurationImportError.invalidField(key)
            }
            return string
        }
        func required(_ key: String) throws -> String {
            guard let value = try string(key), !value.isEmpty else {
                throw HTMLAppGatewayConfigurationImportError.missingRequiredField(key)
            }
            return value
        }

        let name = try required(canonical ? "displayName" : "name")
        let baseURL = try required("baseURL")
        if canonical {
            for field in ["healthEndpoint", "manifestEndpoint", "publicKeyId", "publicKey"] {
                _ = try required(field)
            }
        }
        let configuration = HTMLAppGatewayConfiguration(
            id: try string("id") ?? UUID().uuidString.lowercased(),
            name: name,
            baseURL: baseURL,
            healthPath: try string(canonical ? "healthEndpoint" : "healthPath") ?? "/health",
            manifestPath: try string(canonical ? "manifestEndpoint" : "manifestPath") ?? "/manifest",
            publicKeyID: try string(canonical ? "publicKeyId" : "publicKeyID"),
            publicKey: try string("publicKey")
        )
        return try validateImported(configuration, allowsDevelopmentHTTP: allowsDevelopmentHTTP)
    }

    private static func rejectSecretFields<S: Sequence>(_ keys: S) throws where S.Element == String {
        let forbidden = ["privatekey", "apisecret", "token", "password", "admintoken", "clientsecret"]
        if let key = keys.first(where: { forbidden.contains($0.lowercased()) }) {
            throw HTMLAppGatewayConfigurationImportError.forbiddenSecretField(key)
        }
    }

    private static func rejectSecretFields(in value: Any) throws {
        if let dictionary = value as? [String: Any] {
            try rejectSecretFields(dictionary.keys)
            for nestedValue in dictionary.values { try rejectSecretFields(in: nestedValue) }
        } else if let array = value as? [Any] {
            for nestedValue in array { try rejectSecretFields(in: nestedValue) }
        }
    }

    private static func requiredValue(_ key: String, in values: [String: String]) throws -> String {
        guard let value = values[key], !value.isEmpty else {
            throw HTMLAppGatewayConfigurationImportError.missingRequiredField(key)
        }
        return value
    }

    private static func decodeBase64URL(_ string: String) -> Data? {
        var base64 = string.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: padding)
        return Data(base64Encoded: base64)
    }

    private static func validateImported(
        _ configuration: HTMLAppGatewayConfiguration,
        allowsDevelopmentHTTP: Bool
    ) throws -> HTMLAppGatewayConfiguration {
        guard configuration.validate(allowsDevelopmentHTTP: allowsDevelopmentHTTP).isValid else {
            throw HTMLAppGatewayConfigurationImportError.invalidConfiguration
        }
        return configuration
    }

    private static func isValidEndpointPath(_ path: String, relativeTo baseURL: URL) -> Bool {
        guard path.hasPrefix("/"), !path.hasPrefix("//"), !path.contains("\\"),
              let components = URLComponents(string: path),
              components.scheme == nil,
              components.host == nil,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              let decodedPath = components.percentEncodedPath.removingPercentEncoding,
              !decodedPath.contains("\\"),
              !decodedPath.split(separator: "/", omittingEmptySubsequences: false).contains(".."),
              let endpointURL = components.url(relativeTo: baseURL)?.absoluteURL,
              endpointURL.scheme?.lowercased() == baseURL.scheme?.lowercased(),
              endpointURL.host?.lowercased() == baseURL.host?.lowercased(),
              endpointURL.port == baseURL.port else {
            return false
        }
        return true
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, baseURL, healthPath, manifestPath, publicKeyID, publicKey
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString.lowercased()
        name = try values.decode(String.self, forKey: .name)
        baseURL = try values.decode(String.self, forKey: .baseURL)
        healthPath = try values.decodeIfPresent(String.self, forKey: .healthPath) ?? "/health"
        manifestPath = try values.decodeIfPresent(String.self, forKey: .manifestPath) ?? "/manifest"
        publicKeyID = try values.decodeIfPresent(String.self, forKey: .publicKeyID)
        publicKey = try values.decodeIfPresent(String.self, forKey: .publicKey)
    }
}

public enum HTMLAppGatewayConfigurationValidationResult: Equatable {
    case valid
    case invalid(HTMLAppGatewayConfigurationError)

    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

public enum HTMLAppGatewayConfigurationError: Error, Equatable, LocalizedError {
    case missingName
    case invalidBaseURL
    case insecureBaseURL
    case invalidManifestPath
    case incompleteTrustAnchor
    case invalidPublicKey

    public var errorDescription: String? {
        switch self {
        case .missingName: return "Gateway name is required"
        case .invalidBaseURL: return "Gateway base URL must be an exact HTTP(S) origin"
        case .insecureBaseURL: return "Gateway requires HTTPS outside development"
        case .invalidManifestPath: return "Gateway manifest path is invalid"
        case .incompleteTrustAnchor: return "Gateway keyId and publicKey must be provided together"
        case .invalidPublicKey: return "Gateway publicKey must be a 32-byte Ed25519 public key"
        }
    }
}

public enum HTMLAppGatewayConfigurationImportError: Error, Equatable, LocalizedError {
    case emptyPayload
    case unsupportedPayload
    case missingRequiredField(String)
    case invalidField(String)
    case duplicateField(String)
    case forbiddenSecretField(String)
    case unsupportedSchemaVersion(String)
    case invalidConfiguration

    public var errorDescription: String? {
        switch self {
        case .emptyPayload: return "Gateway configuration payload is empty"
        case .unsupportedPayload: return "Gateway configuration must be JSON or a webbridgekit gateway URL"
        case .missingRequiredField(let field): return "Gateway configuration is missing required field: \(field)"
        case .invalidField(let field): return "Gateway configuration field has an invalid type: \(field)"
        case .duplicateField(let field): return "Gateway configuration repeats field: \(field)"
        case .forbiddenSecretField(let field): return "Gateway configuration must not contain secret field: \(field)"
        case .unsupportedSchemaVersion(let version): return "Unsupported gateway schema version: \(version)"
        case .invalidConfiguration: return "Gateway configuration is invalid"
        }
    }
}

public final class HTMLAppGatewayRegistry {
    private struct State: Codable {
        var configurations: [String: HTMLAppGatewayConfiguration]
        var activeGatewayID: String?
    }

    private let storage: HTMLAppRuntimeStorage
    private let storageKey: String
    private let allowsDevelopmentHTTP: Bool
    private let lock = NSLock()
    private var state: State

    public init(
        storage: HTMLAppRuntimeStorage = HTMLAppUserDefaultsStorage(),
        storageKey: String = "com.webbridgekit.html-app-runtime.gateways",
        allowsDevelopmentHTTP: Bool = false
    ) {
        self.storage = storage
        self.storageKey = storageKey
        self.allowsDevelopmentHTTP = allowsDevelopmentHTTP
        state = Self.load(storage: storage, key: storageKey)
    }

    @discardableResult
    public func importAndActivate(payload: String) throws -> HTMLAppGatewayConfiguration {
        let configuration = try HTMLAppGatewayConfiguration.importPayload(
            payload,
            allowsDevelopmentHTTP: allowsDevelopmentHTTP
        )
        try save(configuration, activate: true)
        return configuration
    }

    public func save(_ configuration: HTMLAppGatewayConfiguration, activate: Bool = false) throws {
        guard configuration.validate(allowsDevelopmentHTTP: allowsDevelopmentHTTP).isValid else {
            throw HTMLAppGatewayConfigurationImportError.invalidConfiguration
        }
        lock.lock()
        defer { lock.unlock() }
        var proposed = state
        proposed.configurations[configuration.id] = configuration
        if activate { proposed.activeGatewayID = configuration.id }
        try persistLocked(proposed)
        state = proposed
    }

    public func activeGateway() -> HTMLAppGatewayConfiguration? {
        lock.lock()
        defer { lock.unlock() }
        guard let id = state.activeGatewayID else { return nil }
        return state.configurations[id]
    }

    public func allGateways() -> [HTMLAppGatewayConfiguration] {
        lock.lock()
        defer { lock.unlock() }
        return state.configurations.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func activate(id: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard state.configurations[id] != nil else { return }
        var proposed = state
        proposed.activeGatewayID = id
        try persistLocked(proposed)
        state = proposed
    }

    public func remove(id: String) throws {
        lock.lock()
        defer { lock.unlock() }
        var proposed = state
        proposed.configurations.removeValue(forKey: id)
        if proposed.activeGatewayID == id { proposed.activeGatewayID = nil }
        try persistLocked(proposed)
        state = proposed
    }

    private func persistLocked(_ proposed: State) throws {
        do {
            let data = try JSONEncoder().encode(proposed)
            if let throwingStorage = storage as? HTMLAppThrowingRuntimeStorage {
                try throwingStorage.setThrowing(data, forKey: storageKey)
            } else {
                storage.set(data, forKey: storageKey)
            }
        } catch {
            throw HTMLAppTrustRegistryError.persistenceFailed
        }
    }

    private static func load(storage: HTMLAppRuntimeStorage, key: String) -> State {
        guard let data = storage.data(forKey: key),
              let state = try? JSONDecoder().decode(State.self, from: data) else {
            return State(configurations: [:], activeGatewayID: nil)
        }
        return state
    }
}
