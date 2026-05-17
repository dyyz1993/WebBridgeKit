import XCTest
@testable import WebBridgeKit

final class ServiceLocatorManagerTests: XCTestCase {

    private var locator: ServiceLocator!

    override func setUp() {
        super.setUp()
        locator = ServiceLocator.shared
    }

    override func tearDown() {
        locator.clearServices()
        locator.reset()
        locator = nil
        super.tearDown()
    }

    // MARK: - PinnedURLManager

    func testPinnedURLManagerFallsBackToShared() {
        locator.clearServices()
        let manager = locator.pinnedURLManager
        XCTAssertNotNil(manager)
        XCTAssertTrue(manager === PinnedURLManager.shared)
    }

    func testCustomPinnedURLManagerRegistration() {
        let mock = MockPinnedURLManager()
        locator.register(pinnedURLManager: mock)
        XCTAssertTrue(locator.pinnedURLManager === mock)
    }

    func testClearServicesFallsBackPinnedURLManagerToShared() {
        let mock = MockPinnedURLManager()
        locator.register(pinnedURLManager: mock)
        XCTAssertTrue(locator.pinnedURLManager === mock)

        locator.clearServices()
        XCTAssertTrue(locator.pinnedURLManager === PinnedURLManager.shared)
    }

    // MARK: - URLFavoriteManager

    func testUrlFavoriteManagerFallsBackToShared() {
        locator.clearServices()
        let manager = locator.urlFavoriteManager
        XCTAssertNotNil(manager)
        XCTAssertTrue(manager === URLFavoriteManager.shared)
    }

    func testCustomUrlFavoriteManagerRegistration() {
        let mock = MockURLManaging()
        locator.register(urlFavoriteManager: mock)
        XCTAssertTrue(locator.urlFavoriteManager === mock)
    }

    func testClearServicesFallsBackUrlFavoriteManagerToShared() {
        let mock = MockURLManaging()
        locator.register(urlFavoriteManager: mock)
        XCTAssertTrue(locator.urlFavoriteManager === mock)

        locator.clearServices()
        XCTAssertTrue(locator.urlFavoriteManager === URLFavoriteManager.shared)
    }

    // MARK: - ManifestStore

    func testManifestStoreFallsBackToShared() {
        locator.clearServices()
        let store = locator.manifestStore
        XCTAssertNotNil(store)
        XCTAssertTrue(store === ManifestStore.shared)
    }

    func testCustomManifestStoreRegistration() {
        let mock = MockManifestCacheManaging()
        locator.register(manifestStore: mock)
        XCTAssertTrue(locator.manifestStore === mock)
    }

    func testClearServicesFallsBackManifestStoreToShared() {
        let mock = MockManifestCacheManaging()
        locator.register(manifestStore: mock)
        locator.clearServices()
        XCTAssertTrue(locator.manifestStore === ManifestStore.shared)
    }

    // MARK: - CacheManager

    func testCacheManagerFallsBackToShared() {
        locator.clearServices()
        let manager = locator.cacheManager
        XCTAssertNotNil(manager)
        XCTAssertTrue(manager === WebCacheManager.shared)
    }

    func testCustomCacheManagerRegistration() {
        let mock = MockWebCacheManaging()
        locator.register(cacheManager: mock)
        XCTAssertTrue(locator.cacheManager === mock)
    }

    func testClearServicesFallsBackCacheManagerToShared() {
        let mock = MockWebCacheManaging()
        locator.register(cacheManager: mock)
        locator.clearServices()
        XCTAssertTrue(locator.cacheManager === WebCacheManager.shared)
    }

    // MARK: - MessageEngine

    func testMessageEngineFallsBackToShared() {
        locator.clearServices()
        let engine = locator.messageEngine
        XCTAssertNotNil(engine)
    }

    func testCustomMessageEngineRegistration() {
        let mock = MockMessageEngineProtocol()
        locator.register(messageEngine: mock)
        XCTAssertTrue(locator.messageEngine === mock)
    }

    // MARK: - historyService no fatalError

    func testHistoryServiceNoFatalErrorWithoutSetup() {
        locator.clearServices()
        let _ = locator.historyService
    }

    func testFavoriteServiceNoFatalErrorWithoutSetup() {
        locator.clearServices()
        let _ = locator.favoriteService
    }

    // MARK: - Convenience accessors for managers

    func testStaticPinnedURLsAccessor() {
        let manager = ServiceLocator.pinnedURLs
        XCTAssertNotNil(manager)
    }

    func testStaticUrlFavoritesAccessor() {
        let manager = ServiceLocator.urlFavorites
        XCTAssertNotNil(manager)
    }

