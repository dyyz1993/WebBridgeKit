import XCTest
@testable import WebBridgeKit

final class CachePerformanceTests: XCTestCase {
    var memoryCache: MemoryCache<String, String>!
    var diskCache: DiskCache!
    var hybridCache: HybridCache<String>!
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("PerfDiskCache-\(UUID().uuidString)")

    override func setUp() async throws {
        try await super.setUp()
        memoryCache = MemoryCache<String, String>(configuration: .default)
        try? FileManager.default.removeItem(at: tempDirectory)
        diskCache = try DiskCache(
            directoryName: "PerfDiskCache",
            configuration: .default
        )
        hybridCache = try HybridCache<String>(
            memoryConfig: CacheConfiguration(maxSize: 1000),
            diskConfig: CacheConfiguration(maxSize: 1000),
            diskDirectoryName: "PerfHybridCache-\(UUID().uuidString)"
        )
    }

    override func tearDown() async throws {
        await memoryCache.clearAll()
        await diskCache.clearAll()
        await hybridCache.clearAll()
        try? FileManager.default.removeItem(at: tempDirectory)
        try await super.tearDown()
    }

    func testMemoryCacheWritePerformance() async throws {
        let count = 1000
        self.measure {
            let sem = DispatchSemaphore(value: 0)
            Task {
                for i in 0..<count {
                    await memoryCache.set("value-\(i)", for: "key-\(i)", expiration: nil)
                }
                sem.signal()
            }
            sem.wait()
        }
    }

    func testMemoryCacheReadPerformance() async throws {
        let count = 1000
        for i in 0..<count {
            await memoryCache.set("value-\(i)", for: "key-\(i)", expiration: nil)
        }
        self.measure {
            let sem = DispatchSemaphore(value: 0)
            Task {
                for i in 0..<count {
                    _ = await memoryCache.get(for: "key-\(i)")
                }
                sem.signal()
            }
            sem.wait()
        }
    }

    func testDiskCacheWritePerformance() async throws {
        let count = 100
        self.measure {
            let sem = DispatchSemaphore(value: 0)
            Task {
                for i in 0..<count {
                    await diskCache.set("value-\(i)", for: "key-\(i)", expiration: nil)
                }
                sem.signal()
            }
            sem.wait()
        }
    }

    func testDiskCacheReadPerformance() async throws {
        let count = 100
        for i in 0..<count {
            await diskCache.set("value-\(i)", for: "key-\(i)", expiration: nil)
        }
        self.measure {
            let sem = DispatchSemaphore(value: 0)
            Task {
                for i in 0..<count {
                    _ = await diskCache.get(for: "key-\(i)")
                }
                sem.signal()
            }
            sem.wait()
        }
    }

    func testHybridCachePerformance() async throws {
        let count = 500
        self.measure {
            let sem = DispatchSemaphore(value: 0)
            Task {
                for i in 0..<count {
                    await hybridCache.set("value-\(i)", for: "key-\(i)", expiration: nil)
                }
                for i in 0..<count {
                    _ = await hybridCache.get(for: "key-\(i)")
                }
                sem.signal()
            }
            sem.wait()
        }
    }
}
