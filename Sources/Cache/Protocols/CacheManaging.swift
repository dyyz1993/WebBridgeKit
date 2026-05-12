import Foundation

// MARK: - Cache Managing Protocol

/// A base protocol for cache managers that share common CRUD operations.
///
/// Provides a unified interface for clearing, measuring, and counting cached data
/// across all cache subsystems (e.g., `WebCompressedCacheStore`, `WebResourceCacheManager`,
/// `SystemURLCacheManager`, `WebPageOfflineCacheManager`, `CacheManager`,
/// `ManifestCacheManager`, `ManifestStore`).
///
/// Conforming types implement these methods so that higher-level orchestration code
/// (e.g., cache cleanup, dashboard display) can operate generically without
/// knowing the concrete cache backend.
public protocol CacheManaging: AnyObject {

    /// Clear all cached data.
    ///
    /// Removes every entry from the underlying cache store.
    /// Implementations should ensure this operation is safe to call on any thread
    /// and that it releases all associated resources (files, database rows, memory entries).
    func clearAll()

    /// Get the total cache size in bytes.
    ///
    /// Computes the cumulative size of all cached entries, including any metadata
    /// or index overhead maintained by the backing store.
    ///
    /// - Returns: Total size in bytes as `Int64`.
    func getSize() -> Int64

    /// Get the number of cached entries.
    ///
    /// Returns the count of individual items currently stored in the cache.
    ///
    /// - Returns: Entry count as `Int`.
    func getEntryCount() -> Int
}
