import XCTest
@testable import WebBridgeKit

final class CachePolicyTests: XCTestCase {

    func testExpirationPolicyNeverReturnsNil() {
        let policy = CacheExpirationPolicy.never
        XCTAssertNil(policy.timeInterval)
    }

    func testExpirationPolicySeconds() {
        let policy = CacheExpirationPolicy.seconds(60)
        XCTAssertEqual(policy.timeInterval, 60.0)
    }

    func testExpirationPolicyMinutes() {
        let policy = CacheExpirationPolicy.minutes(5)
        XCTAssertEqual(policy.timeInterval, 300.0)
    }

    func testExpirationPolicyMinutesZero() {
        let policy = CacheExpirationPolicy.minutes(0)
        XCTAssertEqual(policy.timeInterval, 0.0)
    }

    func testExpirationPolicyHours() {
        let policy = CacheExpirationPolicy.hours(2)
        XCTAssertEqual(policy.timeInterval, 7200.0)
    }

    func testExpirationPolicyHoursLarge() {
        let policy = CacheExpirationPolicy.hours(48)
        XCTAssertEqual(policy.timeInterval, 48 * 3600.0)
    }

    func testExpirationPolicyDays() {
        let policy = CacheExpirationPolicy.days(1)
        XCTAssertEqual(policy.timeInterval, 86400.0)
    }

    func testExpirationPolicyDaysSeven() {
        let policy = CacheExpirationPolicy.days(7)
        XCTAssertEqual(policy.timeInterval, 7 * 86400.0)
    }

    func testExpirationPolicyDaysZero() {
        let policy = CacheExpirationPolicy.days(0)
        XCTAssertEqual(policy.timeInterval, 0.0)
    }

    func testEvictionPolicyLRU() {
        let policy = CacheEvictionPolicy.leastRecentlyUsed
        XCTAssertEqual(policy, .leastRecentlyUsed)
    }

    func testEvictionPolicyLFU() {
        let policy = CacheEvictionPolicy.leastFrequentlyUsed
        XCTAssertEqual(policy, .leastFrequentlyUsed)
    }

    func testEvictionPolicyFIFO() {
        let policy = CacheEvictionPolicy.firstInFirstOut
        XCTAssertEqual(policy, .firstInFirstOut)
    }

    func testEvictionPolicySizeBased() {
        let policy = CacheEvictionPolicy.sizeBased(maxBytes: 1024)
        if case .sizeBased(let maxBytes) = policy {
            XCTAssertEqual(maxBytes, 1024)
        } else {
            XCTFail("Expected sizeBased")
        }
    }

    func testEvictionPolicySizeBasedLarge() {
        let policy = CacheEvictionPolicy.sizeBased(maxBytes: UInt64.max)
        if case .sizeBased(let maxBytes) = policy {
            XCTAssertEqual(maxBytes, UInt64.max)
        } else {
            XCTFail("Expected sizeBased")
        }
    }

    func testConfigurationDefault() {
        let config = CacheConfiguration.default
        XCTAssertEqual(config.maxSize, 1000)
        XCTAssertFalse(config.enableCompression)
        if case .hours(24) = config.expirationPolicy {} else {
            XCTFail("Expected hours(24)")
        }
        XCTAssertEqual(config.evictionPolicy, .leastRecentlyUsed)
    }

    func testConfigurationAggressive() {
        let config = CacheConfiguration.aggressive
        XCTAssertEqual(config.maxSize, 500)
        XCTAssertTrue(config.enableCompression)
        if case .hours(1) = config.expirationPolicy {} else {
            XCTFail("Expected hours(1)")
        }
    }

    func testConfigurationPersistent() {
        let config = CacheConfiguration.persistent
        XCTAssertEqual(config.maxSize, 2000)
        XCTAssertTrue(config.enableCompression)
        if case .days(7) = config.expirationPolicy {} else {
            XCTFail("Expected days(7)")
        }
    }

    func testConfigurationCustom() {
        let config = CacheConfiguration(
            expirationPolicy: .seconds(30),
            evictionPolicy: .firstInFirstOut,
            maxSize: 100,
            enableCompression: true
        )
        XCTAssertEqual(config.maxSize, 100)
        XCTAssertTrue(config.enableCompression)
        XCTAssertEqual(config.expirationPolicy.timeInterval, 30.0)
        XCTAssertEqual(config.evictionPolicy, .firstInFirstOut)
    }

    func testConfigurationCustomNoCompression() {
        let config = CacheConfiguration(
            expirationPolicy: .never,
            evictionPolicy: .sizeBased(maxBytes: 2048),
            maxSize: 0,
            enableCompression: false
        )
        XCTAssertNil(config.expirationPolicy.timeInterval)
        XCTAssertEqual(config.maxSize, 0)
        XCTAssertFalse(config.enableCompression)
    }
}
