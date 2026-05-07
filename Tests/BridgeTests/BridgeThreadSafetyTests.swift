import XCTest
@testable import WebBridgeKit

final class BridgeThreadSafetyTests: XCTestCase {

    private var registry: HandlerRegistry!

    override func setUp() {
        super.setUp()
        registry = HandlerRegistry.shared
    }

    func testConcurrentRegistrationFromMultipleThreadsDoesNotCrash() {
        let expectation = expectation(description: "All registrations complete")
        let threadCount = 50
        let registrationsPerThread = 20

        DispatchQueue.concurrentPerform(iterations: threadCount) { threadIndex in
            for i in 0..<registrationsPerThread {
                let action = "concurrent_t\(threadIndex)_i\(i)_threadSafe"
                let meta = HandlerMeta(
                    action: action,
                    category: .debug,
                    displayName: "Thread \(threadIndex) Item \(i)",
                    description: "Concurrent test handler"
                )
                registry.register(meta)
            }
        }

        expectation.fulfill()
        waitForExpectations(timeout: 10)

        let allHandlers = registry.allHandlers()
        let concurrentHandlers = allHandlers.filter { $0.action.hasSuffix("_threadSafe") }
        XCTAssertEqual(concurrentHandlers.count, threadCount * registrationsPerThread)
    }

    func testConcurrentReadAndWriteDoesNotCrash() {
        let writeExpectation = expectation(description: "Writes complete")
        let readExpectation = expectation(description: "Reads complete")

        let writeCount = 100
        let readCount = 200

        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<writeCount {
                let meta = HandlerMeta(
                    action: "rw_write_\(i)",
                    category: .system,
                    displayName: "Write \(i)",
                    description: "Write test"
                )
                self.registry.register(meta)
            }
            writeExpectation.fulfill()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<readCount {
                _ = self.registry.allHandlers()
                _ = self.registry.handler(for: "rw_write_0")
                _ = self.registry.isRegistered(action: "rw_write_0")
                _ = self.registry.count
                _ = self.registry.handlers(category: .system)
            }
            readExpectation.fulfill()
        }

        waitForExpectations(timeout: 10)

        XCTAssertTrue(registry.isRegistered(action: "rw_write_0"))
        XCTAssertTrue(registry.isRegistered(action: "rw_write_99"))
    }

    func testConcurrentBatchRegisterDoesNotLoseEntries() {
        let expectation = expectation(description: "Batch registrations complete")
        let batchCount = 30

        DispatchQueue.concurrentPerform(iterations: batchCount) { batchIndex in
            var metas: [HandlerMeta] = []
            for i in 0..<10 {
                metas.append(HandlerMeta(
                    action: "batch_concurrent_\(batchIndex)_\(i)",
                    category: .cache,
                    displayName: "Batch \(batchIndex) \(i)",
                    description: "Batch concurrent test"
                ))
            }
            self.registry.register(metas)
        }

        expectation.fulfill()
        waitForExpectations(timeout: 10)

        let allHandlers = registry.allHandlers()
        let batchHandlers = allHandlers.filter { $0.action.hasPrefix("batch_concurrent_") }
        XCTAssertEqual(batchHandlers.count, batchCount * 10)
    }

    func testConcurrentCategoryQueryReturnsConsistentResults() {
        for i in 0..<5 {
            registry.register(HandlerMeta(
                action: "catConcurrent_hw_\(i)",
                category: .hardware,
                displayName: "HW \(i)",
                description: "HW test"
            ))
            registry.register(HandlerMeta(
                action: "catConcurrent_sys_\(i)",
                category: .system,
                displayName: "SYS \(i)",
                description: "SYS test"
            ))
        }

        let expectation = expectation(description: "Category queries complete")
        let queryCount = 50
        var results: [[HandlerMeta]] = []
        let lock = NSLock()

        DispatchQueue.concurrentPerform(iterations: queryCount) { _ in
            let hw = self.registry.handlers(category: .hardware)
            let sys = self.registry.handlers(category: .system)
            lock.lock()
            results.append(hw + sys)
            lock.unlock()
        }

        expectation.fulfill()
        waitForExpectations(timeout: 10)

        for result in results {
            let hwResults = result.filter { $0.category == .hardware }
            let sysResults = result.filter { $0.category == .system }
            XCTAssertGreaterThanOrEqual(hwResults.count, 5)
            XCTAssertGreaterThanOrEqual(sysResults.count, 5)
        }
    }
}
