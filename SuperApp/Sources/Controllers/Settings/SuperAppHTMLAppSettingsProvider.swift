import UIKit
import WebBridgeKit

final class SuperAppHTMLAppSettingsProvider: HTMLAppSettingsViewControllerProviding {
    static let shared = SuperAppHTMLAppSettingsProvider()

    private let trustRegistry = HTMLAppTrustRegistry()
    private let permissionLedger = HTMLAppPermissionLedger.shared

    private init() {}

    func makeHTMLAppSettingsViewController(appID: String, documentURL: URL?) -> UIViewController? {
        guard let manifest = trustRegistry.manifest(for: appID),
              documentURL.map({ manifest.allows(documentURL: $0) }) ?? true else {
            return nil
        }
        return PWAAppPermissionViewController(
            manifest: manifest,
            permissionLedger: permissionLedger
        )
    }
}
