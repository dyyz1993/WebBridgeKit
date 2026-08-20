import UIKit
import WebBridgeKit

final class SuperAppHTMLAppSettingsProvider: HTMLAppSettingsViewControllerProviding {
    static let shared = SuperAppHTMLAppSettingsProvider()

    private let runtime = HTMLAppRuntimeCenter.shared

    private init() {}

    func makeHTMLAppSettingsViewController(appID: String, documentURL: URL?) -> UIViewController? {
        guard let manifest = runtime.trustRegistry.manifest(for: appID),
              documentURL.map({ manifest.allows(documentURL: $0) }) ?? true else {
            return nil
        }
        return PWAPermissionCenterViewController(appID: manifest.appID)
    }
}
