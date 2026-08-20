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

/// The identity a permission grant is bound to. Grants never carry over when
/// any component changes: switching or removing a gateway, moving the app to a
/// different origin, or re-signing under another key all produce a different
/// subject and therefore cannot reuse an existing grant.
public struct HTMLAppPermissionSubject: Codable, Equatable, Hashable, Sendable {
    public let gatewayIdentity: String
    public let appID: String
    public let origin: String

    public init(gatewayIdentity: String, appID: String, origin: String) {
        self.gatewayIdentity = gatewayIdentity
        self.appID = appID
        self.origin = origin
    }

    /// True when the subject carries the full identity. Legacy persisted grants
    /// decoded without gateway/origin components fail this check and are pruned.
    public var isFullyIdentified: Bool {
        !gatewayIdentity.isEmpty && !appID.isEmpty && !origin.isEmpty
    }

    func storageKey(capability: HTMLAppCapability) -> String {
        "\(gatewayIdentity)|\(appID)|\(origin)|\(capability.rawValue)"
    }
}

public struct HTMLAppPermissionGrant: Codable, Equatable, Sendable {
    public let subject: HTMLAppPermissionSubject
    public let capability: HTMLAppCapability
    public let scope: HTMLAppPermissionScope
    public let grantedAt: Date

    public var appID: String { subject.appID }
    public var gatewayIdentity: String { subject.gatewayIdentity }
    public var origin: String { subject.origin }

    public init(
        subject: HTMLAppPermissionSubject,
        capability: HTMLAppCapability,
        scope: HTMLAppPermissionScope,
        grantedAt: Date = Date()
    ) {
        self.subject = subject
        self.capability = capability
        self.scope = scope
        self.grantedAt = grantedAt
    }

    private enum CodingKeys: String, CodingKey {
        case subject
        case appID = "appID"
        case capability
        case scope
        case grantedAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let subject = try values.decodeIfPresent(HTMLAppPermissionSubject.self, forKey: .subject) {
            self.subject = subject
        } else {
            // Legacy grant persisted before gateway/origin identity existed.
            self.subject = HTMLAppPermissionSubject(
                gatewayIdentity: "",
                appID: try values.decode(String.self, forKey: .appID),
                origin: ""
            )
        }
        capability = try values.decode(HTMLAppCapability.self, forKey: .capability)
        scope = try values.decode(HTMLAppPermissionScope.self, forKey: .scope)
        grantedAt = try values.decode(Date.self, forKey: .grantedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(subject, forKey: .subject)
        try container.encode(capability, forKey: .capability)
        try container.encode(scope, forKey: .scope)
        try container.encode(grantedAt, forKey: .grantedAt)
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
        let loaded = Self.load(storage: storage, key: storageKey)
        // Grants without full gateway/app/origin identity must not survive an
        // upgrade: they cannot be attributed to a trustable app identity.
        persistentGrants = loaded.filter { $0.value.subject.isFullyIdentified }
    }

