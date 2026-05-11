//
//  LazyManifestLoaderTests.swift
//  HandlerTests
//

import XCTest
import WebKit
@testable import WebBridgeKit

final class LazyManifestLoaderTests: XCTestCase {

    private var loader: LazyManifestLoader!

    override func setUp() {
        super.setUp()
        loader = LazyManifestLoader.shared
    }

    override func tearDown() {
        loader.cancelAllDownloads()
        super.tearDown()
    }

    // MARK: - Singleton

    func testSharedSingletonIsSameInstance() {
        let a = LazyManifestLoader.shared
        let b = LazyManifestLoader.shared
        XCTAssertTrue(a === b)
    }

    // MARK: - Scheme

    func testSchemeIsCorrect() {
        XCTAssertEqual(loader.scheme, "custom")
    }

    // MARK: - WebManifest Init

    func testWebManifestInit() {
        let manifest = LazyManifestLoader.WebManifest(
            persistent: false,
            resources: ["style.css": "https://example.com/style.css"],
            version: "1.0.0",
            appid: "lazy-app",
            name: "Lazy App"
        )
        XCTAssertFalse(manifest.persistent)
        XCTAssertEqual(manifest.resources.count, 1)
        XCTAssertEqual(manifest.version, "1.0.0")
        XCTAssertEqual(manifest.appid, "lazy-app")
    }

    func testWebManifestResolvedVersionDefault() {
        let manifest = LazyManifestLoader.WebManifest(
            persistent: false,
            resources: [:]
        )
        XCTAssertEqual(manifest.resolvedVersion, "0.0.1")
    }

    func testWebManifestWithAllFields() {
        let manifest = LazyManifestLoader.WebManifest(
            persistent: true,
            resources: ["a.js": "https://a.com/a.js", "b.css": "https://a.com/b.css"],
            version: "3.0.0",
            appid: "full-app",
            name: "Full App",
            icon: "https://a.com/icon.png",
            updatedAt: "2025-01-01",
            description: "Test description"
        )
        XCTAssertTrue(manifest.persistent)
        XCTAssertEqual(manifest.resources.count, 2)
        XCTAssertEqual(manifest.icon, "https://a.com/icon.png")
        XCTAssertEqual(manifest.updatedAt, "2025-01-01")
        XCTAssertEqual(manifest.description, "Test description")
    }

    // MARK: - LazyLoadError

    func testLazyLoadErrorDescriptions() {
        let errors: [LazyManifestLoader.LazyLoadError] = [
            .manifestNotFound,
            .managerDeallocated
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testLazyLoadErrorManifestDownloadFailed() {
        let underlying = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "network"])
        let error = LazyManifestLoader.LazyLoadError.manifestDownloadFailed(underlying)
        XCTAssertTrue(error.errorDescription!.contains("network"))
    }

    func testLazyLoadErrorHTMLDownloadFailed() {
        let underlying = NSError(domain: "test", code: -2, userInfo: [NSLocalizedDescriptionKey: "timeout"])
        let error = LazyManifestLoader.LazyLoadError.htmlDownloadFailed(underlying)
        XCTAssertTrue(error.errorDescription!.contains("timeout"))
    }

    func testLazyLoadErrorResourceDownloadFailed() {
        let underlying = NSError(domain: "test", code: -3, userInfo: nil)
        let error = LazyManifestLoader.LazyLoadError.resourceDownloadFailed("style.css", underlying)
        XCTAssertTrue(error.errorDescription!.contains("style.css"))
    }

    // MARK: - Cancel Downloads

    func testCancelAllDownloadsDoesNotCrash() {
        loader.cancelAllDownloads()
    }

    // MARK: - Load Without Network

    func testLoadWithInvalidURLCallsCompletion() throws {
        guard UIScreen.screens.count > 0 else {
            throw XCTSkip("WKWebView requires a UI scene; skipping in headless CI environment")
        }
        let webView = WKWebView()
        let url = URL(string: "https://invalid-host-xyz123.invalid/page.html")!
        let expectation = self.expectation(description: "load")

        LazyManifestLoader.load(url: url, in: webView) { result in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }
}
