//
//  PersistentManifestLoaderTests.swift
//  HandlerTests
//

import XCTest
import WebKit
@testable import WebBridgeKit

final class PersistentManifestLoaderTests: XCTestCase {

    private var loader: PersistentManifestLoader!

    override func setUp() {
        super.setUp()
        loader = PersistentManifestLoader.shared
    }

    override func tearDown() {
        loader.clearAllCache()
        super.tearDown()
    }

    // MARK: - Loading States

    func testInitialStateIsIdle() {
        if case .idle = loader.getCurrentState() {
            // pass
        } else {
            XCTFail("Expected idle state")
        }
    }

    func testGetCurrentStateReturnsState() {
        let state = loader.getCurrentState()
        switch state {
        case .idle, .fetchingManifest, .downloadingResources, .preparingHTML,
             .loadingWebView, .completed, .failed:
            break
        }
    }

    // MARK: - Scheme

    func testSchemeIsCorrect() {
        XCTAssertEqual(loader.scheme, "wb-resource")
    }

    // MARK: - Cache Size

    func testCacheSizeStartsAtZeroOrSmall() {
        loader.clearAllCache()
        let size = loader.getCacheSize()
        XCTAssertGreaterThanOrEqual(size, 0)
    }

    func testCacheSizeForNonexistentID() {
        let size = loader.getCacheSize(for: "nonexistent-id-12345")
        XCTAssertEqual(size, 0)
    }

    // MARK: - isCached

    func testIsCachedReturnsFalseForUnknownURL() {
        let url = URL(string: "https://nonexistent-site-abc123.com/page")!
        XCTAssertFalse(loader.isCached(url: url))
    }

    func testIsCachedReturnsFalseForEmptyCache() {
        loader.clearAllCache()
        let url = URL(string: "https://example.com/test")!
        XCTAssertFalse(loader.isCached(url: url))
    }

    // MARK: - Clear Cache

    func testClearAllCacheDoesNotCrash() {
        loader.clearAllCache()
    }

    func testClearCacheForURL() {
        let url = URL(string: "https://example.com/page")!
        loader.clearCache(for: url)
    }

    // MARK: - WebManifest

    func testWebManifestInit() {
        let manifest = PersistentManifestLoader.WebManifest(
            persistent: true,
            resources: ["logo.png": "https://example.com/logo.png"],
            version: "1.0.0",
            appid: "test-app",
            name: "Test App",
            icon: "https://example.com/icon.png"
        )
        XCTAssertTrue(manifest.persistent)
        XCTAssertEqual(manifest.resources.count, 1)
        XCTAssertEqual(manifest.version, "1.0.0")
        XCTAssertEqual(manifest.appid, "test-app")
        XCTAssertEqual(manifest.name, "Test App")
    }

    func testWebManifestResolvedVersionDefault() {
        let manifest = PersistentManifestLoader.WebManifest(
            persistent: false,
            resources: [:]
        )
        XCTAssertEqual(manifest.resolvedVersion, "0.0.1")
    }

    func testWebManifestResolvedVersionCustom() {
        let manifest = PersistentManifestLoader.WebManifest(
            persistent: false,
            resources: [:],
            version: "2.5.0"
        )
        XCTAssertEqual(manifest.resolvedVersion, "2.5.0")
    }

    // MARK: - LoaderError

    func testLoaderErrorDescriptions() {
        let errors: [PersistentManifestLoader.LoaderError] = [
            .manifestNotFound,
            .invalidManifestFormat,
            .persistentModeDisabled,
            .cacheDirectoryCreationFailed,
            .webViewNotAvailable
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testLoaderErrorHTMLDownloadFailed() {
        let underlying = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "timeout"])
        let error = PersistentManifestLoader.LoaderError.htmlDownloadFailed(underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("timeout"))
    }

    func testLoaderErrorResourceDownloadFailed() {
        let underlying = NSError(domain: "test", code: -1, userInfo: nil)
        let error = PersistentManifestLoader.LoaderError.resourceDownloadFailed("image.png", underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("image.png"))
    }

    // MARK: - LoadingState Cases

    func testAllLoadingStatesExist() {
        let _: [PersistentManifestLoader.LoadingState] = [
            .idle,
            .fetchingManifest,
            .downloadingResources(current: 0, total: 10),
            .preparingHTML,
            .loadingWebView,
            .completed,
            .failed(NSError(domain: "test", code: -1))
        ]
    }

    // MARK: - loadFromCache

    func testLoadFromCacheFailsForNonexistentURL() {
        let webView = WKWebView()
        let url = URL(string: "https://nonexistent-site-xyz.com/page")!
        let expectation = self.expectation(description: "loadFromCache")

        loader.loadFromCache(url: url, in: webView) { result in
            if case .failure = result {
                // Expected
            } else {
                XCTFail("Expected failure for nonexistent cache")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3.0)
    }
}
