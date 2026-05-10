import XCTest
import RxSwift
@testable import WebBridgeKit

final class WebCacheManagerTests: XCTestCase {

    private var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        disposeBag = nil
        super.tearDown()
    }

    func testSharedInstance() {
        let manager = WebCacheManager.shared
        XCTAssertNotNil(manager)
    }

    func testIsURLCachedForRandomURL() {
        let manager = WebCacheManager.shared
        let url = URL(string: "https://nonexistent-\(UUID().uuidString).com/test")!
        XCTAssertFalse(manager.isURLCached(url))
    }

    func testIsResourceCachedForRandomURL() {
        let manager = WebCacheManager.shared
        let url = URL(string: "https://nonexistent-\(UUID().uuidString).com/asset.js")!
        let result = manager.isResourceCached(url: url)
        XCTAssertFalse(result.cached)
        XCTAssertNil(result.info)
    }

    func testGetCachedDomains() {
        let manager = WebCacheManager.shared
        let domains = manager.getCachedDomains()
        XCTAssertNotNil(domains)
    }

    func testGetTotalCacheSize() {
        let manager = WebCacheManager.shared
        let size = manager.getTotalCacheSize()
        XCTAssertGreaterThanOrEqual(size, 0)
    }

    func testClearAllNoCrash() {
        let manager = WebCacheManager.shared
        manager.clearAll()
    }

    func testPerformAutoCleanupNoCrash() {
        let manager = WebCacheManager.shared
        manager.performAutoCleanup()
    }

    func testURLSHA256Consistent() {
        let url = URL(string: "https://example.com/test.js")!
        let hash1 = url.sha256
        let hash2 = url.sha256
        XCTAssertEqual(hash1, hash2)
    }

    func testURLSHA256NotEmpty() {
        let url = URL(string: "https://example.com/test.js")!
        let hash = url.sha256
        XCTAssertFalse(hash.isEmpty)
        XCTAssertEqual(hash.count, 64)
    }

    func testURLSHA256DifferentURLs() {
        let url1 = URL(string: "https://example.com/a.js")!
        let url2 = URL(string: "https://example.com/b.js")!
        XCTAssertNotEqual(url1.sha256, url2.sha256)
    }

    func testURLSHA256SameContent() {
        let url1 = URL(string: "https://example.com/test.js")!
        let url2 = URL(string: "https://example.com/test.js")!
        XCTAssertEqual(url1.sha256, url2.sha256)
    }

    func testURLSHA256Deterministic() {
        let url = URL(string: "https://example.com/test.js")!
        let hash1 = url.sha256
        let hash2 = url.sha256
        XCTAssertEqual(hash1, hash2)
        XCTAssertEqual(hash1.count, 64)
    }

    func testGetCacheMemoryInfoObservable() {
        let manager = WebCacheManager.shared
        let expectation = XCTestExpectation(description: "getCacheMemoryInfo")
        _ = manager.getCacheMemoryInfo()
            .subscribe(onNext: { _ in
                expectation.fulfill()
            }, onError: { _ in
                expectation.fulfill()
            })
            .disposed(by: disposeBag)
        wait(for: [expectation], timeout: 2.0)
    }

    func testGetDetailedCacheEntriesObservable() {
        let manager = WebCacheManager.shared
        let expectation = XCTestExpectation(description: "getDetailedCacheEntries")
        _ = manager.getDetailedCacheEntries()
            .subscribe(onNext: { _ in
                expectation.fulfill()
            }, onError: { _ in
                expectation.fulfill()
            })
            .disposed(by: disposeBag)
        wait(for: [expectation], timeout: 2.0)
    }

    func testGetDetailedCacheEntriesWithFilter() {
        let manager = WebCacheManager.shared
        let expectation = XCTestExpectation(description: "getDetailedCacheEntries filter")
        _ = manager.getDetailedCacheEntries(filterPattern: "*.js")
            .subscribe(onNext: { _ in
                expectation.fulfill()
            }, onError: { _ in
                expectation.fulfill()
            })
            .disposed(by: disposeBag)
        wait(for: [expectation], timeout: 2.0)
    }

    func testGetCacheEntriesGroupedByDomainObservable() {
        let manager = WebCacheManager.shared
        let expectation = XCTestExpectation(description: "getCacheEntriesGroupedByDomain")
        _ = manager.getCacheEntriesGroupedByDomain()
            .subscribe(onNext: { _ in
                expectation.fulfill()
            }, onError: { _ in
                expectation.fulfill()
            })
            .disposed(by: disposeBag)
        wait(for: [expectation], timeout: 2.0)
    }

    func testDeleteCacheByGlobObservable() {
        let manager = WebCacheManager.shared
        let expectation = XCTestExpectation(description: "deleteCacheByGlob")
        _ = manager.deleteCacheByGlob(pattern: "https://nonexistent.com/*.js")
            .subscribe(onNext: { _ in
                expectation.fulfill()
            }, onError: { _ in
                expectation.fulfill()
            })
            .disposed(by: disposeBag)
        wait(for: [expectation], timeout: 2.0)
    }

    func testClearAllCompressedCacheObservable() {
        let manager = WebCacheManager.shared
        let expectation = XCTestExpectation(description: "clearAllCompressedCache")
        _ = manager.clearAllCompressedCache()
            .subscribe(onNext: { _ in
                expectation.fulfill()
            }, onError: { _ in
                expectation.fulfill()
            })
            .disposed(by: disposeBag)
        wait(for: [expectation], timeout: 2.0)
    }
}
