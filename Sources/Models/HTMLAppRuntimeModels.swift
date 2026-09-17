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

/// Drel's namespaced extension for declaring a strongly installed offline
/// package from an otherwise standards-compatible web app manifest. Standard
/// Web App Manifest consumers ignore this member; Drel maps it onto its
/// existing signed resource-manifest installer contract.
public struct DrelOfflinePackageDeclaration: Codable, Equatable, Sendable {
    public let version: String
    public let resourceManifestURL: String
    public let resourceManifestSHA256: String

    public init(
        version: String,
        resourceManifestURL: String,
        resourceManifestSHA256: String
    ) {
        self.version = version
        self.resourceManifestURL = resourceManifestURL
        self.resourceManifestSHA256 = resourceManifestSHA256
    }

    fileprivate func cachePolicy(restoresLastState: Bool) -> HTMLAppCachePolicy {
        HTMLAppCachePolicy(
            strategy: .manifest,
            version: version,
            persistent: true,
            resourceManifestURL: resourceManifestURL,
            resourceManifestSHA256: resourceManifestSHA256,
            restoresLastState: restoresLastState
        )
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case resourceManifestURL = "resource_manifest"
        case resourceManifestSHA256 = "resource_manifest_sha256"
    }
}

/// A digest-pinned reference to the standards-compatible Web App Manifest.
/// The binding is part of the signed Drel parent manifest; the remote file is
/// presentation metadata only until its exact bytes have been verified.
public struct HTMLAppWebManifestBinding: Codable, Equatable, Sendable {
    public let url: String
    public let sha256: String

    public init(url: String, sha256: String) {
        self.url = url
        self.sha256 = sha256
    }
}

public struct HTMLAppWebManifestIcon: Codable, Equatable, Sendable {
    public let src: String
    public let sizes: String?
    public let type: String?
    public let purpose: String?

    public init(src: String, sizes: String? = nil, type: String? = nil, purpose: String? = nil) {
        self.src = src
        self.sizes = sizes
        self.type = type
        self.purpose = purpose
    }
}

/// The deliberately small Web App Manifest profile understood by Drel. Any
/// additional standard members remain forward-compatible and are ignored.
public struct HTMLAppWebManifest: Codable, Equatable, Sendable {
    public let id: String?
    public let name: String?
    public let shortName: String?
    public let startURL: String?
    public let scope: String?
    public let display: String?
    public let themeColor: String?
    public let backgroundColor: String?
    public let icons: [HTMLAppWebManifestIcon]
    public let drelOffline: DrelOfflinePackageDeclaration?

    public init(
        id: String? = nil,
        name: String? = nil,
        shortName: String? = nil,
        startURL: String? = nil,
        scope: String? = nil,
        display: String? = nil,
        themeColor: String? = nil,
        backgroundColor: String? = nil,
        icons: [HTMLAppWebManifestIcon] = [],
        drelOffline: DrelOfflinePackageDeclaration? = nil
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.startURL = startURL
        self.scope = scope
        self.display = display
        self.themeColor = themeColor
        self.backgroundColor = backgroundColor
        self.icons = icons
        self.drelOffline = drelOffline
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, scope, display, icons
        case shortName = "short_name"
        case startURL = "start_url"
        case themeColor = "theme_color"
        case backgroundColor = "background_color"
        case drelOffline = "drel_offline"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        shortName = try values.decodeIfPresent(String.self, forKey: .shortName)
        startURL = try values.decodeIfPresent(String.self, forKey: .startURL)
        scope = try values.decodeIfPresent(String.self, forKey: .scope)
        display = try values.decodeIfPresent(String.self, forKey: .display)
        themeColor = try values.decodeIfPresent(String.self, forKey: .themeColor)
        backgroundColor = try values.decodeIfPresent(String.self, forKey: .backgroundColor)
        icons = try values.decodeIfPresent([HTMLAppWebManifestIcon].self, forKey: .icons) ?? []
        drelOffline = try values.decodeIfPresent(DrelOfflinePackageDeclaration.self, forKey: .drelOffline)
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
    public let webManifest: HTMLAppWebManifestBinding?
    /// Optional `drel_offline` extension. It is signed with the parent
    /// manifest and takes precedence for the strong-offline installer only.
    public let drelOffline: DrelOfflinePackageDeclaration?
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
        webManifest: HTMLAppWebManifestBinding? = nil,
        drelOffline: DrelOfflinePackageDeclaration? = nil,
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
        self.webManifest = webManifest
        self.drelOffline = drelOffline
        self.signature = signature
    }

