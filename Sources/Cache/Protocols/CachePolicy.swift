import Foundation

/// Cache expiration policy
public enum CacheExpirationPolicy: Sendable {
    case never
    case seconds(TimeInterval)
    case minutes(Int)
    case hours(Int)
    case days(Int)
    
    public var timeInterval: TimeInterval? {
        switch self {
        case .never:
            return nil
        case .seconds(let interval):
            return interval
        case .minutes(let minutes):
            return TimeInterval(minutes * 60)
        case .hours(let hours):
            return TimeInterval(hours * 3600)
        case .days(let days):
            return TimeInterval(days * 86400)
        }
    }
}

/// Cache eviction policy when cache is full
public enum CacheEvictionPolicy: Sendable {
    case leastRecentlyUsed
    case leastFrequentlyUsed
    case firstInFirstOut
    case sizeBased(maxBytes: UInt64)
}

/// Cache configuration
public struct CacheConfiguration: Sendable {
    public let expirationPolicy: CacheExpirationPolicy
    public let evictionPolicy: CacheEvictionPolicy
    public let maxSize: Int
    public let enableCompression: Bool
    
    public init(
        expirationPolicy: CacheExpirationPolicy = .hours(24),
        evictionPolicy: CacheEvictionPolicy = .leastRecentlyUsed,
        maxSize: Int = 1000,
        enableCompression: Bool = false
    ) {
        self.expirationPolicy = expirationPolicy
        self.evictionPolicy = evictionPolicy
        self.maxSize = maxSize
        self.enableCompression = enableCompression
    }
    
    public static let `default` = CacheConfiguration()
    public static let aggressive = CacheConfiguration(
        expirationPolicy: .hours(1),
        evictionPolicy: .leastRecentlyUsed,
        maxSize: 500,
        enableCompression: true
    )
    public static let persistent = CacheConfiguration(
        expirationPolicy: .days(7),
        evictionPolicy: .leastFrequentlyUsed,
        maxSize: 2000,
        enableCompression: true
    )
}
