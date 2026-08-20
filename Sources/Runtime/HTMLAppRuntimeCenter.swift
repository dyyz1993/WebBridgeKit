//
//  HTMLAppRuntimeCenter.swift
//  WebBridgeKit
//
//  Composition root sharing one runtime instance between the bridge, the
//  permission coordinator, and host permission management screens.
//

import Foundation

public extension Notification.Name {
    /// Posted after a capability authorization is revoked. `userInfo` carries
    /// the revoked `HTMLAppCapability` under `capability`. Continuous sessions
    /// (for example an active Bluetooth scan) must stop when this arrives.
    static let htmlAppPermissionDidRevoke = Notification.Name("com.webbridgekit.html-app.permission-did-revoke")
}

public final class HTMLAppRuntimeCenter {

    public static let shared = HTMLAppRuntimeCenter()

    public let trustRegistry: HTMLAppTrustRegistry
    public let permissionLedger: HTMLAppPermissionLedger
    public let systemPermissionAdapter: HTMLAppSystemPermissionAdapter
    public let gateway: HTMLAppCapabilityGateway
    public let permissionCoordinator: HTMLAppPermissionCoordinator

    /// Identity of the currently active gateway (gateway id plus signing key
    /// id). Hosts must update it when the gateway configuration changes and
    /// remove stale grants via `permissionLedger.removeGrants(gatewayIdentity:)`.
    public var gatewayIdentity: String {
        didSet {
            guard gatewayIdentity != oldValue else { return }
            if !oldValue.isEmpty {
                permissionLedger.removeGrants(gatewayIdentity: oldValue)
            }
        }
    }

    public init(
        storage: HTMLAppRuntimeStorage = HTMLAppUserDefaultsStorage(),
        presenter: HTMLAppPermissionPromptPresenting = HTMLAppPermissionPanelPresenter(),
        gatewayIdentity: String = ""
    ) {
        let registry = HTMLAppTrustRegistry(storage: storage)
        let ledger = HTMLAppPermissionLedger(storage: storage)
        let adapter = HTMLAppSystemPermissionAdapter()
        let capabilityGateway = HTMLAppCapabilityGateway(
            trustRegistry: registry,
            permissionLedger: ledger,
            nativeAuthorizationProvider: adapter
        )
        self.trustRegistry = registry
        self.permissionLedger = ledger
        self.systemPermissionAdapter = adapter
        self.gateway = capabilityGateway
        self.permissionCoordinator = HTMLAppPermissionCoordinator(
            gateway: capabilityGateway,
            presenter: presenter
        )
        self.gatewayIdentity = gatewayIdentity
    }

    /// Builds the permission subject for one HTML app under the active
    /// gateway. Returns nil when the gateway identity is not configured yet.
    public func subject(appID: String, origin: String) -> HTMLAppPermissionSubject? {
        guard !gatewayIdentity.isEmpty else { return nil }
        return HTMLAppPermissionSubject(gatewayIdentity: gatewayIdentity, appID: appID, origin: origin)
    }

    /// Convenience for registering a manifest and pruning grants for
    /// capabilities the new manifest no longer declares.
    public func register(
        _ manifest: HTMLAppManifest,
        trustPolicy: HTMLAppTrustPolicy = .development
    ) throws {
        try trustRegistry.register(manifest, trustPolicy: trustPolicy)
        let origin = HTMLAppOrigin.canonicalOrigin(forDocumentURL: URL(string: manifest.startURL) ?? URL(fileURLWithPath: "/"))
        if let origin, let subject = subject(appID: manifest.appID, origin: origin) {
            permissionLedger.syncGrants(with: manifest, gatewayIdentity: subject.gatewayIdentity, origin: subject.origin)
        }
    }

    /// Revokes one capability and notifies continuous sessions to stop.
    public func revokeAuthorization(subject: HTMLAppPermissionSubject, capability: HTMLAppCapability) {
        gateway.revokeAuthorization(subject: subject, capability: capability)
        NotificationCenter.default.post(
            name: .htmlAppPermissionDidRevoke,
            object: nil,
            userInfo: ["capability": capability]
        )
    }

    /// Revokes every authorization for one app (uninstall path).
    public func revokeAllAuthorizations(appID: String) {
        gateway.revokeAllAuthorizations(appID: appID)
    }

    /// Ends one container session: clears "while using" grants and pending
    /// prompts without touching "always" grants.
    public func endSession(subject: HTMLAppPermissionSubject) {
        permissionCoordinator.cancelPendingRequests(subject: subject)
        gateway.endSession(subject: subject)
    }
}