    func testStaticManifestAccessor() {
        let store = ServiceLocator.manifest
        XCTAssertNotNil(store)
    }

    func testStaticCacheAccessor() {
        let manager = ServiceLocator.cache
        XCTAssertNotNil(manager)
    }

    func testStaticMessagesAccessor() {
        let engine = ServiceLocator.messages
        XCTAssertNotNil(engine)
    }
}

// MARK: - Mocks

private final class MockPinnedURLManager: PinnedURLManaging {
    func add(url: String, title: String?, notes: String?) async throws -> PinnedURLRealm {
        fatalError("not implemented")
    }
    func unpin(id: String) async throws {
        fatalError("not implemented")
    }
    func delete(id: String) async throws {
        fatalError("not implemented")
    }
    func recordAccess(id: String) async {}
    func getAllPinned() async throws -> [PinnedURLRealm] { [] }
    func getByType(_ type: URLType) async throws -> [PinnedURLRealm] { [] }
    func search(_ query: String) async throws -> [PinnedURLRealm] { [] }
    func getSummary() async throws -> PinnedURLSummary {
        PinnedURLSummary(totalCount: 0, pinnedCount: 0, typeDistribution: [:], topDomains: [])
    }
    func importPresets(_ items: [PresetURLItem]) async throws -> Int { 0 }
    func seedRecommendedPresetsIfNeeded() async throws -> Int { 0 }
}

private final class MockURLManaging: URLManaging {
    func addURL(_ url: URL, title: String?) throws {}
    func removeURL(_ url: URL) throws {}
    func getAllURLs() -> [URL] { [] }
    func isFavorite(_ url: URL) -> Bool { false }
}

private final class MockManifestCacheManaging: ManifestCacheManaging {
    func saveHTML(_ html: String, for key: String) {}
    func getHTML(for key: String) -> String? { nil }
    func removeHTML(for key: String) {}
    func saveManifest(_ manifest: Manifest, for key: String) {}
    func getManifest(for key: String) -> Manifest? { nil }
    func removeManifest(for key: String) {}
    func clearAll() {}
    func getAllPageKeys() -> [String] { [] }
}

private final class MockWebCacheManaging: WebCacheManaging {
    func fetchSystemCacheStatistics() -> Observable<[WebCacheStatistics]> {
        Observable.just([])
    }
    func clearAll() {}
    func clearCache(for domain: String) -> Observable<Void> { Observable.just(()) }
    func clearAllCache() -> Observable<Void> { Observable.just(()) }
    func performAutoCleanup() {}
    func getCachedDomains() -> [WebCacheStatistics] { [] }
    func getTotalCacheSize() -> Int64 { 0 }
    func isURLCached(_ url: URL) -> Bool { false }
    func preloadURL(_ url: URL) -> Observable<Void> { Observable.just(()) }
    func deleteCacheByGlob(pattern: String) -> Observable<Int> { Observable.just(0) }
    func getCacheMemoryInfo() -> Observable<CacheMemoryInfo> {
        fatalError("not implemented")
    }
    func getDetailedCacheEntries(filterPattern: String?) -> Observable<[CacheEntryInfo]> {
        Observable.just([])
    }
    func getCacheEntriesGroupedByDomain() -> Observable<[String: [CacheEntryInfo]]> {
        Observable.just([:])
    }
    func isResourceCached(url: URL) -> (cached: Bool, info: CacheEntryInfo?) {
        (false, nil)
    }
    func preloadToCompressedCache(url: URL) -> Observable<Progress> {
        fatalError("not implemented")
    }
    func clearAllCompressedCache() -> Observable<Void> { Observable.just(()) }
}

private final class MockMessageEngineProtocol: MessageEngineProtocol {
    func registerChannel(_ channel: any MessageChannel) async {}
    func unregisterChannel(_ channelId: String) async {}
    func getRegisteredChannels() async -> [String] { [] }
    func setPipeline(_ pipeline: MessageProcessorPipeline) async {}
    func setStore(_ store: any MessageStore) async {}
    func registerHandler(_ handler: MessageHandler, forCategory category: String) async {}
    func startAll() async {}
    func stopAll() async {}
    func send(_ payload: MessagePayload, through channelId: String) async throws -> MessageSendResult {
        .success(messageId: "")
    }
    func receive(_ payload: MessagePayload) async throws {}
    func getMessages() async -> [StoredMessage] { [] }
    func getUnreadMessages() async -> [StoredMessage] { [] }
    func getUnreadCount() async -> Int { 0 }
    func markAsRead(id: String) async {}
    func deleteMessage(id: String) async {}
    func clearAllMessages() async {}
    func getStatistics() async -> MessageStatistics { MessageStatistics() }
}
