import UIKit
import WebBridgeKit

final class SuperAppHTMLAppSettingsProvider: HTMLAppSettingsViewControllerProviding {
    static let shared = SuperAppHTMLAppSettingsProvider()

    private let runtime = HTMLAppRuntimeCenter.shared

    private init() {}

    func makeHTMLAppSettingsViewController(appID: String, documentURL: URL?) -> UIViewController? {
        #if DREL_CONTAINER_ONLY
        // Store build: remote pages have no native Bridge or capability grants.
        return nil
        #else
        guard let manifest = runtime.trustRegistry.manifest(for: appID),
              documentURL.map({ manifest.allows(documentURL: $0) }) ?? true else {
            return nil
        }
        return PWAPermissionCenterViewController(appID: manifest.appID)
        #endif
    }
}
