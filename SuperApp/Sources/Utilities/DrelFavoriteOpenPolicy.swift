import Foundation
import UIKit
import WebBridgeKit

/// The single presentation rule for opening a stored URL (favorite or recent
/// item). A URL that resolves to a registered HTML app reopens that app the
/// way it was experienced — immersive with the manifest loader — so favoriting
/// an app and reopening it from the favorites page or the home grid stays one
/// continuous app experience. Everything else remains a normal web page.
enum DrelFavoriteOpenPolicy {

    static func open(_ url: URL, from viewController: UIViewController?) {
        if let manifest = HTMLAppRuntimeCenter.shared.trustRegistry.registeredApp(matching: url),
           let entry = URL(string: manifest.startURL) {
            WebBrowserManager.shared.openBrowser(
                url: entry,
                params: WebBrowserParams(displayMode: .immersive, useManifestLoader: true),
                from: viewController
            )
            return
        }
        WebBrowserManager.shared.openBrowser(
            url: url,
            params: WebBrowserParams(displayMode: .normal),
            from: viewController
        )
    }
}
