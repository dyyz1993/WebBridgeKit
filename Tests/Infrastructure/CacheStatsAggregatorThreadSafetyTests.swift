import XCTest
@testable import WebBridgeKit

final class CacheStatsAggregatorThreadSafetyTests: XCTestCase {

    private var aggregator: CacheStatsAggregator!

    override func setUp() {
        super.setUp()
        aggregator = CacheStatsAggregator.shared
    }

    override func tearDown() {
        aggregator = nil
        super.tearDown()
    }

    func testConcurrentProviderRegistration() {
        let expectation = XCTestExpectation(description: "concurrent registration")
        expectation.expectedFulfillmentCount = 100

        for i in 0..<100 {
            DispatchQueue.global().async {
                let provider = StubStatsProvider(id: .manifestCache, suffix: i)
                self.aggregator.registerProvider(provider)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
    }

    func testConcurrentProviderUnregistration() {
        for id in SubsystemID.allCases {
            aggregator.registerProvider(StubStatsProvider(id: id, suffix: 0))
        }

        let expectation = XCTestExpectation(description: "concurrent unregistration")
        expectation.expectedFulfillmentCount = SubsystemID.allCases.count

        for id in SubsystemID.allCases {
            DispatchQueue.global().async {
                self.aggregator.unregisterProvider(for: id)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
    }

    func testConcurrentRegisterAndUnregister() {
        let expectation = XCTestExpectation(description: "mixed register/unregister")
        expectation.expectedFulfillmentCount = 200

        for i in 0..<100 {
            DispatchQueue.global().async {
                let provider = StubStatsProvider(id: .manifestCache, suffix: i)
                self.aggregator.registerProvider(provider)
                expectation.fulfill()
            }
            DispatchQueue.global().async {
                self.aggregator.unregisterProvider(for: .manifestCache)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
    }

    func testConcurrentSyncAggregate() {
        let expectation = XCTestExpectation(description: "concurrent syncAggregate")
        expectation.expectedFulfillmentCount = 50

        for _ in 0..<50 {
            DispatchQueue.global().async {
                let _ = self.aggregator.syncAggregate()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
    }

    func testConcurrentRegisterWhileAggregating() {
        let regExpectation = XCTestExpectation(description: "register")
        regExpectation.expectedFulfillmentCount = 50
        let aggExpectation = XCTestExpectation(description: "aggregate")
        aggExpectation.expectedFulfillmentCount = 50

        for i in 0..<50 {
            DispatchQueue.global().async {
                let provider = StubStatsProvider(id: .webResourceCache, suffix: i)
                self.aggregator.registerProvider(provider)
                regExpectation.fulfill()
            }
            DispatchQueue.global().async {
                let _ = self.aggregator.syncAggregate()
                aggExpectation.fulfill()
            }
        }

        wait(for: [regExpectation, aggExpectation], timeout: 5)
    }

    func testCollectStatsDuringProviderSwap() {
        let providerA = StubStatsProvider(id: .systemURLCache, suffix: 0)
        let providerB = StubStatsProvider(id: .systemURLCache, suffix: 1)

        let expectation = XCTestExpectation(description: "swap + collect")
        expectation.expectedFulfillmentCount = 200

        for i in 0..<100 {
            DispatchQueue.global().async {
                let provider = i % 2 == 0 ? providerA : providerB
                self.aggregator.registerProvider(provider)
                expectation.fulfill()
            }
            DispatchQueue.global().async {
                let _ = self.aggregator.collectStats(for: .systemURLCache)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
    }
}

private final class StubStatsProvider: CacheStatisticsProviding {
    let subsystemID: SubsystemID
    private let suffix: Int

    init(id: SubsystemID, suffix: Int) {
        self.subsystemID = id
        self.suffix = suffix
    }

    func collectStats() -> SubsystemStats {
        SubsystemStats(
            id: subsystemID,
            totalEntries: suffix,
            totalSize: Int64(suffix),
            status: .active
        )
    }
}
