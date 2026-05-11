//
//  PinnedURLModelTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class PinnedURLModelTests: XCTestCase {

    // MARK: - URLType Detection

    func testURLTypeDetectHTML() {
        XCTAssertEqual(URLType.detect(from: "https://example.com"), .htmlPage)
        XCTAssertEqual(URLType.detect(from: "https://wikipedia.org"), .htmlPage)
        XCTAssertEqual(URLType.detect(from: "http://localhost/index.html"), .htmlPage)
    }

    func testURLTypeDetectWebSocket() {
        XCTAssertEqual(URLType.detect(from: "wss://echo.websocket.events"), .websocket)
        XCTAssertEqual(URLType.detect(from: "ws://localhost:8080/ws"), .websocket)
    }

    func testURLTypeDetectAPI() {
        XCTAssertEqual(URLType.detect(from: "https://httpbin.org/api/v2/data"), .apiEndpoint)
        XCTAssertEqual(URLType.detect(from: "https://api.github.com/v1/users"), .apiEndpoint)
        XCTAssertEqual(URLType.detect(from: "https://example.com/api/v2/data"), .apiEndpoint)
    }

    func testURLTypeDetectStaticResource() {
        XCTAssertEqual(URLType.detect(from: "https://cdn.jsdelivr.net/npm/vue@3/dist/vue.js"), .staticResource)
        XCTAssertEqual(URLType.detect(from: "https://fonts.googleapis.com/css2?family=Inter"), .staticResource)
        XCTAssertEqual(URLType.detect(from: "https://example.com/styles/main.css"), .staticResource)
        XCTAssertEqual(URLType.detect(from: "https://example.com/image.png"), .staticResource)
    }

    func testURLTypeDetectManifest() {
        XCTAssertEqual(URLType.detect(from: "https://example.com/manifest.json"), .manifest)
        XCTAssertEqual(URLType.detect(from: "https://cdn.example.com/app/manifest.json"), .manifest)
    }

    func testURLTypeDetectMCP() {
        XCTAssertEqual(URLType.detect(from: "https://modelcontextprotocol.io/endpoint"), .mcpServer)
        XCTAssertEqual(URLType.detect(from: "https://mcp.example.com/api"), .mcpServer)
    }

    func testURLTypeDetectWebApp() {
        XCTAssertEqual(URLType.detect(from: "https://chat.openai.com"), .webApp)
        XCTAssertEqual(URLType.detect(from: "https://excalidraw.com"), .webApp)
    }

    func testURLTypeDetectDefaultFallback() {
        XCTAssertEqual(URLType.detect(from: "ftp://files.example.com/doc.pdf"), .htmlPage)
    }

    // MARK: - URLType Properties

    func testURLTypeDisplayName() {
        XCTAssertFalse(URLType.htmlPage.displayName.isEmpty)
        XCTAssertFalse(URLType.websocket.displayName.isEmpty)
        XCTAssertFalse(URLType.apiEndpoint.displayName.isEmpty)
        for type in URLType.allCases {
            XCTAssertFalse(type.displayName.isEmpty, "\(type) should have displayName")
            XCTAssertFalse(type.iconName.isEmpty, "\(type) should have iconName")
        }
    }

    // MARK: - PinnedURLRealm Model

    func testPinnedURLRealmDefaults() {
        let obj = PinnedURLRealm()

        XCTAssertFalse(obj.id.isEmpty)
        XCTAssertTrue(obj.isPinned)
        XCTAssertEqual(obj.accessCount, 0)
        XCTAssertEqual(obj.urlType, .other)
        XCTAssertNotNil(obj.createdAt)
        XCTAssertNotNil(obj.lastAccessedAt)
        XCTAssertEqual(obj.tags, [])
    }

    func testPinnedURLRealmDisplayTitleFallbackToDomain() {
        let obj = PinnedURLRealm()
        obj.url = "https://example.com"
        obj.title = nil
        obj.domain = "example.com"

        XCTAssertEqual(obj.displayTitle, "example.com")
    }

    func testPinnedURLRealmDisplayTitleCustom() {
        let obj = PinnedURLRealm()
        obj.url = "https://example.com"
        obj.title = "My Custom Title"

        XCTAssertEqual(obj.displayTitle, "My Custom Title")
    }

    func testPinnedURLRealmTags() {
        let obj = PinnedURLRealm()
        obj.tags = ["test", "important"]

        XCTAssertEqual(obj.tags.count, 2)
        XCTAssertTrue(obj.tags.contains("test"))
        XCTAssertTrue(obj.tags.contains("important"))
    }

    func testPinnedURLRealmTagsJSONRoundTrip() {
        let obj = PinnedURLRealm()
        let tags = ["web", "api", "test"]
        obj.tags = tags

        XCTAssertFalse(obj.tagsJson.isEmpty)

        let decoded = obj.tags
        XCTAssertEqual(decoded.sorted(), tags.sorted())
    }

    // MARK: - SubsystemID

    func testSubsystemIDAllCasesCount() {
        XCTAssertEqual(SubsystemID.allCases.count, 11,
                       "Should have exactly 11 cache subsystems")
    }

    func testSubsystemIDProperties() {
        for id in SubsystemID.allCases {
            XCTAssertFalse(id.name.isEmpty, "\(id) needs name")
            XCTAssertFalse(id.nameZh.isEmpty, "\(id) needs nameZh")
            XCTAssertFalse(id.iconName.isEmpty, "\(id) needs iconName")
        }
    }

    // MARK: - SubsystemStats

    func testSubsystemStatsFormattedSize() {
        let stats = SubsystemStats(id: .manifestCache, totalEntries: 10, totalSize: 1024 * 1024)

        XCTAssertEqual(stats.formattedSize, "1 MB")
 XCTAssertEqual(stats.totalEntries, 10)
        XCTAssertTrue(stats.hasData)
    }

    func testSubsystemStatsZeroState() {
        let stats = SubsystemStats(id: .genericCacheManager)

        XCTAssertFalse(stats.hasData)
        XCTAssertEqual(stats.totalEntries, 0)
        XCTAssertTrue(stats.formattedSize == "0 KB" || stats.formattedSize == "Zero KB" || stats.formattedSize == "0 bytes", "Expected zero-size format but got: \(stats.formattedSize)")
    }

    func testSubsystemStatsWithHitRate() {
        let stats = SubsystemStats(
            id: .manifestCache,
            totalEntries: 100,
            totalSize: 5_000_000,
            hitRate: 0.85
        )

        XCTAssertEqual(stats.formattedHitRate, "85.0%")
    }

    func testSubsystemStatsWithoutHitRate() {
        let stats = SubsystemStats(id: .offlinePageCache)

        XCTAssertNil(stats.formattedHitRate)
    }

    // MARK: - DashboardData

    func testDashboardDataAggregation() {
        let data = DashboardData(
            totalSize: 10_000_000,
            totalEntries: 500,
            subsystems: [
                SubsystemStats(id: .manifestCache, totalEntries: 200, totalSize: 5_000_000, hitRate: 0.9),
                SubsystemStats(id: .webResourceCache, totalEntries: 300, totalSize: 5_000_000),
                SubsystemStats(id: .memoryCacheRule, totalEntries: 0, totalSize: 0),
            ],
            pinnedURLCount: 5
        )

        XCTAssertEqual(data.totalEntries, 500)
        XCTAssertEqual(data.activeSubsystemCount, 2)
        XCTAssertEqual(data.pinnedURLCount, 5)
        XCTAssertFalse(data.formattedTotalSize.isEmpty)
    }

    func testDashboardDataSizeDistribution() {
        let data = DashboardData(
            totalSize: 1000,
            totalEntries: 10,
            subsystems: [
                SubsystemStats(id: .manifestCache, totalEntries: 5, totalSize: 700),
                SubsystemStats(id: .webResourceCache, totalEntries: 3, totalSize: 250),
                SubsystemStats(id: .webCompressedCache, totalEntries: 2, totalSize: 50),
            ],
            pinnedURLCount: 0
        )

        let dist = data.sizeDistribution
        XCTAssertEqual(dist.count, 3)

        if dist.count >= 2 {
            XCTAssertGreaterThanOrEqual(dist[0].percentage, dist[1].percentage)
        }

        let totalPercent = dist.reduce(0.0) { $0 + $1.percentage }
        XCTAssertEqual(totalPercent, 100.0, accuracy: 1.0)
    }

    func testDashboardDataEmpty() {
        let data = DashboardData()

        XCTAssertEqual(data.totalEntries, 0)
        XCTAssertEqual(data.totalSize, 0)
        XCTAssertEqual(data.activeSubsystemCount, 0)
        XCTAssertTrue(data.sizeDistribution.isEmpty)
    }

    func testDashboardDataAverageHitRate() {
        let data = DashboardData(
            totalSize: 100,
            totalEntries: 10,
            subsystems: [
                SubsystemStats(id: .manifestCache, totalEntries: 5, totalSize: 50, hitRate: 0.8),
                SubsystemStats(id: .systemURLCache, totalEntries: 5, totalSize: 50, hitRate: 0.6),
            ],
            pinnedURLCount: 0
        )

        XCTAssertEqual(data.averageHitRate ?? -1, 0.7, accuracy: 0.01)
    }

    func testDashboardDataAverageHitRateNilWhenNoHitRates() {
        let data = DashboardData(
            subsystems: [
                SubsystemStats(id: .offlinePageCache, totalEntries: 1, totalSize: 100),
            ]
        )

        XCTAssertNil(data.averageHitRate)
    }

    func testDashboardDataByStatus() {
        let data = DashboardData(
            subsystems: [
                SubsystemStats(id: .manifestCache, totalEntries: 10, totalSize: 1000, status: .active),
                SubsystemStats(id: .genericCacheManager, status: .empty),
                SubsystemStats(id: .webResourceCache, status: .error("test error")),
                SubsystemStats(id: .memoryCacheRule, status: .unknown),
            ]
        )

        let grouped = data.byStatus
        XCTAssertEqual(grouped.active.count, 1)
        XCTAssertEqual(grouped.empty.count, 2)
        XCTAssertEqual(grouped.error.count, 1)
    }
}

