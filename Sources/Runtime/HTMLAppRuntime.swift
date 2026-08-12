//
//  HTMLAppRuntime.swift
//  WebBridgeKit
//
//  Trust, permission, and capability-gateway primitives for managed HTML apps.
//

import Foundation

public protocol HTMLAppRuntimeStorage: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
}

public final class HTMLAppUserDefaultsStorage: HTMLAppRuntimeStorage {
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func data(forKey key: String) -> Data? {
        userDefaults.data(forKey: key)
    }

    public func set(_ data: Data?, forKey key: String) {
        userDefaults.set(data, forKey: key)
    }
}

public struct HTMLAppTrustPolicy {
    public let requiresSignature: Bool
    private let signatureVerifier: ((HTMLAppManifest) -> Bool)?

    public static let development = HTMLAppTrustPolicy(requiresSignature: false)

    public init(requiresSignature: Bool, signatureVerifier: ((HTMLAppManifest) -> Bool)? = nil) {
        self.requiresSignature = requiresSignature
        self.signatureVerifier = signatureVerifier
    }

    public static func managed(
        signatureVerifier: @escaping (HTMLAppManifest) -> Bool
    ) -> HTMLAppTrustPolicy {
        HTMLAppTrustPolicy(requiresSignature: true, signatureVerifier: signatureVerifier)
    }

    fileprivate func accepts(_ manifest: HTMLAppManifest) -> Bool {
        guard requiresSignature else { return true }
        return signatureVerifier?(manifest) ?? false
    }
}

public enum HTMLAppTrustRegistryError: Error, Equatable, LocalizedError {
    case invalidManifest([HTMLAppManifestError])
    case signatureVerificationFailed(appID: String)
    case persistenceFailed

    public var errorDescription: String? {
        switch self {
        case .invalidManifest(let errors):
            return "Invalid HTML app manifest: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        case .signatureVerificationFailed(let appID):
            return "HTML app manifest signature verification failed: \(appID)"
        case .persistenceFailed:
            return "Unable to persist HTML app runtime state"
        }
    }
}

public final class HTMLAppTrustRegistry {
    private let storage: HTMLAppRuntimeStorage
    private let storageKey: String
    private let lock = NSLock()
    private var manifests: [String: HTMLAppManifest]

    public init(
        storage: HTMLAppRuntimeStorage = HTMLAppUserDefaultsStorage(),
        storageKey: String = "com.webbridgekit.html-app-runtime.manifests"
    ) {
        self.storage = storage
        self.storageKey = storageKey
        manifests = Self.load(storage: storage, key: storageKey)
    }

    public func register(
        _ manifest: HTMLAppManifest,
        trustPolicy: HTMLAppTrustPolicy = .development
    ) throws {
        let validation = manifest.validate(requiringSignature: trustPolicy.requiresSignature)
        guard validation.isValid else {
            if case .invalid(let errors) = validation {
                throw HTMLAppTrustRegistryError.invalidManifest(errors)
            }
            throw HTMLAppTrustRegistryError.persistenceFailed
        }
        guard trustPolicy.accepts(manifest) else {
            throw HTMLAppTrustRegistryError.signatureVerificationFailed(appID: manifest.appID)
        }

        lock.lock()
        defer { lock.unlock() }
        manifests[manifest.appID] = manifest
        try persistLocked()
    }

    public func manifest(for appID: String) -> HTMLAppManifest? {
        lock.lock()
        defer { lock.unlock() }
        return manifests[appID]
    }

    public func registeredManifests() -> [HTMLAppManifest] {
        lock.lock()
        defer { lock.unlock() }
        return manifests.values.sorted { $0.appID < $1.appID }
    }

    public func unregister(appID: String) throws {
        lock.lock()
        defer { lock.unlock() }
        manifests.removeValue(forKey: appID)
        try persistLocked()
    }

    private func persistLocked() throws {
        do {
            storage.set(try JSONEncoder().encode(manifests), forKey: storageKey)
        } catch {
            throw HTMLAppTrustRegistryError.persistenceFailed
        }
    }

