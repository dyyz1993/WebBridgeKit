//
//  HTMLAppPushActivationStore.swift
//  WebBridgeKit
//
//  A signed gateway catalog is trust material, not a user's application list.
//  An app is shown by the host only after a trusted push has actually targeted
//  it, so catalog additions never appear as unsolicited tiles.
//

import Foundation

public final class HTMLAppPushActivationStore {
    public static let defaultStorageKey = "com.webbridgekit.html-app-runtime.push-activated-app-ids"

    private let defaults: UserDefaults
    private let storageKey: String
    private let lock = NSLock()

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = HTMLAppPushActivationStore.defaultStorageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    public func contains(_ appID: String) -> Bool {
        activeAppIDs().contains(appID)
    }

    public func activeAppIDs() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(defaults.stringArray(forKey: storageKey) ?? [])
    }

    /// Records only the stable app id. The current signed manifest remains the
    /// source of display name, icon, routes and offline-package metadata.
    public func activate(_ appID: String) {
        let normalized = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        lock.lock()
        var values = Set(defaults.stringArray(forKey: storageKey) ?? [])
        let inserted = values.insert(normalized).inserted
        if inserted {
            defaults.set(values.sorted(), forKey: storageKey)
        }
        lock.unlock()
        if inserted {
            NotificationCenter.default.post(name: .htmlAppPushDidActivate, object: self, userInfo: ["appID": normalized])
        }
    }

    public func deactivate(_ appID: String) {
        lock.lock()
        var values = Set(defaults.stringArray(forKey: storageKey) ?? [])
        guard values.remove(appID) != nil else {
            lock.unlock()
            return
        }
        defaults.set(values.sorted(), forKey: storageKey)
        lock.unlock()
    }
}

public extension Notification.Name {
    static let htmlAppPushDidActivate = Notification.Name("com.webbridgekit.html-app.push-did-activate")
}
