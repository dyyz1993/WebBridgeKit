import XCTest
@testable import WebBridgeKit

final class ManifestCacheManagerThreadSafetyTests: XCTestCase {

    private var manager: ManifestCacheManager!

    override func setUp() {
        super.setUp()
        manager = ManifestCacheManager.shared
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    func testConcurrentCacheHitIncrement() {
        let initialHits = manager.cacheHits
        let incrementCount = 100

        let expectation = XCTestExpectation(description: "concurrent hits")
        expectation.expectedFulfillmentCount = incrementCount

        for _ in 0..<incrementCount {
            DispatchQueue.global().async {
                self.manager.recordCacheHit()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
        XCTAssertEqual(manager.cacheHits, initialHits + Int64(incrementCount))
    }

    func testConcurrentCacheMissIncrement() {
        let initialMisses = manager.cacheMisses
        let incrementCount = 100

        let expectation = XCTestExpectation(description: "concurrent misses")
        expectation.expectedFulfillmentCount = incrementCount

        for _ in 0..<incrementCount {
            DispatchQueue.global().async {
                self.manager.recordCacheMiss()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
        XCTAssertEqual(manager.cacheMisses, initialMisses + Int64(incrementCount))
    }

    func testConcurrentMixedHitAndMiss() {
        let initialHits = manager.cacheHits
        let initialMisses = manager.cacheMisses
        let count = 50

        let hitExpectation = XCTestExpectation(description: "hits")
        hitExpectation.expectedFulfillmentCount = count
        let missExpectation = XCTestExpectation(description: "misses")
        missExpectation.expectedFulfillmentCount = count

        for _ in 0..<count {
            DispatchQueue.global().async {
                self.manager.recordCacheHit()
                hitExpectation.fulfill()
            }
            DispatchQueue.global().async {
                self.manager.recordCacheMiss()
                missExpectation.fulfill()
            }
        }

        wait(for: [hitExpectation, missExpectation], timeout: 5)
        XCTAssertEqual(manager.cacheHits, initialHits + Int64(count))
        XCTAssertEqual(manager.cacheMisses, initialMisses + Int64(count))
    }

    func testConcurrentGetStatsDuringWrites() {
        let writeExpectation = XCTestExpectation(description: "writes")
        writeExpectation.expectedFulfillmentCount = 100
        let readExpectation = XCTestExpectation(description: "reads")
        readExpectation.expectedFulfillmentCount = 100

        for _ in 0..<100 {
            DispatchQueue.global().async {
                self.manager.recordCacheHit()
                writeExpectation.fulfill()
            }
            DispatchQueue.global().async {
                let _ = self.manager.getStats()
                readExpectation.fulfill()
            }
        }

        wait(for: [writeExpectation, readExpectation], timeout: 5)
    }

    func testCacheStatsAreAccurateAfterHighContention() {
        manager.resetStats()
        let totalOps = 500

        let expectation = XCTestExpectation(description: "high contention")
        expectation.expectedFulfillmentCount = totalOps * 2

        for i in 0..<totalOps {
            DispatchQueue.global().async {
                self.manager.recordCacheHit()
                expectation.fulfill()
            }
            DispatchQueue.global().async {
                self.manager.recordCacheMiss()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10)

        let stats = manager.getStats()
        XCTAssertEqual(stats.cacheHits, totalOps)
        XCTAssertEqual(stats.cacheMisses, totalOps)
        XCTAssertEqual(stats.totalRequests, totalOps * 2)
    }

    func testResetStatsClearsCounters() {
        manager.recordCacheHit()
        manager.recordCacheHit()
        manager.recordCacheMiss()

        manager.resetStats()

        XCTAssertEqual(manager.cacheHits, 0)
        XCTAssertEqual(manager.cacheMisses, 0)
    }
}
