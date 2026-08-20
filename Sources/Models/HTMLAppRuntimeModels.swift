//
//  HTMLAppRuntimeModels.swift
//  WebBridgeKit
//
//  Protocol models for managed HTML applications. They intentionally avoid
//  product-specific concepts so any conforming HTML application can use them.
//

import Foundation

public enum HTMLAppCapability: String, CaseIterable, Codable, Sendable {
    case biometrics
    case bluetooth
    case camera
    case clipboard
    case contacts
    case deviceControl
    case displayStatus
    case fileExport
    case fileImport
    case location
    case microphone
    case motion
    case notification
    case photoLibrary
    case scan
    case share

    public var displayName: String {
        switch self {
        case .biometrics: return "身份验证"
        case .bluetooth: return "蓝牙"
        case .camera: return "相机"
        case .clipboard: return "剪贴板"
        case .contacts: return "通讯录"
        case .deviceControl: return "设备控制"
        case .displayStatus: return "投屏状态"
        case .fileExport: return "导出文件"
        case .fileImport: return "读取文件"
        case .location: return "位置"
        case .microphone: return "麦克风"
        case .motion: return "运动传感器"
        case .notification: return "通知"
        case .photoLibrary: return "照片"
        case .scan: return "扫码"
        case .share: return "系统分享"
        }
    }
}

public enum HTMLAppPermissionScope: String, Codable, Sendable {
    case once
    case appSession
    case always
}

public struct HTMLAppManifestSignature: Codable, Equatable, Sendable {
    public let algorithm: String
    public let keyID: String
    public let value: String

    public init(algorithm: String, keyID: String, value: String) {
        self.algorithm = algorithm
        self.keyID = keyID
        self.value = value
    }

    var isWellFormed: Bool {
        algorithm == "ed25519" && !keyID.isEmpty && !value.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case algorithm
        case keyID = "keyId"
        case value
    }
}

public struct HTMLAppCachePolicy: Codable, Equatable, Sendable {
    public enum Strategy: String, Codable, Sendable {
        case manifest
        case networkOnly
    }

    public let strategy: Strategy
    public let version: String
    public let persistent: Bool
    public let resourceManifestURL: String?
    public let resourceManifestSHA256: String?
    public let restoresLastState: Bool

    public init(
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

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        strategy = try values.decode(Strategy.self, forKey: .strategy)
        version = try values.decode(String.self, forKey: .version)
        persistent = try values.decode(Bool.self, forKey: .persistent)
        resourceManifestURL = try values.decodeIfPresent(String.self, forKey: .resourceManifestURL)
        resourceManifestSHA256 = try values.decodeIfPresent(String.self, forKey: .resourceManifestSHA256)
        restoresLastState = try values.decodeIfPresent(Bool.self, forKey: .restoresLastState) ?? true
    }

    /// Whether the signed parent manifest carries all production trust anchors
    /// needed by a strong offline package. Installation success is a separate
    /// fact and must be checked before reporting `.strong` launch availability.
    public var isStrongOfflineEligible: Bool {
        guard strategy == .manifest,
              persistent,
              let value = resourceManifestURL,
              let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              let digest = resourceManifestSHA256 else {
            return false
        }
        return Self.isValidSHA256(digest)
    }

    public static func isValidSHA256(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        return bytes.count == 64 && bytes.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

public struct HTMLAppManifest: Codable, Equatable, Sendable {
    public static let supportedSchemaVersion = "1"

    public let schemaVersion: String
    public let appID: String
    public let name: String
    public let startURL: String
    public let allowedOrigins: [String]
    public let capabilities: [HTMLAppCapability]
    public let routes: [String]
    public let cache: HTMLAppCachePolicy
    public let signature: HTMLAppManifestSignature?

    public init(
        schemaVersion: String = HTMLAppManifest.supportedSchemaVersion,
        appID: String,
        name: String,
        startURL: String,
        allowedOrigins: [String],
        capabilities: [HTMLAppCapability],
        routes: [String],
        cache: HTMLAppCachePolicy,
        signature: HTMLAppManifestSignature? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.appID = appID
        self.name = name
        self.startURL = startURL
        self.allowedOrigins = allowedOrigins
        self.capabilities = capabilities
        self.routes = routes
        self.cache = cache
        self.signature = signature
    }

    public func validate(requiringSignature: Bool = false) -> HTMLAppManifestValidationResult {
        var errors: [HTMLAppManifestError] = []

        if schemaVersion != Self.supportedSchemaVersion {
            errors.append(.unsupportedSchemaVersion(schemaVersion))
        }

        if !Self.isValidAppID(appID) {
            errors.append(.invalidAppID(appID))
        }

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }

        guard let startURL = URL(string: self.startURL),
              let startOrigin = HTMLAppOrigin.canonicalOrigin(forDocumentURL: startURL) else {
            errors.append(.invalidStartURL(self.startURL))
            return .invalid(errors)
        }

        if allowedOrigins.isEmpty {
            errors.append(.missingAllowedOrigins)
        }

        let canonicalOrigins = allowedOrigins.compactMap(HTMLAppOrigin.canonicalDeclaredOrigin)
        if canonicalOrigins.count != allowedOrigins.count || Set(canonicalOrigins).count != canonicalOrigins.count {
            errors.append(.invalidAllowedOrigins)
        }
        if !canonicalOrigins.contains(startOrigin) {
            errors.append(.startURLNotAllowed(startOrigin))
        }

        if routes.isEmpty || routes.contains(where: { !HTMLAppRoute.isValidPattern($0) }) {
            errors.append(.invalidRoutes)
        }

        if cache.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyCacheVersion)
        }

