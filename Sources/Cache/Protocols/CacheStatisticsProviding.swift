import Foundation

// MARK: - Cache Statistics Protocol

/// A unified protocol for cache statistics collection across all subsystems.
///
/// Each subsystem manager (e.g., manifest, image, resource cache) conforms to this protocol
/// so that `CacheStatsAggregator` can collect statistics generically without hardcoded
/// per-subsystem `collect*Stats()` methods.
///
/// Conforming types provide their `SubsystemID` and a `collectStats()` method that returns
/// a fully populated `SubsystemStats` snapshot for the dashboard.
public protocol CacheStatisticsProviding: AnyObject {

    /// The unique identifier of the subsystem this provider represents.
    var subsystemID: SubsystemID { get }

    /// Collect and return the current statistics snapshot for this subsystem.
    ///
    /// Implementations should compute entry count, total size, hit rate, and any
    /// subsystem-specific extra metrics at call time.
    ///
    /// - Returns: A `SubsystemStats` instance representing the current state.
    func collectStats() -> SubsystemStats
}
