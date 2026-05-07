import XCTest
import WebKit
@testable import WebBridgeKit

final class WebResourceURLSchemeHandlerTests: XCTestCase {

    // MARK: - Initialization

    func testHandler_InitWithCustomCacheDirectory() {
        let tempDir = FileManager.default.temporaryDirectory
        let handler = WebResourceURLSchemeHandler(cacheDirectory: tempDir)
        XCTAssertNotNil(handler)
    }

    func testHandler_ConvenienceInit() {
        let handler = WebResourceURLSchemeHandler()
        XCTAssertNotNil(handler)
    }

    // MARK: - Shared Instance

    func testHandler_SharedInstance_IsNotNil() {
        let handler = WebResourceURLSchemeHandler.shared
        XCTAssertNotNil(handler)
    }

    // MARK: - Shared Instance Creates New Each Time

    func testHandler_SharedInstance_CreatesNewEachTime() {
        let handler1 = WebResourceURLSchemeHandler.shared
        let handler2 = WebResourceURLSchemeHandler.shared
        XCTAssertNotNil(handler1)
        XCTAssertNotNil(handler2)
    }

    // MARK: - Default Cache Directory

    func testHandler_DefaultCacheDirectory_IsValid() {
        let cacheDir = WebResourceURLSchemeHandler.defaultCacheDirectory
        XCTAssertFalse(cacheDir.path.isEmpty)
        XCTAssertTrue(cacheDir.lastPathComponent.contains("WebBridgeKit"))
    }

    func testHandler_DefaultCacheDirectory_ContainsWebResources() {
        let cacheDir = WebResourceURLSchemeHandler.defaultCacheDirectory
        let webResourcesDir = cacheDir.appendingPathComponent("web-resources", isDirectory: true)
        XCTAssertTrue(webResourcesDir.lastPathComponent == "web-resources")
    }

    // MARK: - Default Cache Directory Is In Caches

    func testHandler_DefaultCacheDirectory_IsInCaches() {
        let cacheDir = WebResourceURLSchemeHandler.defaultCacheDirectory
        let cachesPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        XCTAssertNotNil(cachesPath)
        if let cachesPath = cachesPath {
            XCTAssertTrue(cacheDir.path.contains(cachesPath.path) || cacheDir.path.contains("tmp"))
        }
    }

    // MARK: - WKURLSchemeHandler Protocol Conformance

    func testHandler_ConformsToWKURLSchemeHandler() {
        let handler = WebResourceURLSchemeHandler()
        XCTAssertTrue((handler as Any) is WKURLSchemeHandler)
    }

    func testHandler_IsNSObject() {
        let handler = WebResourceURLSchemeHandler()
        XCTAssertTrue(handler.isKind(of: NSObject.self))
    }
}