        if let resourceManifestURL = cache.resourceManifestURL {
            guard let url = URL(string: resourceManifestURL),
                  let resourceOrigin = HTMLAppOrigin.canonicalOrigin(forDocumentURL: url),
                  canonicalOrigins.contains(resourceOrigin) else {
                errors.append(.invalidResourceManifestURL(resourceManifestURL))
                return .invalid(errors)
            }
        }

        if let digest = cache.resourceManifestSHA256,
           !HTMLAppCachePolicy.isValidSHA256(digest) {
            errors.append(.invalidResourceManifestDigest)
        }

        if signature != nil && !(signature?.isWellFormed ?? false) {
            errors.append(.missingOrInvalidSignature)
        } else if requiringSignature && signature == nil {
            errors.append(.missingOrInvalidSignature)
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }

    public func allows(documentURL: URL) -> Bool {
        guard let documentOrigin = HTMLAppOrigin.canonicalOrigin(forDocumentURL: documentURL) else {
            return false
        }
        return allowedOrigins.contains { HTMLAppOrigin.canonicalDeclaredOrigin($0) == documentOrigin }
    }

    public func declares(_ capability: HTMLAppCapability) -> Bool {
        capabilities.contains(capability)
    }

    public func allows(route: String) -> Bool {
        routes.contains { HTMLAppRoute.matches(pattern: $0, route: route) }
    }

    private static func isValidAppID(_ appID: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        return !appID.isEmpty && appID.count <= 64 && appID.unicodeScalars.allSatisfy(allowed.contains)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case appID = "appId"
        case name
        case startURL
        case allowedOrigins
        case capabilities
        case routes
        case cache
        case signature
    }
}

public enum HTMLAppManifestValidationResult: Equatable {
    case valid
    case invalid([HTMLAppManifestError])

    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

public enum HTMLAppManifestError: Error, Equatable, LocalizedError {
    case unsupportedSchemaVersion(String)
    case invalidAppID(String)
    case emptyName
    case invalidStartURL(String)
    case missingAllowedOrigins
    case invalidAllowedOrigins
    case startURLNotAllowed(String)
    case invalidRoutes
    case emptyCacheVersion
    case invalidResourceManifestURL(String)
    case invalidResourceManifestDigest
    case missingOrInvalidSignature

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version): return "Unsupported HTML app manifest schema: \(version)"
        case .invalidAppID(let appID): return "Invalid HTML app ID: \(appID)"
        case .emptyName: return "HTML app name must not be empty"
        case .invalidStartURL(let url): return "Invalid HTML app start URL: \(url)"
        case .missingAllowedOrigins: return "HTML app must declare at least one allowed origin"
        case .invalidAllowedOrigins: return "HTML app allowed origins must be unique exact HTTP(S) origins"
        case .startURLNotAllowed(let origin): return "HTML app start URL origin is not allowed: \(origin)"
        case .invalidRoutes: return "HTML app routes are invalid"
        case .emptyCacheVersion: return "HTML app cache version must not be empty"
        case .invalidResourceManifestURL(let url): return "HTML app resource manifest URL is invalid: \(url)"
        case .invalidResourceManifestDigest: return "HTML app resource manifest SHA-256 must be 64 lowercase hexadecimal characters"
        case .missingOrInvalidSignature: return "HTML app manifest signature is missing or invalid"
        }
    }
}

public struct HTMLAppCapabilityRequest: Codable, Equatable, Sendable {
    public let id: String
    public let capability: HTMLAppCapability
    public let reason: String
    public let scope: HTMLAppPermissionScope

    public init(id: String, capability: HTMLAppCapability, reason: String, scope: HTMLAppPermissionScope) {
        self.id = id
        self.capability = capability
        self.reason = reason
        self.scope = scope
    }

    public func validate(against manifest: HTMLAppManifest) -> HTMLAppCapabilityRequestResult {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .rejected(.missingRequestID)
        }
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .rejected(.missingReason)
        }
        guard manifest.declares(capability) else {
            return .rejected(.undeclaredCapability(capability))
        }
        return .accepted
    }
}

