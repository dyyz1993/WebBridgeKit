//
//  URLManaging.swift
//  WebBridgeKit
//
//  Created on 2025-05-12.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// Shared protocol for URL management operations.
/// Both URLFavoriteManager and PinnedURLManager can conform to this protocol
/// to provide a unified interface for add/remove/query/check operations.
public protocol URLManaging: AnyObject {

    /// Add a URL with an optional title.
    func addURL(_ url: URL, title: String?) throws

    /// Remove a URL.
    func removeURL(_ url: URL) throws

    /// Get all managed URLs.
    func getAllURLs() -> [URL]

    /// Check if a URL is a favorite/pinned.
    func isFavorite(_ url: URL) -> Bool
}