    private static func load(storage: HTMLAppRuntimeStorage, key: String) -> [String: HTMLAppManifest] {
        guard let data = storage.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: HTMLAppManifest].self, from: data)) ?? [:]
    }
}

public struct HTMLAppPermissionGrant: Codable, Equatable, Sendable {
    public let appID: String
    public let capability: HTMLAppCapability
    public let scope: HTMLAppPermissionScope
    public let grantedAt: Date

    public init(
        appID: String,
        capability: HTMLAppCapability,
        scope: HTMLAppPermissionScope,
        grantedAt: Date = Date()
    ) {
        self.appID = appID
        self.capability = capability
        self.scope = scope
        self.grantedAt = grantedAt
    }
}

public final class HTMLAppPermissionLedger {
    private let storage: HTMLAppRuntimeStorage
    private let storageKey: String
    private let lock = NSLock()
    private var persistentGrants: [String: HTMLAppPermissionGrant]
    private var sessionGrants: [String: HTMLAppPermissionGrant] = [:]

    public init(
        storage: HTMLAppRuntimeStorage = HTMLAppUserDefaultsStorage(),
        storageKey: String = "com.webbridgekit.html-app-runtime.permission-grants"
    ) {
        self.storage = storage
        self.storageKey = storageKey
        persistentGrants = Self.load(storage: storage, key: storageKey)
    }

    @discardableResult
    public func grant(
        appID: String,
        capability: HTMLAppCapability,
        scope: HTMLAppPermissionScope,
        grantedAt: Date = Date()
    ) -> HTMLAppPermissionGrant {
        let grant = HTMLAppPermissionGrant(
            appID: appID,
            capability: capability,
            scope: scope,
            grantedAt: grantedAt
        )
        let key = Self.key(appID: appID, capability: capability)

        lock.lock()
        defer { lock.unlock() }
        switch scope {
        case .once:
            break
        case .appSession:
            persistentGrants.removeValue(forKey: key)
            sessionGrants[key] = grant
            persistLocked()
        case .always:
            sessionGrants.removeValue(forKey: key)
            persistentGrants[key] = grant
            persistLocked()
        }
        return grant
    }

    public func grant(for appID: String, capability: HTMLAppCapability) -> HTMLAppPermissionGrant? {
        let key = Self.key(appID: appID, capability: capability)
        lock.lock()
        defer { lock.unlock() }
        return sessionGrants[key] ?? persistentGrants[key]
    }

    public func grants(for appID: String) -> [HTMLAppPermissionGrant] {
        lock.lock()
        defer { lock.unlock() }
        return (Array(sessionGrants.values) + Array(persistentGrants.values))
            .filter { $0.appID == appID }
            .sorted { $0.capability.rawValue < $1.capability.rawValue }
    }

    public func revoke(appID: String, capability: HTMLAppCapability) {
        let key = Self.key(appID: appID, capability: capability)
        lock.lock()
        defer { lock.unlock() }
        sessionGrants.removeValue(forKey: key)
        persistentGrants.removeValue(forKey: key)
        persistLocked()
    }

    public func revokeAll(appID: String) {
        lock.lock()
        defer { lock.unlock() }
        sessionGrants = sessionGrants.filter { $0.value.appID != appID }
        persistentGrants = persistentGrants.filter { $0.value.appID != appID }
        persistLocked()
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(persistentGrants) else { return }
        storage.set(data, forKey: storageKey)
    }

    private static func load(storage: HTMLAppRuntimeStorage, key: String) -> [String: HTMLAppPermissionGrant] {
        guard let data = storage.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: HTMLAppPermissionGrant].self, from: data)) ?? [:]
    }

    private static func key(appID: String, capability: HTMLAppCapability) -> String {
        "\(appID)|\(capability.rawValue)"
    }
}

public protocol HTMLAppNativeAuthorizationProviding: AnyObject {
    func authorizationStatus(for capability: HTMLAppCapability) -> HTMLAppCapabilityResult.Status
}

public final class HTMLAppCapabilityGateway {
    private struct PendingRequest {
        let appID: String
        let capability: HTMLAppCapability
        let documentOrigin: String
    }