public enum HTMLAppCapabilityRequestResult: Equatable {
    case accepted
    case rejected(HTMLAppCapabilityRequestError)
}

public enum HTMLAppCapabilityRequestError: Error, Equatable, LocalizedError {
    case missingRequestID
    case missingReason
    case undeclaredCapability(HTMLAppCapability)

    public var errorDescription: String? {
        switch self {
        case .missingRequestID: return "Capability request ID is required"
        case .missingReason: return "Capability request reason is required"
        case .undeclaredCapability(let capability): return "Capability is not declared: \(capability.rawValue)"
        }
    }
}

public struct HTMLAppCapabilityResult: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case granted
        case denied
        case notDetermined
        case restricted
        case requiresSettings
        case unavailable
    }

    public enum AuthorizationLayer: String, Codable, Sendable {
        case nativeSystem
        case htmlApp
    }

    public let id: String
    public let capability: HTMLAppCapability
    public let status: Status
    public let scope: HTMLAppPermissionScope?
    public let authorizationLayer: AuthorizationLayer?

    public init(
        id: String,
        capability: HTMLAppCapability,
        status: Status,
        scope: HTMLAppPermissionScope? = nil,
        authorizationLayer: AuthorizationLayer? = nil
    ) {
        self.id = id
        self.capability = capability
        self.status = status
        self.scope = scope
        self.authorizationLayer = authorizationLayer
    }
}

public struct HTMLAppPushNotification: Codable, Equatable, Sendable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

public struct HTMLAppPushEnvelope: Codable, Equatable, Sendable {
    public let version: String
    public let appID: String
    public let route: String
    public let parameters: [String: String]
    public let notification: HTMLAppPushNotification
    public let expiresAt: String?
    public let nonce: String?

    public init(
        version: String = HTMLAppManifest.supportedSchemaVersion,
        appID: String,
        route: String,
        parameters: [String: String] = [:],
        notification: HTMLAppPushNotification,
        expiresAt: String? = nil,
        nonce: String? = nil
    ) {
        self.version = version
        self.appID = appID
        self.route = route
        self.parameters = parameters
        self.notification = notification
        self.expiresAt = expiresAt
        self.nonce = nonce
    }

    public func isValid(for manifest: HTMLAppManifest, now: Date = Date()) -> Bool {
        guard version == HTMLAppManifest.supportedSchemaVersion,
              appID == manifest.appID,
              manifest.allows(route: route),
              !notification.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        guard let expiresAt = expiresAt else { return true }
        guard let date = ISO8601DateFormatter().date(from: expiresAt) else { return false }
        return date > now
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case appID = "appId"
        case route
        case parameters = "params"
        case notification
        case expiresAt
        case nonce
    }
}

public enum HTMLAppOrigin {
    public static func canonicalDeclaredOrigin(_ value: String) -> String? {
        guard let url = URL(string: value),
              url.path.isEmpty || url.path == "/",
              url.query == nil,
              url.fragment == nil,
              url.user == nil,
              url.password == nil,
              !(url.host?.contains("*") ?? false) else {
            return nil
        }
        return canonicalOrigin(forDocumentURL: url)
    }

    public static func canonicalOrigin(forDocumentURL url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host?.lowercased(),
              !host.isEmpty,
              url.user == nil,
              url.password == nil else {
            return nil
        }

        let port = url.port
        let isDefaultPort = (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
        let portPart = port == nil || isDefaultPort ? "" : ":\(port!)"
        return "\(scheme)://\(host)\(portPart)"
    }
}

public enum HTMLAppRoute {
    public static func isValidPattern(_ route: String) -> Bool {
        isValid(route, allowsParameters: true)
    }

    public static func matches(pattern: String, route: String) -> Bool {
        guard isValid(pattern, allowsParameters: true), isValid(route, allowsParameters: false) else {
            return false
        }

        let patternComponents = components(for: pattern)
        let routeComponents = components(for: route)
        guard patternComponents.count == routeComponents.count else { return false }

        return zip(patternComponents, routeComponents).allSatisfy { patternPart, routePart in
            patternPart.hasPrefix(":") ? !routePart.isEmpty : patternPart == routePart
        }
    }

    private static func isValid(_ route: String, allowsParameters: Bool) -> Bool {
        guard route.hasPrefix("/"),
              !route.contains("//"),
              !route.contains(".."),
              !route.contains("?"),
              !route.contains("#") else {
            return false
        }

        for component in components(for: route) {
            if component.hasPrefix(":") {
                guard allowsParameters, component.count > 1 else { return false }
            } else if component.contains(":") {
                return false
            }
        }
        return true
    }

    private static func components(for route: String) -> [String] {
        route.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }
}