    @discardableResult
    public func grant(
        subject: HTMLAppPermissionSubject,
        capability: HTMLAppCapability,
        scope: HTMLAppPermissionScope,
        grantedAt: Date = Date()
    ) -> HTMLAppPermissionGrant {
        let grant = HTMLAppPermissionGrant(
            subject: subject,
            capability: capability,
            scope: scope,
            grantedAt: grantedAt
        )
        let key = subject.storageKey(capability: capability)

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

    public func grant(
        for subject: HTMLAppPermissionSubject,
        capability: HTMLAppCapability
    ) -> HTMLAppPermissionGrant? {
        let key = subject.storageKey(capability: capability)
        lock.lock()
        defer { lock.unlock() }
        return sessionGrants[key] ?? persistentGrants[key]
    }

    public func grants(for subject: HTMLAppPermissionSubject) -> [HTMLAppPermissionGrant] {
        lock.lock()
        defer { lock.unlock() }
        return (Array(sessionGrants.values) + Array(persistentGrants.values))
            .filter { $0.subject == subject }
            .sorted { $0.capability.rawValue < $1.capability.rawValue }
    }

    public func grants(for appID: String) -> [HTMLAppPermissionGrant] {
        lock.lock()
        defer { lock.unlock() }
        return (Array(sessionGrants.values) + Array(persistentGrants.values))
            .filter { $0.subject.appID == appID }
            .sorted { $0.capability.rawValue < $1.capability.rawValue }
    }

    public func allGrants() -> [HTMLAppPermissionGrant] {
        lock.lock()
        defer { lock.unlock() }
        return (Array(sessionGrants.values) + Array(persistentGrants.values))
            .sorted { $0.subject.storageKey(capability: $0.capability) < $1.subject.storageKey(capability: $1.capability) }
    }

    // Compatibility helpers for hosts/tests that have not yet supplied a
    // gateway identity. New integrations should always use HTMLAppPermissionSubject.
    @discardableResult
    public func grant(
        appID: String,
        origin: String,
        capability: HTMLAppCapability,
        scope: HTMLAppPermissionScope,
        grantedAt: Date = Date()
    ) -> HTMLAppPermissionGrant {
        grant(
            subject: HTMLAppPermissionSubject(gatewayIdentity: "test-gateway", appID: appID, origin: origin),
            capability: capability,
            scope: scope,
            grantedAt: grantedAt
        )
    }

    public func grant(
        for appID: String,
        origin: String,
        capability: HTMLAppCapability
    ) -> HTMLAppPermissionGrant? {
        grant(
            for: HTMLAppPermissionSubject(gatewayIdentity: "test-gateway", appID: appID, origin: origin),
            capability: capability
        )
    }

    public func revoke(appID: String, origin: String, capability: HTMLAppCapability) {
        revoke(
            subject: HTMLAppPermissionSubject(gatewayIdentity: "test-gateway", appID: appID, origin: origin),
            capability: capability
        )
    }

    public func replaceAll(_ grants: [HTMLAppPermissionGrant]) throws {
        var proposedPersistent: [String: HTMLAppPermissionGrant] = [:]
        var proposedSession: [String: HTMLAppPermissionGrant] = [:]
        for grant in grants {
            let key = grant.subject.storageKey(capability: grant.capability)
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

    public func revoke(subject: HTMLAppPermissionSubject, capability: HTMLAppCapability) {
        let key = subject.storageKey(capability: capability)
        lock.lock()
        let removedSession = sessionGrants.removeValue(forKey: key)
        let removedPersistent = persistentGrants.removeValue(forKey: key)
        persistLocked()
        lock.unlock()

        guard removedSession != nil || removedPersistent != nil else { return }
        postRevocation(HTMLAppPermissionRevocation(
            appID: subject.appID,
            origin: subject.origin,
            capability: capability
        ))
    }

    public func revokeAll(appID: String) {
        lock.lock()
        defer { lock.unlock() }
        sessionGrants = sessionGrants.filter { $0.value.subject.appID != appID }
        persistentGrants = persistentGrants.filter { $0.value.subject.appID != appID }
        persistLocked()
    }

    /// Drops every grant issued under one gateway identity. Used when a gateway
    /// is removed; switching gateways also calls this for the previous identity.
    public func removeGrants(gatewayIdentity: String) {
        lock.lock()
        defer { lock.unlock() }
        sessionGrants = sessionGrants.filter { $0.value.subject.gatewayIdentity != gatewayIdentity }
        persistentGrants = persistentGrants.filter { $0.value.subject.gatewayIdentity != gatewayIdentity }
        persistLocked()
    }

    /// Clears "while using" grants for one container subject. Closing the PWA
    /// container must call this; backgrounding the app must not.
    public func endSession(for subject: HTMLAppPermissionSubject) {
        lock.lock()
        defer { lock.unlock() }
        sessionGrants = sessionGrants.filter { $0.value.subject != subject }
        persistLocked()
    }

    /// Drops grants for capabilities the current manifest no longer declares.
    /// Must run after a manifest update removes a capability.
    public func syncGrants(with manifest: HTMLAppManifest, gatewayIdentity: String, origin: String) {
        let prefix = "\(gatewayIdentity)|\(manifest.appID)|\(origin)|"
        lock.lock()
        func keep(_ entry: (key: String, value: HTMLAppPermissionGrant)) -> Bool {
            guard entry.key.hasPrefix(prefix) else { return true }
            return manifest.declares(entry.value.capability)
        }
        let revoked = (Array(sessionGrants.values) + Array(persistentGrants.values)).filter {
            $0.subject.gatewayIdentity == gatewayIdentity &&
                $0.subject.appID == manifest.appID &&
                $0.subject.origin == origin &&
                !manifest.declares($0.capability)
        }
        sessionGrants = sessionGrants.filter(keep)
        persistentGrants = persistentGrants.filter(keep)
        persistLocked()
        lock.unlock()
        revoked.forEach {
            postRevocation(HTMLAppPermissionRevocation(
                appID: $0.appID,
                origin: $0.origin,
                capability: $0.capability
            ))
        }
    }

    /// Ends only container-scoped grants for one managed PWA document context.
    /// Persistent `.always` grants and grants owned by another app/origin remain.
    public func revokeSessionGrants(subject: HTMLAppPermissionSubject) {
        lock.lock()
        let revoked = sessionGrants.values.filter {
            $0.subject == subject
        }
        sessionGrants = sessionGrants.filter {
            $0.value.subject != subject
        }
        persistLocked()
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
}

/// Adapts iOS system authorization for HTML app capabilities. The synchronous
/// status check gates the first-layer panel (denied/restricted short-circuit);
/// `requestAuthorization` triggers the actual system prompt after the user
/// accepts the WebBridgeKit panel.
public protocol HTMLAppNativeAuthorizationProviding: AnyObject {
    func authorizationStatus(for capability: HTMLAppCapability) -> HTMLAppCapabilityResult.Status
    func requestAuthorization(
        for capability: HTMLAppCapability,
        completion: @escaping (HTMLAppCapabilityResult.Status) -> Void
    )
}

extension HTMLAppNativeAuthorizationProviding {
    /// Providers without an interactive system prompt simply re-report status.
    public func requestAuthorization(
        for capability: HTMLAppCapability,
        completion: @escaping (HTMLAppCapabilityResult.Status) -> Void
    ) {
        completion(authorizationStatus(for: capability))
    }
}

public final class HTMLAppCapabilityGateway {
    private struct PendingRequest {
        let subject: HTMLAppPermissionSubject
        let capability: HTMLAppCapability
        let documentOrigin: String
    }

    public let permissionLedger: HTMLAppPermissionLedger
    private let trustRegistry: HTMLAppTrustRegistry
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

    public func manifest(for appID: String) -> HTMLAppManifest? {
        trustRegistry.manifest(for: appID)
    }

    /// First authorization pass. Returns `.notDetermined` with the `.htmlApp`
    /// layer only when a branded consent panel should be presented. The iOS
    /// system prompt happens later, inside `resolveUserConsent`, so the
    /// WebBridgeKit panel is always the first thing the user sees.
    public func requestAuthorization(
        subject: HTMLAppPermissionSubject,
        documentURL: URL,
        request: HTMLAppCapabilityRequest
    ) -> HTMLAppCapabilityResult {
        guard let manifest = trustRegistry.manifest(for: subject.appID) else {
            return result(for: request, status: .denied, failureReason: .appNotRegistered)
        }
        guard manifest.allows(documentURL: documentURL) else {
            return result(for: request, status: .denied, failureReason: .originMismatch)
        }
        guard case .accepted = request.validate(against: manifest) else {
            return result(for: request, status: .denied, failureReason: .undeclaredCapability)
        }
        guard let documentOrigin = HTMLAppOrigin.canonicalOrigin(forDocumentURL: documentURL),
              documentOrigin == subject.origin,
              subject.isFullyIdentified else {
            return result(for: request, status: .denied, failureReason: .originMismatch)
        }

        // A system-level refusal cannot be fixed by an in-app panel; surface it
        // directly so the host can offer the iOS Settings handoff instead.
        let nativeStatus = nativeAuthorizationProvider.authorizationStatus(for: request.capability)
        switch nativeStatus {
        case .denied:
            return result(
                for: request,
                status: .requiresSettings,
                failureReason: .systemDenied,
                authorizationLayer: .nativeSystem
            )
        case .restricted:
            return result(
                for: request,
                status: .restricted,
                failureReason: .systemRestricted,
                authorizationLayer: .nativeSystem
            )
        default:
            break
        }

        if let grant = permissionLedger.grant(for: subject, capability: request.capability) {
            return result(for: request, status: .granted, scope: grant.scope)
        }

        lock.lock()
        pendingRequests[pendingKey(subject: subject, requestID: request.id)] = PendingRequest(
            subject: subject,
            capability: request.capability,
            documentOrigin: documentOrigin
        )
        lock.unlock()
        return result(for: request, status: .notDetermined, authorizationLayer: .htmlApp)
    }

    /// Completes a pending consent request. On acceptance this triggers the
    /// iOS system authorization (which may show the system prompt) before the
    /// grant is recorded, so a system refusal never leaves a stale grant.
    public func resolveUserConsent(
        subject: HTMLAppPermissionSubject,
        documentURL: URL,
        request: HTMLAppCapabilityRequest,
        approvedScope: HTMLAppPermissionScope,
        granted: Bool,
        completion: @escaping (HTMLAppCapabilityResult) -> Void
    ) {
        let key = pendingKey(subject: subject, requestID: request.id)
        lock.lock()
        let pendingRequest = pendingRequests.removeValue(forKey: key)
        lock.unlock()

        guard granted else {
            completion(result(for: request, status: .denied, failureReason: .userCancelled, authorizationLayer: .htmlApp))
            return
        }

        guard let pendingRequest,
              pendingRequest.subject == subject,
              pendingRequest.capability == request.capability,
              pendingRequest.documentOrigin == HTMLAppOrigin.canonicalOrigin(forDocumentURL: documentURL) else {
            completion(result(for: request, status: .denied, failureReason: .userCancelled, authorizationLayer: .htmlApp))
            return
        }

        guard let manifest = trustRegistry.manifest(for: subject.appID),
              manifest.allows(documentURL: documentURL),
              case .accepted = request.validate(against: manifest) else {
            completion(result(for: request, status: .denied, failureReason: .originMismatch, authorizationLayer: .htmlApp))
            return
        }

        nativeAuthorizationProvider.requestAuthorization(for: request.capability) { [weak self] nativeStatus in
            guard let self else { return }
            switch nativeStatus {
            case .granted:
                let grant = self.permissionLedger.grant(
                    subject: subject,
                    capability: request.capability,
                    scope: approvedScope
                )
                completion(self.result(for: request, status: .granted, scope: grant.scope))
            case .denied:
                completion(self.result(
                    for: request,
                    status: .requiresSettings,
                    failureReason: .systemDenied,
                    authorizationLayer: .nativeSystem
                ))
            case .restricted:
                completion(self.result(
                    for: request,
                    status: .restricted,
                    failureReason: .systemRestricted,
                    authorizationLayer: .nativeSystem
                ))
            default:
                completion(self.result(
                    for: request,
                    status: .notDetermined,
                    failureReason: .systemNotDetermined,
                    authorizationLayer: .nativeSystem
                ))
            }
        }
    }

    /// Safely drops pending consent requests, e.g. when the PWA navigates to a
    /// different origin or the container is destroyed. The coordinator is
    /// responsible for completing any UI-side callbacks itself.
    public func cancelPendingRequests(subject: HTMLAppPermissionSubject) {
        lock.lock()
        defer { lock.unlock() }
        let prefix = "\(subject.gatewayIdentity)|\(subject.appID)|\(subject.origin)|"
        pendingRequests = pendingRequests.filter { !$0.key.hasPrefix(prefix) }
    }

    public func revokeAuthorization(subject: HTMLAppPermissionSubject, capability: HTMLAppCapability) {
        permissionLedger.revoke(subject: subject, capability: capability)
        cancelPendingRequests(subject: subject)
    }

    public func revokeAllAuthorizations(appID: String) {
        permissionLedger.revokeAll(appID: appID)
    }

    /// Ends the container session: clears "while using" grants and pending
    /// consent requests for this subject without touching persistent grants.
    public func endSession(subject: HTMLAppPermissionSubject) {
        permissionLedger.endSession(for: subject)
        cancelPendingRequests(subject: subject)
    }

    private func pendingKey(subject: HTMLAppPermissionSubject, requestID: String) -> String {
        "\(subject.gatewayIdentity)|\(subject.appID)|\(subject.origin)|\(requestID)"
    }

    private func result(
        for request: HTMLAppCapabilityRequest,
        status: HTMLAppCapabilityResult.Status,
        scope: HTMLAppPermissionScope? = nil,
        failureReason: HTMLAppCapabilityResult.FailureReason? = nil,
        authorizationLayer: HTMLAppCapabilityResult.AuthorizationLayer? = nil
    ) -> HTMLAppCapabilityResult {
        HTMLAppCapabilityResult(
            id: request.id,
            capability: request.capability,
            status: status,
            scope: scope,
            authorizationLayer: authorizationLayer,
            failureReason: failureReason
        )
    }
}