    private let trustRegistry: HTMLAppTrustRegistry
    private let permissionLedger: HTMLAppPermissionLedger
    private let nativeAuthorizationProvider: HTMLAppNativeAuthorizationProviding
    private let lock = NSLock()
    private var pendingRequests: [String: PendingRequest] = [:]

    public init(
        trustRegistry: HTMLAppTrustRegistry,
        permissionLedger: HTMLAppPermissionLedger,
        nativeAuthorizationProvider: HTMLAppNativeAuthorizationProviding
    ) {
        self.trustRegistry = trustRegistry
        self.permissionLedger = permissionLedger
        self.nativeAuthorizationProvider = nativeAuthorizationProvider
    }

    public func requestAuthorization(
        appID: String,
        documentURL: URL,
        request: HTMLAppCapabilityRequest
    ) -> HTMLAppCapabilityResult {
        guard let manifest = trustRegistry.manifest(for: appID),
              manifest.allows(documentURL: documentURL),
              case .accepted = request.validate(against: manifest) else {
            return result(for: request, status: .denied)
        }

        let nativeStatus = nativeAuthorizationProvider.authorizationStatus(for: request.capability)
        guard nativeStatus == .granted else {
            return result(
                for: request,
                status: nativeStatus == .denied ? .requiresSettings : nativeStatus,
                authorizationLayer: .nativeSystem
            )
        }

        if let grant = permissionLedger.grant(for: appID, capability: request.capability) {
            return result(for: request, status: .granted, scope: grant.scope)
        }

        guard let origin = HTMLAppOrigin.canonicalOrigin(forDocumentURL: documentURL) else {
            return result(for: request, status: .denied)
        }
        lock.lock()
        pendingRequests[pendingKey(appID: appID, requestID: request.id)] = PendingRequest(
            appID: appID,
            capability: request.capability,
            documentOrigin: origin
        )
        lock.unlock()
        return result(for: request, status: .notDetermined, authorizationLayer: .htmlApp)
    }

    public func resolveUserConsent(
        appID: String,
        documentURL: URL,
        request: HTMLAppCapabilityRequest,
        granted: Bool
    ) -> HTMLAppCapabilityResult {
        let key = pendingKey(appID: appID, requestID: request.id)
        lock.lock()
        let pendingRequest = pendingRequests.removeValue(forKey: key)
        lock.unlock()

        guard let pendingRequest,
              pendingRequest.appID == appID,
              pendingRequest.capability == request.capability,
              pendingRequest.documentOrigin == HTMLAppOrigin.canonicalOrigin(forDocumentURL: documentURL),
              granted else {
            return result(for: request, status: .denied, authorizationLayer: .htmlApp)
        }

        guard let manifest = trustRegistry.manifest(for: appID),
              manifest.allows(documentURL: documentURL),
              case .accepted = request.validate(against: manifest) else {
            return result(for: request, status: .denied, authorizationLayer: .htmlApp)
        }

        let nativeStatus = nativeAuthorizationProvider.authorizationStatus(for: request.capability)
        guard nativeStatus == .granted else {
            return result(
                for: request,
                status: nativeStatus == .denied ? .requiresSettings : nativeStatus,
                authorizationLayer: .nativeSystem
            )
        }

        let permissionGrant = permissionLedger.grant(
            appID: appID,
            capability: request.capability,
            scope: request.scope
        )
        return result(for: request, status: .granted, scope: permissionGrant.scope)
    }

    public func revokeAuthorization(appID: String, capability: HTMLAppCapability) {
        permissionLedger.revoke(appID: appID, capability: capability)
    }

    private func pendingKey(appID: String, requestID: String) -> String {
        "\(appID)|\(requestID)"
    }

    private func result(
        for request: HTMLAppCapabilityRequest,
        status: HTMLAppCapabilityResult.Status,
        scope: HTMLAppPermissionScope? = nil,
        authorizationLayer: HTMLAppCapabilityResult.AuthorizationLayer? = nil
    ) -> HTMLAppCapabilityResult {
        HTMLAppCapabilityResult(
            id: request.id,
            capability: request.capability,
            status: status,
            scope: scope,
            authorizationLayer: authorizationLayer
        )
    }
}
