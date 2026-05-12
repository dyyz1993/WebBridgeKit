import UIKit
import SnapKit
import WebBridgeKit

struct DiscoverSection {
    let title: String
    let items: [DiscoverItem]
}

struct DiscoverItem {
    let name: String
    let url: String
    let cacheStatus: CacheStatus
    var cacheSize: String
    var lastAccessed: String?
    var descriptionText: String?
    var bundleID: String?
    var version: String?
    var resourceCount: String?
    var cachedDate: String?
    var expiresText: String?
    var visitCount: String?
    var lastVisit: String?
    var sourceText: String?
    var pushToken: String?

    enum CacheStatus {
        case persistent
        case cached
        case needsUpdate
        case notCached

        var displayText: String {
            switch self {
            case .persistent: return L10n.tr("discover.badge.saved")
            case .cached: return L10n.tr("discover.badge.saved")
            case .needsUpdate: return L10n.tr("discover.badge.temp")
            case .notCached: return L10n.tr("discover.badge.none")
            }
        }

        var statusTypeText: String {
            switch self {
            case .persistent: return L10n.tr("discover.status.persistent")
            case .cached: return L10n.tr("discover.status.persistent")
            case .needsUpdate: return L10n.tr("discover.status.temporary")
            case .notCached: return L10n.tr("discover.status.not_cached")
            }
        }

        var color: UIColor {
            switch self {
            case .persistent: return ThemeTokens.Color.success
            case .cached: return ThemeTokens.Color.success
            case .needsUpdate: return ThemeTokens.Color.warning
            case .notCached: return ThemeTokens.Color.textSecondary
            }
        }

        init(from history: WebPageHistory) {
            if history.isCached {
                self = .cached
            } else {
                self = .notCached
            }
        }
    }
}
