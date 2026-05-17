//
//  PinnedURLManagerAsyncTests.swift
//  ManagersTests
//
//  Created for WebBridgeKit async method test coverage.
//

import XCTest
@testable import WebBridgeKit
import RealmSwift

final class PinnedURLManagerAsyncTests: XCTestCase {

    private var sut: PinnedURLManager!

    override func setUp() async throws {
        try await super.setUp()
        sut = PinnedURLManager.shared
        let all = (try? await sut.getAllPinned()) ?? []
        for item in all {
            try? await sut.delete(id: item.id)
        }
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Singleton

    func testShared_returnsSameInstance() {
        let a = PinnedURLManager.shared
        let b = PinnedURLManager.shared
        XCTAssertTrue(a === b)
    }

    // MARK: - add(url:title:notes:)

    func testAddAsync_createsNewPinnedURL() async throws {
        let result = try await sut.add(url: "https://test.example.com/page", title: "Test Page", notes: "some notes")

        XCTAssertEqual(result.url, "https://test.example.com/page")
        XCTAssertEqual(result.title, "Test Page")
        XCTAssertEqual(result.notes, "some notes")
        XCTAssertEqual(result.domain, "test.example.com")
        XCTAssertTrue(result.isPinned)
        XCTAssertEqual(result.accessCount, 1)
    }

    func testAddAsync_defaultsTitleToHost() async throws {
        let result = try await sut.add(url: "https://myhost.com/path")

        XCTAssertEqual(result.title, "myhost.com")
    }

    func testAddAsync_detectsURLType_htmlPage() async throws {
        let result = try await sut.add(url: "https://example.com/about")
        XCTAssertEqual(result.urlType, .htmlPage)
    }

    func testAddAsync_detectsURLType_apiEndpoint() async throws {
        let result = try await sut.add(url: "https://api.example.com/v1/users")
        XCTAssertEqual(result.urlType, .apiEndpoint)
    }

    func testAddAsync_detectsURLType_websocket() async throws {
        let result = try await sut.add(url: "wss://socket.example.com/realtime")
        XCTAssertEqual(result.urlType, .websocket)
    }

    func testAddAsync_detectsURLType_staticResource() async throws {
        let result = try await sut.add(url: "https://cdn.example.com/style.css")
        XCTAssertEqual(result.urlType, .staticResource)
    }

    func testAddAsync_detectsURLType_manifest() async throws {
        let result = try await sut.add(url: "https://example.com/manifest.json")
        XCTAssertEqual(result.urlType, .manifest)
    }

    func testAddAsync_updatesExistingURL() async throws {
        let first = try await sut.add(url: "https://dup.example.com", title: "First")
        let second = try await sut.add(url: "https://dup.example.com", title: "Second")

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(second.title, "Second")
        XCTAssertEqual(second.accessCount, 2)
    }

    func testAddAsync_setsCreatedAt() async throws {
        let before = Date()
        let result = try await sut.add(url: "https://date-test.com")
        let after = Date()

        XCTAssertGreaterThanOrEqual(result.createdAt, before)
        XCTAssertLessThanOrEqual(result.createdAt, after)
    }

    // MARK: - getAllPinned()

    func testGetAllPinnedAsync_returnsEmptyInitially() async throws {
        let all = try await sut.getAllPinned()
        XCTAssertTrue(all.isEmpty)
    }

    func testGetAllPinnedAsync_returnsPinnedItems() async throws {
        try await sut.add(url: "https://a-pinned.com")
        try await sut.add(url: "https://b-pinned.com")

        let all = try await sut.getAllPinned()

        XCTAssertEqual(all.count, 2)
        let urls = Set(all.map(\.url))
        XCTAssertTrue(urls.contains("https://a-pinned.com"))
        XCTAssertTrue(urls.contains("https://b-pinned.com"))
    }

    func testGetAllPinnedAsync_excludesUnpinnedItems() async throws {
        let added = try await sut.add(url: "https://will-unpin.com")
        try await sut.unpin(id: added.id)
        try await sut.add(url: "https://stays-pinned.com")

        let all = try await sut.getAllPinned()

        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.url, "https://stays-pinned.com")
    }

    func testGetAllPinnedAsync_sortedByLastAccessedAt() async throws {
        let first = try await sut.add(url: "https://first.com")
        _ = try await sut.add(url: "https://second.com")
        try await sut.recordAccess(id: first.id)

        let all = try await sut.getAllPinned()
        XCTAssertEqual(all.first?.url, "https://first.com")
    }

    // MARK: - delete(id:)

