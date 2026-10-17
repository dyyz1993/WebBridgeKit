import Foundation

/// Server build identity exposed via `/health`. The shanbox deployment is a
/// manually synced source tree (no git remote), so this constant is the only
/// reliable way to tell WHICH server code a phone is talking to.
///
/// RULE: bump `current` on every behavioral server change that ships to
/// shanbox. When diagnosing any client/server mismatch, check this value
/// FIRST — a stale server explains many "the fix doesn't work" reports.
enum ServerVersion {
    /// - 2026.09.17-1: seeded the `dev.drel.data-template` offline template
    ///   app (push-data → rendered card; contract in
    ///   docs/api/drel-offline-template.md). No behavioral route change.
    /// - 2026.10.16-1: APNs requests preflight the 4 KB payload limit, log
    ///   Apple's rejection reason, and map positive `ttl` values to
    ///   `apns-expiration` for bounded offline storage.
    /// - 2026.09.15-1: full redeploy after the shanbox container was rebuilt
    ///   and the Swift server (with the gateway Ed25519 key and device
    ///   registrations) was lost. Ships a NEW gateway signing keypair —
    ///   existing app builds fail-closed on gateway manifests until they pin
    ///   the new public key. Push restores fail-closed (503) until the new
    ///   APNs provider key is configured.
    /// - 2026.08.29-1: exact key + APNs-token unregistration supports safe
    ///   Drel push-address rotation; copy payloads expose the native copy action.
    /// - 2026.08.27-1: registration storage accepts a short successor key for
    ///   the same APNs token while retaining legacy long-address delivery.
    /// - 2026.08.26-2: Drel 1.0 degrades unsupported critical-alert requests
    ///   to time-sensitive delivery; no unapproved mute/Focus bypass claim.
    /// - 2026.08.26-1: APNs alert delivery makes one request per endpoint;
    ///   only an explicit primary-host BadDeviceToken can try the other APNs
    ///   environment, preventing delayed duplicate alerts after a timeout.
    /// - 2026.08.20-2: APNs 429 backoff — never re-mint provider token on
    ///   TooManyProviderTokenUpdates (re-minting deepens the ~25 min penalty);
    ///   keep the cached token and fail fast.
    /// - 2026.08.20-1: empty-body Bark pushes (撤回/清角标), passive pushes
    ///   omit `aps.sound`, `/health` exposes this version.
    static let current = "2026.10.16-1"
}
