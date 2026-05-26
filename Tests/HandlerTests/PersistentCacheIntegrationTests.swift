import XCTest
import WebKit
@testable import WebBridgeKit

final class PersistentCacheIntegrationTests: XCTestCase {

    private var loader: PersistentManifestLoader!

    static let testBaseURL = URL(string: "http://localhost:8081/test_resources/cases/persistent_with_id/")!
    static let manifestURL = URL(string: "http://localhost:8081/test_resources/cases/persistent_with_id/manifest.json")!

    override class func setUp() {
        super.setUp()
        let healthURL = URL(string: "http://localhost:8081/test_resources/cases/persistent_with_id/manifest.json")!
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: healthURL) { data, response, error in
            if let error = error {
                print("[SETUP-FAIL] test server not reachable: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("[SETUP-FAIL] unexpected status: \(http.statusCode)")
            } else if let data = data, let str = String(data: data, encoding: .utf8) {
                print("[SETUP-OK] manifest.json reachable: \(str.prefix(200))")
            }
            semaphore.signal()
        }.resume()
        let result = semaphore.wait(timeout: .now() + 5)
        if result == .timedOut {
            print("[SETUP-FAIL] test server health check timed out")
        }
    }

    override func setUp() {
        super.setUp()
        loader = PersistentManifestLoader.shared
    }

    override func tearDown() {
        loader.clearAllCache()
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
            semaphore.signal()
        }
        semaphore.wait()
        super.tearDown()
    }

    func test01_FetchManifestFromLocalServer() async throws {
        let manifest = try await loader.fetchManifest(from: Self.testBaseURL)
        XCTAssertTrue(manifest.persistent, "manifest.persistent should be true")
        XCTAssertEqual(manifest.appid, "com.test.persistent")
        XCTAssertEqual(manifest.resources.count, 2, "should have 2 resources")
        XCTAssertEqual(manifest.name, "持久化测试 (有 AppID)")
        print("[OK] test01: manifest fetched and decoded correctly")
    }

    func test02_FullPersistentCacheFlow() async throws {
        let url = Self.testBaseURL

        XCTAssertFalse(loader.isCached(url: url), "should not be cached before load")

        let config = WKWebViewConfiguration()
        let schemeHandler = ManifestURLSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "wb-resource")
        let webView = WKWebView(frame: .zero, configuration: config)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PersistentManifestLoader.load(url: url, in: webView) { result in
                switch result {
                case .success:
                    print("[OK] PersistentManifestLoader.load succeeded")
                    continuation.resume(returning: ())
                case .failure(let error):
                    print("[FAIL] PersistentManifestLoader.load failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }

        print("[DIAG] checking isCached after load...")
        let isCached = loader.isCached(url: url)
        XCTAssertTrue(isCached, "URL should be cached after persistent load")
        print("[OK] test02: full persistent cache flow succeeded, isCached=\(isCached)")
    }

    func test03_CacheFilesExist() async throws {
        let url = Self.testBaseURL

        let config = WKWebViewConfiguration()
        let schemeHandler = ManifestURLSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "wb-resource")
        let webView = WKWebView(frame: .zero, configuration: config)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PersistentManifestLoader.load(url: url, in: webView) { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let persistentCacheDir = appSupportDir.appendingPathComponent("WebBridgeKit/PersistentCache")

        var foundCacheDir: URL?
        if let contents = try? FileManager.default.contentsOfDirectory(at: persistentCacheDir, includingPropertiesForKeys: nil) {
            for dir in contents {
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
                let htmlPath = dir.appendingPathComponent("index.html")
                let originPath = dir.appendingPathComponent("origin_url.txt")
                if FileManager.default.fileExists(atPath: htmlPath.path),
                   let originURL = try? String(contentsOf: originPath, encoding: .utf8),
                   originURL == url.absoluteString {
                    foundCacheDir = dir
                    break
                }
            }
        }

        guard let cacheDir = foundCacheDir else {
            XCTFail("Cache directory not found for URL: \(url.absoluteString)")
            return
        }
        let cacheID = cacheDir.lastPathComponent
        print("[DIAG] found cacheDir: \(cacheDir.path), cacheID: \(cacheID)")
        print("[DIAG] cacheDir: \(cacheDir.path)")
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheDir.path, isDirectory: &isDir), "cache directory should exist")
        XCTAssertTrue(isDir.boolValue, "cache path should be a directory")

        let htmlPath = cacheDir.appendingPathComponent("index.html")
        let manifestPath = cacheDir.appendingPathComponent("manifest.json")
        let originPath = cacheDir.appendingPathComponent("origin_url.txt")

        XCTAssertTrue(FileManager.default.fileExists(atPath: htmlPath.path), "index.html should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestPath.path), "manifest.json should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: originPath.path), "origin_url.txt should exist")

        if let htmlData = try? Data(contentsOf: htmlPath),
           let html = String(data: htmlData, encoding: .utf8) {
            XCTAssertFalse(html.isEmpty, "HTML should not be empty")
            print("[OK] index.html size: \(html.count) chars")
        } else {
            XCTFail("Failed to read index.html")
        }

        if let manifestData = try? Data(contentsOf: manifestPath),
           let savedManifest = try? JSONDecoder().decode(PersistentManifestLoader.WebManifest.self, from: manifestData) {
            XCTAssertTrue(savedManifest.persistent, "saved manifest should have persistent=true")
            XCTAssertEqual(savedManifest.appid, "com.test.persistent")
            print("[OK] saved manifest.json parsed correctly")
        } else {
            XCTFail("Failed to read or parse saved manifest.json")
        }

        if let originURL = try? String(contentsOf: originPath, encoding: .utf8) {
            XCTAssertEqual(originURL, url.absoluteString, "origin_url.txt should match original URL")
            print("[OK] origin_url.txt matches")
        } else {
            XCTFail("Failed to read origin_url.txt")
        }

        print("[OK] test03: all cache files verified")
    }

    func test04_LoadFromCache() async throws {
        let url = Self.testBaseURL

        let config = WKWebViewConfiguration()
        let schemeHandler = ManifestURLSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "wb-resource")
        let webView = WKWebView(frame: .zero, configuration: config)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PersistentManifestLoader.load(url: url, in: webView) { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        XCTAssertTrue(loader.isCached(url: url), "should be cached after first load")

        let config2 = WKWebViewConfiguration()
        let schemeHandler2 = ManifestURLSchemeHandler()
        config2.setURLSchemeHandler(schemeHandler2, forURLScheme: "wb-resource")
        let webView2 = WKWebView(frame: .zero, configuration: config2)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            loader.loadFromCache(url: url, in: webView2) { result in
                switch result {
                case .success:
                    print("[OK] loadFromCache succeeded")
                    continuation.resume(returning: ())
                case .failure(let error):
                    print("[FAIL] loadFromCache failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }

        print("[OK] test04: loadFromCache succeeded")
    }

    func test05_CacheSizeIsPositive() async throws {
        let url = Self.testBaseURL

        let config = WKWebViewConfiguration()
        let schemeHandler = ManifestURLSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "wb-resource")
        let webView = WKWebView(frame: .zero, configuration: config)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PersistentManifestLoader.load(url: url, in: webView) { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        let totalSize = loader.getCacheSize()
        XCTAssertGreaterThan(totalSize, 0, "total cache size should be positive after caching")
        print("[OK] test05: total cache size = \(totalSize) bytes")
    }

}
