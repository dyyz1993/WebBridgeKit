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
    public static let official = HTMLAppGatewayConfiguration(
        id: "tx-webbridgekit",
        name: "WebBridgeKit 官方服务",
        baseURL: "https://cloak.xbrowser.dev:5801",
        healthPath: "/health",
        manifestPath: "/api/v1/html-apps",
        publicKeyID: "tx-ed25519-20260810",
        publicKey: "ZDgR7vFJo7MbhRTj7H3EuYygdVv89ZqR8I6sZXUfShE"
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
        return .valid
    }

    public static func importPayload(
        _ payload: String,
        allowsDevelopmentHTTP: Bool = false
    ) throws -> HTMLAppGatewayConfiguration {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HTMLAppGatewayConfigurationImportError.emptyPayload }

        if let data = trimmed.data(using: .utf8),
           let configuration = try? JSONDecoder().decode(HTMLAppGatewayConfiguration.self, from: data) {
            return try validateImported(configuration, allowsDevelopmentHTTP: allowsDevelopmentHTTP)
        }

        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "webbridgekit",
              components.host?.lowercased() == "gateway" else {
            throw HTMLAppGatewayConfigurationImportError.unsupportedPayload
        }
        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard values[item.name] == nil else {
                throw HTMLAppGatewayConfigurationImportError.invalidConfiguration
            }
            values[item.name] = item.value ?? ""
        }
        guard let baseURL = values["url"], let name = values["name"] else {
            throw HTMLAppGatewayConfigurationImportError.missingRequiredField
        }
        let configuration = HTMLAppGatewayConfiguration(
            id: values["id"]?.isEmpty == false ? values["id"]! : UUID().uuidString.lowercased(),
            name: name,
            baseURL: baseURL,
            healthPath: values["healthPath"]?.isEmpty == false ? values["healthPath"]! : "/health",
            manifestPath: values["manifestPath"]?.isEmpty == false ? values["manifestPath"]! : "/manifest",
            publicKeyID: values["keyId"]?.isEmpty == false ? values["keyId"] : nil,
            publicKey: values["publicKey"]?.isEmpty == false ? values["publicKey"] : nil
        )
        return try validateImported(configuration, allowsDevelopmentHTTP: allowsDevelopmentHTTP)
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

    public var errorDescription: String? {
        switch self {
        case .missingName: return "Gateway name is required"
        case .invalidBaseURL: return "Gateway base URL must be an exact HTTP(S) origin"
        case .insecureBaseURL: return "Gateway requires HTTPS outside development"
        case .invalidManifestPath: return "Gateway manifest path is invalid"
        case .incompleteTrustAnchor: return "Gateway keyId and publicKey must be provided together"
        }
    }
}

public enum HTMLAppGatewayConfigurationImportError: Error, Equatable, LocalizedError {
    case emptyPayload
    case unsupportedPayload
    case missingRequiredField
    case invalidConfiguration

    public var errorDescription: String? {
        switch self {
        case .emptyPayload: return "Gateway configuration payload is empty"
        case .unsupportedPayload: return "Gateway configuration must be JSON or a webbridgekit gateway URL"
        case .missingRequiredField: return "Gateway configuration is missing a required field"
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
        state.configurations[configuration.id] = configuration
        if activate { state.activeGatewayID = configuration.id }
        try persistLocked()
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
        state.activeGatewayID = id
        try persistLocked()
    }

    public func remove(id: String) throws {
        lock.lock()
        defer { lock.unlock() }
        state.configurations.removeValue(forKey: id)
        if state.activeGatewayID == id { state.activeGatewayID = nil }
        try persistLocked()
    }

    private func persistLocked() throws {
        do {
            storage.set(try JSONEncoder().encode(state), forKey: storageKey)
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
