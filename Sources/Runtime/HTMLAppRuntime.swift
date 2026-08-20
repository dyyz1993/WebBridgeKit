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

/// Optional extension for storage backends that can surface persistence errors.
/// Runtime registries use it when available so in-memory state is not advanced
/// after a failed durable write.
public protocol HTMLAppThrowingRuntimeStorage: HTMLAppRuntimeStorage {
    func setThrowing(_ data: Data?, forKey key: String) throws
}

private extension HTMLAppRuntimeStorage {
    func persist(_ data: Data?, forKey key: String) throws {
        if let throwingStorage = self as? HTMLAppThrowingRuntimeStorage {
            try throwingStorage.setThrowing(data, forKey: key)
        } else {
            set(data, forKey: key)
        }
    }
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
        var proposed = manifests
        proposed[manifest.appID] = manifest
        try persistLocked(proposed)
        manifests = proposed
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
        var proposed = manifests
        proposed.removeValue(forKey: appID)
        try persistLocked(proposed)
        manifests = proposed
    }

    public func replaceAll(
        _ replacement: [HTMLAppManifest],
        trustPolicy: HTMLAppTrustPolicy = .development
    ) throws {
        for manifest in replacement {
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
        }
        let proposed = Dictionary(uniqueKeysWithValues: replacement.map { ($0.appID, $0) })
        lock.lock()
        defer { lock.unlock() }
        try persistLocked(proposed)
        manifests = proposed
    }

    private func persistLocked(_ proposed: [String: HTMLAppManifest]) throws {
        do {
            try storage.persist(try JSONEncoder().encode(proposed), forKey: storageKey)
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
    public let origin: String
    public let capability: HTMLAppCapability
    public let scope: HTMLAppPermissionScope
    public let grantedAt: Date

    public init(
        appID: String,
        origin: String,
        capability: HTMLAppCapability,
        scope: HTMLAppPermissionScope,
        grantedAt: Date = Date()
    ) {
        self.appID = appID
        self.origin = origin
        self.capability = capability
        self.scope = scope
        self.grantedAt = grantedAt
    }
}

public struct HTMLAppPermissionRevocation: Equatable, Sendable {
    public let appID: String
    public let origin: String
    public let capability: HTMLAppCapability

    public init(appID: String, origin: String, capability: HTMLAppCapability) {
        self.appID = appID
        self.origin = origin
        self.capability = capability
    }
}

public extension Notification.Name {
    static let htmlAppPermissionDidRevoke = Notification.Name(
        "com.webbridgekit.html-app-runtime.permission-did-revoke"
    )
}

public enum HTMLAppPermissionRevocationNotification {
    public static let payloadKey = "revocation"
}

public final class HTMLAppPermissionLedger {
    public static let shared = HTMLAppPermissionLedger()

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
        origin: String,
        capability: HTMLAppCapability,
        scope: HTMLAppPermissionScope,
        grantedAt: Date = Date()
    ) -> HTMLAppPermissionGrant {
        let grant = HTMLAppPermissionGrant(
            appID: appID,
            origin: origin,
            capability: capability,
            scope: scope,
            grantedAt: grantedAt
        )
        let key = Self.key(appID: appID, origin: origin, capability: capability)

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

    public func grant(for appID: String, origin: String, capability: HTMLAppCapability) -> HTMLAppPermissionGrant? {
        let key = Self.key(appID: appID, origin: origin, capability: capability)
        lock.lock()
        defer { lock.unlock() }
        return sessionGrants[key] ?? persistentGrants[key]
    }

    public func grants(for appID: String) -> [HTMLAppPermissionGrant] {
        lock.lock()
        defer { lock.unlock() }
        return (Array(sessionGrants.values) + Array(persistentGrants.values))
            .filter { $0.appID == appID }
            .sorted {
                $0.origin == $1.origin
                    ? $0.capability.rawValue < $1.capability.rawValue
                    : $0.origin < $1.origin
            }
    }

    public func allGrants() -> [HTMLAppPermissionGrant] {
        lock.lock()
        defer { lock.unlock() }
        return (Array(sessionGrants.values) + Array(persistentGrants.values))
            .sorted {
                Self.key(appID: $0.appID, origin: $0.origin, capability: $0.capability)
                    < Self.key(appID: $1.appID, origin: $1.origin, capability: $1.capability)
            }
    }

    public func replaceAll(_ grants: [HTMLAppPermissionGrant]) throws {
        var proposedPersistent: [String: HTMLAppPermissionGrant] = [:]
        var proposedSession: [String: HTMLAppPermissionGrant] = [:]
        for grant in grants {
            let key = Self.key(appID: grant.appID, origin: grant.origin, capability: grant.capability)
            switch grant.scope {
            case .once: continue
            case .appSession: proposedSession[key] = grant
            case .always: proposedPersistent[key] = grant
            }
        }
        let data = try JSONEncoder().encode(proposedPersistent)
        lock.lock()
        defer { lock.unlock() }
        do {
            try storage.persist(data, forKey: storageKey)
        } catch {
            throw HTMLAppTrustRegistryError.persistenceFailed
        }
        persistentGrants = proposedPersistent
        sessionGrants = proposedSession
    }

    public func revoke(appID: String, origin: String, capability: HTMLAppCapability) {
        let key = Self.key(appID: appID, origin: origin, capability: capability)
        lock.lock()
        let removedSession = sessionGrants.removeValue(forKey: key)
        let removedPersistent = persistentGrants.removeValue(forKey: key)
        persistLocked()
        lock.unlock()

        guard removedSession != nil || removedPersistent != nil else { return }
        postRevocation(HTMLAppPermissionRevocation(
            appID: appID,
            origin: origin,
            capability: capability
        ))
    }

    public func revokeAll(appID: String) {
        lock.lock()
        var revokedByKey: [String: HTMLAppPermissionRevocation] = [:]
        for grant in sessionGrants.values where grant.appID == appID {
            revokedByKey[Self.key(
                appID: grant.appID,
                origin: grant.origin,
                capability: grant.capability
            )] = HTMLAppPermissionRevocation(
                appID: grant.appID,
                origin: grant.origin,
                capability: grant.capability
            )
        }
        for grant in persistentGrants.values where grant.appID == appID {
            revokedByKey[Self.key(
                appID: grant.appID,
                origin: grant.origin,
                capability: grant.capability
            )] = HTMLAppPermissionRevocation(
                appID: grant.appID,
                origin: grant.origin,
                capability: grant.capability
            )
        }
        sessionGrants = sessionGrants.filter { $0.value.appID != appID }
        persistentGrants = persistentGrants.filter { $0.value.appID != appID }
        persistLocked()
        lock.unlock()

        revokedByKey.values.forEach(postRevocation)
    }

    /// Ends only container-scoped grants for one managed PWA document context.
    /// Persistent `.always` grants and grants owned by another app/origin remain.
    public func revokeSessionGrants(appID: String, origin: String) {
        lock.lock()
        let revoked = sessionGrants.values.filter {
            $0.appID == appID && $0.origin == origin
        }
        sessionGrants = sessionGrants.filter {
            !($0.value.appID == appID && $0.value.origin == origin)
        }
        lock.unlock()

        revoked.forEach {
            postRevocation(HTMLAppPermissionRevocation(
                appID: $0.appID,
                origin: $0.origin,
                capability: $0.capability
            ))
        }
    }

    private func postRevocation(_ revocation: HTMLAppPermissionRevocation) {
        NotificationCenter.default.post(
            name: .htmlAppPermissionDidRevoke,
            object: self,
            userInfo: [HTMLAppPermissionRevocationNotification.payloadKey: revocation]
        )
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(persistentGrants) else { return }
        storage.set(data, forKey: storageKey)
    }

    private static func load(storage: HTMLAppRuntimeStorage, key: String) -> [String: HTMLAppPermissionGrant] {
        guard let data = storage.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: HTMLAppPermissionGrant].self, from: data)) ?? [:]
    }

    private static func key(appID: String, origin: String, capability: HTMLAppCapability) -> String {
        "\(appID)|\(origin)|\(capability.rawValue)"
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

        guard let origin = HTMLAppOrigin.canonicalOrigin(forDocumentURL: documentURL) else {
            return result(for: request, status: .denied)
        }

        if let grant = permissionLedger.grant(for: appID, origin: origin, capability: request.capability) {
            let nativeStatus = nativeAuthorizationProvider.authorizationStatus(for: request.capability)
            guard nativeStatus == .granted else {
                return result(
                    for: request,
                    status: nativeStatus == .denied ? .requiresSettings : nativeStatus,
                    scope: grant.scope,
                    authorizationLayer: .nativeSystem
                )
            }
            return result(for: request, status: .granted, scope: grant.scope)
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

        let permissionGrant = permissionLedger.grant(
            appID: appID,
            origin: pendingRequest.documentOrigin,
            capability: request.capability,
            scope: request.scope
        )
        let nativeStatus = nativeAuthorizationProvider.authorizationStatus(for: request.capability)
        guard nativeStatus == .granted else {
            return result(
                for: request,
                status: nativeStatus == .denied ? .requiresSettings : nativeStatus,
                scope: permissionGrant.scope,
                authorizationLayer: .nativeSystem
            )
        }
        return result(for: request, status: .granted, scope: permissionGrant.scope)
    }

    /// Removes an unresolved app-level request without creating a grant.
    /// Returns false when the request was already resolved or cancelled.
    @discardableResult
    public func cancelAuthorization(appID: String, requestID: String) -> Bool {
        let key = pendingKey(appID: appID, requestID: requestID)
        lock.lock()
        let removed = pendingRequests.removeValue(forKey: key)
        lock.unlock()
        return removed != nil
    }

    public func revokeAuthorization(appID: String, documentURL: URL, capability: HTMLAppCapability) {
        guard let origin = HTMLAppOrigin.canonicalOrigin(forDocumentURL: documentURL) else { return }
        permissionLedger.revoke(appID: appID, origin: origin, capability: capability)
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
