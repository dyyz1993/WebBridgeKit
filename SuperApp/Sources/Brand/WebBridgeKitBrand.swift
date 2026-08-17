import UIKit

/// Central access point for the WebBridgeKit product mark.
///
/// Functional UI icons remain Lucide icons. This asset is reserved for
/// product identity surfaces such as About, Settings, notifications, and
/// empty app-icon fallbacks.
enum WebBridgeKitBrand {
    static let imageName = "WebBridgeKitBrand"

    static var image: UIImage? {
        UIImage(named: imageName)?.withRenderingMode(.alwaysOriginal)
    }
}