    func testDeleteAsync_removesItem() async throws {
        let added = try await sut.add(url: "https://delete-me.com")
        try await sut.delete(id: added.id)

        let all = try await sut.getAllPinned()
        XCTAssertTrue(all.isEmpty)
    }

    func testDeleteAsync_throwsForNonexistentId() async {
        do {
            try await sut.delete(id: "nonexistent-id-12345")
            XCTFail("Should throw for nonexistent ID")
        } catch let error as WebBridgeError {
            if case .invalidInput(let msg) = error {
                XCTAssertTrue(msg.contains("not found"))
            } else {
                XCTFail("Wrong error case: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - unpin(id:)

    func testUnpinAsync_setsIsPinnedFalse() async throws {
        let added = try await sut.add(url: "https://unpin-me.com")
        XCTAssertTrue(added.isPinned)

        try await sut.unpin(id: added.id)

        let all = try await sut.getAllPinned()
        XCTAssertTrue(all.isEmpty, "Unpinned item should not appear in getAllPinned")
    }

    func testUnpinAsync_throwsForNonexistentId() async {
        do {
            try await sut.unpin(id: "nonexistent-id-99999")
            XCTFail("Should throw for nonexistent ID")
        } catch let error as WebBridgeError {
            if case .invalidInput(let msg) = error {
                XCTAssertTrue(msg.contains("not found"))
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - recordAccess(id:)

    func testRecordAccessAsync_incrementsAccessCount() async throws {
        let added = try await sut.add(url: "https://access-test.com")
        XCTAssertEqual(added.accessCount, 1)

        try await sut.recordAccess(id: added.id)
        try await sut.recordAccess(id: added.id)

        let all = try await sut.getAllPinned()
        let updated = all.first(where: { $0.id == added.id })
        XCTAssertEqual(updated?.accessCount, 3)
    }

    func testRecordAccessAsync_doesNotThrowForNonexistentId() async throws {
        try await sut.recordAccess(id: "nonexistent-id-no-crash")
    }

    // MARK: - getByType(_:)

    func testGetByTypeAsync_filtersByType() async throws {
        try await sut.add(url: "https://plain-site.com/about")
        try await sut.add(url: "https://api.example.com/v1/data")

        let htmlPages = try await sut.getByType(.htmlPage)
        let apiEndpoints = try await sut.getByType(.apiEndpoint)

        XCTAssertGreaterThanOrEqual(htmlPages.count, 1)
        XCTAssertGreaterThanOrEqual(apiEndpoints.count, 1)
        XCTAssertTrue(htmlPages.allSatisfy { $0.urlType == .htmlPage })
        XCTAssertTrue(apiEndpoints.allSatisfy { $0.urlType == .apiEndpoint })
    }

    func testGetByTypeAsync_excludesUnpinned() async throws {
        let added = try await sut.add(url: "https://type-unpin.com")
        try await sut.unpin(id: added.id)

        let results = try await sut.getByType(.htmlPage)
        XCTAssertFalse(results.contains(where: { $0.id == added.id }))
    }

    // MARK: - search(_:)

    func testSearchAsync_matchesTitle() async throws {
        try await sut.add(url: "https://search-test.com", title: "My Special Title")

        let results = try await sut.search("Special")

        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertTrue(results.contains(where: { $0.title == "My Special Title" }))
    }

    func testSearchAsync_matchesUrl() async throws {
        try await sut.add(url: "https://unique-search-domain.com/path")

        let results = try await sut.search("unique-search-domain")

        XCTAssertGreaterThanOrEqual(results.count, 1)
    }

    func testSearchAsync_matchesDomain() async throws {
        try await sut.add(url: "https://findable-domain.com")

        let results = try await sut.search("findable-domain")

        XCTAssertGreaterThanOrEqual(results.count, 1)
    }

    func testSearchAsync_matchesNotes() async throws {
        try await sut.add(url: "https://note-search.com", notes: "important research notes")

        let results = try await sut.search("research")

        XCTAssertGreaterThanOrEqual(results.count, 1)
    }

    func testSearchAsync_caseInsensitive() async throws {
        try await sut.add(url: "https://case-test.com", title: "UPPERCASE Title")

        let results = try await sut.search("uppercase")

        XCTAssertGreaterThanOrEqual(results.count, 1)
    }

    func testSearchAsync_returnsEmptyForNoMatch() async throws {
        try await sut.add(url: "https://existing.com")

        let results = try await sut.search("zzzznonexistent")

        XCTAssertTrue(results.isEmpty)
    }

    func testSearchAsync_excludesUnpinned() async throws {
        let added = try await sut.add(url: "https://search-unpin.com", title: "Will Be Unpinned")
        try await sut.unpin(id: added.id)

        let results = try await sut.search("Will Be Unpinned")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - getSummary()

    func testGetSummaryAsync_returnsCorrectCounts() async throws {
        try await sut.add(url: "https://summary-a.com")
        try await sut.add(url: "https://summary-b.com")
        let toUnpin = try await sut.add(url: "https://summary-c.com")
        try await sut.unpin(id: toUnpin.id)

        let summary = try await sut.getSummary()

        XCTAssertGreaterThanOrEqual(summary.totalCount, 3)
        XCTAssertGreaterThanOrEqual(summary.pinnedCount, 2)
    }

    func testGetSummaryAsync_emptyDatabase() async throws {
        let summary = try await sut.getSummary()

        XCTAssertEqual(summary.totalCount, 0)
        XCTAssertEqual(summary.pinnedCount, 0)
        XCTAssertTrue(summary.typeDistribution.isEmpty)
        XCTAssertTrue(summary.topDomains.isEmpty)
    }

    func testGetSummaryAsync_typeDistribution() async throws {
        try await sut.add(url: "https://plain.com/page")
        try await sut.add(url: "https://api.host.com/v1/endpoint")

        let summary = try await sut.getSummary()

        XCTAssertGreaterThanOrEqual(summary.typeDistribution[.htmlPage, default: 0], 1)
        XCTAssertGreaterThanOrEqual(summary.typeDistribution[.apiEndpoint, default: 0], 1)
    }

    func testGetSummaryAsync_topDomains() async throws {
        try await sut.add(url: "https://top-domain.com/a")
        try await sut.add(url: "https://top-domain.com/b")
        try await sut.add(url: "https://other-domain.com/x")

        let summary = try await sut.getSummary()

        XCTAssertFalse(summary.topDomains.isEmpty)
        let topEntry = summary.topDomains.first
        XCTAssertEqual(topEntry?.domain, "top-domain.com")
        XCTAssertEqual(topEntry?.count, 2)
    }

    // MARK: - importPresets(_:)

    func testImportPresetsAsync_importsNewItems() async throws {
        let items = [
            PresetURLItem(url: "https://preset-a.com", title: "Preset A", description: "Desc A", category: .development),
            PresetURLItem(url: "https://preset-b.com", title: "Preset B", description: "Desc B", category: .tools)
        ]

        let count = try await sut.importPresets(items)

        XCTAssertEqual(count, 2)
        let all = try await sut.getAllPinned()
        XCTAssertGreaterThanOrEqual(all.count, 2)
    }

    func testImportPresetsAsync_skipsExistingURLs() async throws {
        try await sut.add(url: "https://existing-preset.com")
        let items = [
            PresetURLItem(url: "https://existing-preset.com", title: "Already There", description: "", category: .development),
            PresetURLItem(url: "https://new-preset.com", title: "New One", description: "", category: .tools)
        ]

        let count = try await sut.importPresets(items)

        XCTAssertEqual(count, 1, "Should skip existing URL and only import new one")
    }

    func testImportPresetsAsync_emptyArray() async throws {
        let count = try await sut.importPresets([])
        XCTAssertEqual(count, 0)
    }

    // MARK: - seedRecommendedPresetsIfNeeded()

    func testSeedRecommendedPresetsAsync_seedsWhenEmpty() async throws {
        let count = try await sut.seedRecommendedPresetsIfNeeded()

        XCTAssertGreaterThan(count, 0, "Should seed recommended presets when DB is empty")
    }

    func testSeedRecommendedPresetsAsync_skipsWhenNotEmpty() async throws {
        try await sut.add(url: "https://already-here.com")

        let count = try await sut.seedRecommendedPresetsIfNeeded()

        XCTAssertEqual(count, 0, "Should not seed when items already exist")
    }

    // MARK: - Deprecated Sync Methods

    func testDeprecatedGetAllPinnedSync_returnsNotNil() {
        let result = sut.getAllPinnedSync()
        XCTAssertNotNil(result)
    }

    func testDeprecatedAddSync_returnsResult() {
        let result = sut.addSync(url: "https://sync-test.com", title: "Sync Title")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.url, "https://sync-test.com")
        XCTAssertEqual(result?.title, "Sync Title")
    }

    func testDeprecatedDeleteSync_works() async throws {
        let added = try await sut.add(url: "https://sync-delete-test.com")
        XCTAssertNoThrow(try sut.deleteSync(id: added.id))
    }

    func testDeprecatedUnpinSync_works() async throws {
        let added = try await sut.add(url: "https://sync-unpin-test.com")
        XCTAssertNoThrow(try sut.unpinSync(id: added.id))
    }
}
