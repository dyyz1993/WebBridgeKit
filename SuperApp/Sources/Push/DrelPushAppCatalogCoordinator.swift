//
//  DrelPushAppCatalogCoordinator.swift
//  SuperApp
//
//  Push is the activation path for a user-visible HTML app. The signed
//  gateway catalog may be refreshed to verify the target, but it must not be
//  rendered as a list of unsolicited applications.
//

import Foundation
import WebBridgeKit

final class DrelPushAppCatalogCoordinator {
    static let shared = DrelPushAppCatalogCoordinator()

    private let runtime = HTMLAppRuntimeCenter.shared
    private let gatewayRegistry = HTMLAppGatewayRegistry()
    private let receivedAppStore = HTMLAppPushActivationStore()
    private let lock = NSLock()
    private var isRefreshing = false
    private var pending: [(appID: String, route: String, completion: (Bool) -> Void)] = []

    private lazy var onboardingService = HTMLAppGatewayOnboardingService(
        gatewayRegistry: gatewayRegistry,
        trustRegistry: runtime.trustRegistry,
        permissionLedger: runtime.permissionLedger
    )

    private init() {}

    /// Makes an app visible only after its signed manifest permits the route
    /// carried in a received push. Completion always returns on the main queue.
    func activateIfTrusted(appID: String, route: String, completion: @escaping (Bool) -> Void = { _ in }) {
        guard !appID.isEmpty, !route.isEmpty else {
            finish(completion, accepted: false)
            return
        }
        if routeIsTrusted(appID: appID, route: route) {
            receivedAppStore.activate(appID)
            finish(completion, accepted: true)
            return
        }

        lock.lock()
        pending.append((appID, route, completion))
        let shouldRefresh = !isRefreshing
        isRefreshing = true
        lock.unlock()
        guard shouldRefresh else { return }

        // Drel-owned app identifiers are signed by the configuration-free
        // official catalog. Push transport is deliberately independent: a
        // self-hosted/direct channel may deliver this notification, but it
        // must not replace the public trust source for a Drel app.
        let gateway = gateway(for: appID)
        onboardingService.validate(gateway) { [weak self] result in
            guard let self else { return }
            if case .success(let report) = result {
                try? self.onboardingService.activate(report)
            }
            self.finishPending()
        }
    }

    func activateIfTrusted(userInfo: [AnyHashable: Any]) {
        guard let appID = (userInfo["appId"] as? String) ?? (userInfo["appid"] as? String),
              let route = userInfo["route"] as? String else { return }
        activateIfTrusted(appID: appID, route: route)
    }

    func activateIfTrusted(userInfo: [String: Any]) {
        activateIfTrusted(userInfo: Dictionary(uniqueKeysWithValues: userInfo.map { (AnyHashable($0.key), $0.value) }))
    }

    private func finishPending() {
        lock.lock()
        let work = pending
        pending.removeAll()
        isRefreshing = false
        lock.unlock()

        for item in work {
            let accepted = routeIsTrusted(appID: item.appID, route: item.route)
            if accepted {
                receivedAppStore.activate(item.appID)
            }
            finish(item.completion, accepted: accepted)
        }
    }

    private func routeIsTrusted(appID: String, route: String) -> Bool {
        guard let manifest = runtime.trustRegistry.manifest(for: appID),
              manifest.allows(route: route) else { return false }
        return true
    }

    private func gateway(for appID: String) -> HTMLAppGatewayConfiguration {
        if appID.hasPrefix("dev.drel.") {
            return HTMLAppGatewayDefaults.official
        }
        return gatewayRegistry.activeGateway() ?? HTMLAppGatewayDefaults.official
    }

    private func finish(_ completion: @escaping (Bool) -> Void, accepted: Bool) {
        DispatchQueue.main.async {
            completion(accepted)
        }
    }
}