// MARK: - PresetURLCatalog Tests

extension PinnedURLModelTests {

    func testPresetCatalogItemCount() {
        XCTAssertEqual(PresetURLCatalog.allItems.count, 25,
                       "Should have exactly 25 preset URLs")
    }

    func testPresetCatalogCategories() {
        let byCat = PresetURLCatalog.itemsByCategory
        XCTAssertGreaterThan(byCat.count, 0)
    }

    func testPresetCatalogRecommendedItems() {
        let recommended = PresetURLCatalog.recommendedItems
        XCTAssertGreaterThanOrEqual(recommended.count, 4)

        for item in recommended {
            XCTAssertTrue(item.isRecommended, "\(item.title) should be recommended")
        }
    }

    func testPresetCatalogSearch() {
        let results = PresetURLCatalog.search("GitHub")

        XCTAssertFalse(results.isEmpty, "Should find GitHub-related items")
        for item in results {
            XCTAssertTrue(
                item.title.lowercased().contains("github") ||
                item.description.lowercased().contains("github") ||
                item.url.lowercased().contains("github") ||
                item.tags.contains(where: { $0.lowercased().contains("github") }),
                "Search result '\(item.title)' doesn't match 'GitHub'"
            )
        }
    }

    func testPresetCatalogSearchEmpty() {
        let results = PresetURLCatalog.search("xyznonexistent12345")
        XCTAssertTrue(results.isEmpty, "Empty search should return no results")
    }

    func testPresetCatalogSearchAll() {
        let results = PresetURLCatalog.search("")
        XCTAssertEqual(results.count, PresetURLCatalog.allItems.count)
    }

    func testPresetCatalogFindByID() {
        guard let first = PresetURLCatalog.allItems.first else {
            XCTFail("Catalog should not be empty"); return
        }

        let found = PresetURLCatalog.find(id: first.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, first.id)
        XCTAssertEqual(found?.url, first.url)
    }

    func testPresetCatalogAllItemsHaveRequiredFields() {
        for item in PresetURLCatalog.allItems {
            XCTAssertFalse(item.id.isEmpty, "\(item.title): missing id")
            XCTAssertFalse(item.url.isEmpty, "\(item.title): missing url")
            XCTAssertFalse(item.title.isEmpty, "\(item.title): missing title")
            XCTAssertFalse(item.description.isEmpty, "\(item.title): missing description")
        }
    }
}
