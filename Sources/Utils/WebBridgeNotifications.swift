//
//  WebBridgeNotifications.swift
//  WebBridgeKit
//
//  Type-safe notification names to avoid string literal errors
//

import Foundation

public extension Notification.Name {
    // MARK: - Manifest Cache Notifications

    /// Posted when manifest cache is updated
    static let manifestCacheDidUpdate = Notification.Name("ManifestCacheDidUpdate")

    /// Posted when manifest cache is cleared
    static let manifestCacheDidClear = Notification.Name("ManifestCacheDidClear")

    // MARK: - Browser Notifications

    /// Posted when browser is opened
    static let browserDidOpen = Notification.Name("WebBrowserDidOpen")

    /// Posted when browser is closed
    static let browserDidClose = Notification.Name("WebBrowserDidClose")

    // MARK: - History Notifications

    /// Posted when page history is updated
    static let historyDidUpdate = Notification.Name("WebPageHistoryDidUpdate")

    /// Posted when page history is cleared
    static let historyDidClear = Notification.Name("WebPageHistoryDidClear")

    // MARK: - Favorite Notifications

    /// Posted when URL favorites are updated
    static let favoriteDidUpdate = Notification.Name("URLFavoriteDidUpdate")

    /// Posted when a URL favorite is removed
    static let favoriteDidRemove = Notification.Name("URLFavoriteDidRemove")

    // MARK: - Cache Statistics Notifications

    /// Posted when cache size changes
    static let cacheSizeDidChange = Notification.Name("WebCacheSizeDidChange")

    // MARK: - QR Scanner Notifications

    /// Posted when QR scanner scans a URL
    static let qrScannerDidScanURL = Notification.Name("QRScannerDidScanURL")

    // MARK: - Debug Notifications

    /// Posted when debug label should be updated
    static let updateDebugLabel = Notification.Name("UpdateDebugLabel")

    // MARK: - Message Notifications

    /// Posted when a push message is received
    static let didReceivePushMessage = Notification.Name("didReceivePushMessage")

    // MARK: - Cache Hit Notifications

    /// Posted when manifest cache is hit
    static let manifestCacheHit = Notification.Name("com.webbridgekit.manifest-cache.hit")

    // MARK: - Resource Delivery Notifications

    /// Posted when a resource is delivered
    static let resourceDelivered = Notification.Name("wb-resource-delivered")

    // MARK: - Debug Log Notifications

    /// Posted for debug logging
    static let resourceLogNotification = Notification.Name("WebBridgeDebugLog")

    // MARK: - Automation Test Notifications

    /// Posted when automation test should open URL
    static let automationTestOpenURL = Notification.Name("AutomationTestOpenURL")
}

public extension Notification.Name {
    // MARK: - UserInfo Keys

    /// Type-safe keys for notification userInfo dictionaries
    struct UserInfoKey {
        /// Page key for history/favorites
        public static let pageKey = "pageKey"

        /// URL string
        public static let url = "url"

        /// Cache size (in bytes)
        public static let size = "size"

        /// Page title
        public static let title = "title"

        /// Error object
        public static let error = "error"

        /// Timestamp
        public static let timestamp = "timestamp"

        /// Success flag
        public static let success = "success"
    }
}
