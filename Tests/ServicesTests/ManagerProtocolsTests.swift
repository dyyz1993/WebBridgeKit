import XCTest
@testable import WebBridgeKit

final class ManagerProtocolsTests: XCTestCase {

    func testWebBrowserManagingProtocolExists() {
        let protocolType: WebBrowserManaging.Protocol = WebBrowserManaging.self
        XCTAssertNotNil(protocolType)
    }

    func testManifestCacheManagingProtocolExists() {
        let protocolType: ManifestCacheManaging.Protocol = ManifestCacheManaging.self
        XCTAssertNotNil(protocolType)
    }

    func testWebPageHistoryManagingProtocolExists() {
        let protocolType: WebPageHistoryManaging.Protocol = WebPageHistoryManaging.self
        XCTAssertNotNil(protocolType)
    }

    func testWebCacheManagingProtocolExists() {
        let protocolType: WebCacheManaging.Protocol = WebCacheManaging.self
        XCTAssertNotNil(protocolType)
    }

    func testManifestStoreConformsToManifestCacheManaging() {
        let store: any ManifestCacheManaging = ManifestStore.shared
        XCTAssertTrue(store is ManifestCacheManaging)
    }

    func testRealmHistoryServiceConformsToHistoryServiceProtocol() {
        let service: any HistoryServiceProtocol = RealmHistoryService.shared
        XCTAssertTrue(service is HistoryServiceProtocol)
    }

    func testWebBrowserParamsDefaultExists() {
        let params = WebBrowserParams.default
        XCTAssertEqual(params.displayMode, .normal)
    }

    func testWebBrowserParamsFromURL() {
        let params = WebBrowserParams.from(url: URL(string: "https://example.com")!)
        XCTAssertEqual(params.displayMode, .normal)
    }

    func testCacheMemoryInfoDefaultValues() {
        let info = CacheMemoryInfo(
            totalEntries: 0,
            totalOriginalSize: 0,
            totalCompressedSize: 0,
            compressionRatio: 1.0,
            savedSpace: 0
        )
        XCTAssertEqual(info.totalEntries, 0)
        XCTAssertEqual(info.totalOriginalSize, 0)
        XCTAssertEqual(info.savedSpace, 0)
    }

    func testCacheEntryInfoInit() {
        let entry = CacheEntryRealm()
        entry.key = "test-key"
        entry.url = "https://example.com/test.js"
        entry.originalSize = 1024
        entry.compressedSize = 512

        let info = CacheEntryInfo(from: entry)
        XCTAssertEqual(info.key, "test-key")
        XCTAssertEqual(info.url, "https://example.com/test.js")
        XCTAssertEqual(info.originalSize, 1024)
        XCTAssertEqual(info.compressedSize, 512)
    }

    func testCachedPageInfoInit() {
        let info = CachedPageInfo(
            id: "page-1",
            url: "https://example.com",
            title: "Example",
            ruleId: "rule-1",
            ruleName: "Test Rule",
            resourceCount: 10,
            totalSize: 1024,
            cachedAt: Date()
        )
        XCTAssertEqual(info.id, "page-1")
        XCTAssertEqual(info.url, "https://example.com")
        XCTAssertTrue(info.isOfflineAvailable)
        XCTAssertFalse(info.isExcluded)
    }

    func testRuleWithPagesAggregation() {
        let rule = PageCacheRule(id: UUID().uuidString, name: "Test", includePatterns: ["https://example.com/**"])
        let page1 = CachedPageInfo(
            id: "p1", url: "https://example.com/a", title: "A",
            ruleId: rule.id, ruleName: rule.name,
            resourceCount: 5, totalSize: 1000, cachedAt: Date()
        )
        let page2 = CachedPageInfo(
            id: "p2", url: "https://example.com/b", title: "B",
            ruleId: rule.id, ruleName: rule.name,
            resourceCount: 3, totalSize: 500, cachedAt: Date(), isExcluded: true
        )
        let rwp = RuleWithPages(rule: rule, cachedPages: [page1, page2])
        XCTAssertEqual(rwp.cachedPages.count, 2)
    }
}