    /// The only cache policy used to decide strong-offline installation and
    /// launch. Legacy signed manifests keep their existing `cache` contract;
    /// newer manifests may use the namespaced Web Manifest extension instead.
    public var effectiveOfflineCache: HTMLAppCachePolicy {
        drelOffline?.cachePolicy(restoresLastState: cache.restoresLastState) ?? cache
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

        if hasInconsistentDrelOfflineDeclaration {
            errors.append(.inconsistentDrelOfflineDeclaration)
        }

        if let webManifest {
            guard let url = URL(string: webManifest.url),
                  let origin = HTMLAppOrigin.canonicalOrigin(forDocumentURL: url),
                  url.scheme?.lowercased() == "https",
                  canonicalOrigins.contains(origin) else {
                errors.append(.invalidWebManifestURL(webManifest.url))
                return .invalid(errors)
            }
            if !HTMLAppCachePolicy.isValidSHA256(webManifest.sha256) {
                errors.append(.invalidWebManifestDigest)
            }
        }

        let offlineCache = effectiveOfflineCache
        if offlineCache.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyCacheVersion)
        }

        if let resourceManifestURL = offlineCache.resourceManifestURL {
            guard let url = URL(string: resourceManifestURL),
                  let resourceOrigin = HTMLAppOrigin.canonicalOrigin(forDocumentURL: url),
                  canonicalOrigins.contains(resourceOrigin) else {
                errors.append(.invalidResourceManifestURL(resourceManifestURL))
                return .invalid(errors)
            }
        }

        if let digest = offlineCache.resourceManifestSHA256,
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

    private var hasInconsistentDrelOfflineDeclaration: Bool {
        guard let drelOffline else { return false }
        let hasLegacyResourceDeclaration = cache.resourceManifestURL != nil || cache.resourceManifestSHA256 != nil
        guard hasLegacyResourceDeclaration else { return false }
        return cache.strategy != .manifest
            || !cache.persistent
            || cache.version != drelOffline.version
            || cache.resourceManifestURL != drelOffline.resourceManifestURL
            || cache.resourceManifestSHA256 != drelOffline.resourceManifestSHA256
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
        case webManifest
        case drelOffline = "drel_offline"
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
    case inconsistentDrelOfflineDeclaration
    case invalidWebManifestURL(String)
    case invalidWebManifestDigest
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
        case .inconsistentDrelOfflineDeclaration: return "HTML app drel_offline declaration conflicts with the legacy cache resource declaration"
        case .invalidWebManifestURL(let url): return "Web App Manifest URL is invalid or outside the allowed origins: \(url)"
        case .invalidWebManifestDigest: return "Web App Manifest SHA-256 must be 64 lowercase hexadecimal characters"
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

    /// Stable machine-readable reason a request did not end in `.granted`.
    /// Bridge responses expose it so HTML apps can branch without string matching.
    public enum FailureReason: String, Codable, Sendable {
        case userCancelled
        case systemDenied
        case systemRestricted
        case systemNotDetermined
        case undeclaredCapability
        case originMismatch
        case appNotRegistered
        case presentationUnavailable
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
    public let failureReason: FailureReason?

    public init(
        id: String,
        capability: HTMLAppCapability,
        status: Status,
        scope: HTMLAppPermissionScope? = nil,
        authorizationLayer: AuthorizationLayer? = nil,
        failureReason: FailureReason? = nil
    ) {
        self.id = id
        self.capability = capability
        self.status = status
        self.scope = scope
        self.authorizationLayer = authorizationLayer
        self.failureReason = failureReason
    }

    private enum CodingKeys: String, CodingKey {
        case id, capability, status, scope, authorizationLayer, failureReason
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        capability = try values.decode(HTMLAppCapability.self, forKey: .capability)
        status = try values.decode(Status.self, forKey: .status)
        scope = try values.decodeIfPresent(HTMLAppPermissionScope.self, forKey: .scope)
        authorizationLayer = try values.decodeIfPresent(AuthorizationLayer.self, forKey: .authorizationLayer)
        failureReason = try values.decodeIfPresent(FailureReason.self, forKey: .failureReason)
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
            } else if component.contains(":") || component.contains("*") {
                return false
            }
        }
        return true
    }

    private static func components(for route: String) -> [String] {
        route.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }
}
