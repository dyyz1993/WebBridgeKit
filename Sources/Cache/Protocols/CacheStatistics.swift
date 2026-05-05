import Foundation

/// Cache statistics for monitoring cache performance
public struct CacheStatistics: Codable, Sendable {
    public var hitCount: UInt64
    public var missCount: UInt64
    public var evictionCount: UInt64
    public var totalEntries: UInt64
    public var totalSizeBytes: UInt64
    public var averageAccessTime: TimeInterval
    public var lastUpdated: Date

    public init() {
        self.hitCount = 0
        self.missCount = 0
        self.evictionCount = 0
        self.totalEntries = 0
        self.totalSizeBytes = 0
        self.averageAccessTime = 0
        self.lastUpdated = Date()
    }

    public var totalRequests: UInt64 {
        hitCount + missCount
    }

    public var hitRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(hitCount) / Double(totalRequests)
    }

    public var missRate: Double {
        1.0 - hitRate
    }

    public mutating func recordHit() {
        hitCount += 1
        lastUpdated = Date()
    }

    public mutating func recordMiss() {
        missCount += 1
        lastUpdated = Date()
    }

    public mutating func recordEviction() {
        evictionCount += 1
        lastUpdated = Date()
    }

    public mutating func updateAccessTime(_ time: TimeInterval) {
        let total = Double(totalRequests)
        averageAccessTime = ((averageAccessTime * total) + time) / (total + 1)
    }
}
