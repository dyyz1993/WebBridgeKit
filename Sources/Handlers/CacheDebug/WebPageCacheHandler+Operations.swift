//
//  WebPageCacheHandler+Operations.swift
//  WebBridgeKit
//
//  Extracted from WebPageCacheHandler.swift
//

import Foundation
import UIKit

extension PageCacheManager {

    // MARK: - Private Methods

    func loadHTMLContent(for pageName: String) async throws -> String {
        if let html = try? await loadFromTestResources(pageName: pageName) {
            return html
        }

        if let html = loadFromBundle(pageName: pageName) {
            return html
        }

        if let html = try? await loadFromHTTPServer(pageName: pageName) {
            return html
        }

        throw WebBridgeError.cacheLoadFailed(
            reason: "Failed to load HTML content for page '\(pageName)' from any source"
        )
    }

    func loadFromTestResources(pageName: String) async throws -> String {
        return try await PerformanceMonitor.shared.measure(
            "PageCache.loadFromTestResources",
            metadata: ["pageName": pageName, "source": "test_resources"]
        ) {
            try NetworkMonitor.shared.ensureNetworkAvailable()

            guard try await self.isTestServerRunning() else {
                throw WebBridgeError.networkRequestFailed(reason: "Test server is not running")
            }

            let urlString = "http://localhost:8080/\(pageName).html"
            guard let url = URL(string: urlString) else {
                throw WebBridgeError.invalidInput("Invalid URL: \(urlString)")
            }

            do {
                let (data, response) = try await self.urlSession.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WebBridgeError.networkRequestFailed(reason: "Invalid HTTP response")
                }

                guard httpResponse.statusCode == 200 else {
                    throw WebBridgeError.networkRequestFailed(
                        reason: "HTTP status code: \(httpResponse.statusCode)"
                    )
                }

                guard let html = String(data: data, encoding: .utf8) else {
                    throw WebBridgeError.cacheLoadFailed(reason: "Failed to decode HTML as UTF-8")
                }

                WebBridgeLogger.shared.log(.info, "📥 [PageCache] Loaded from test_resources: \(pageName)")
                return html

            } catch let error as WebBridgeError {
                throw error
            } catch {
                WebBridgeLogger.shared.log(.error, "❌ [PageCache] Failed to load from test_resources: \(error)")
                throw WebBridgeError.networkRequestFailed(reason: error.localizedDescription)
            }
        }
    }

    func loadFromBundle(pageName: String) -> String? {
        return PerformanceMonitor.shared.measure(
            "PageCache.loadFromBundle",
            metadata: ["pageName": pageName, "source": "bundle"]
        ) {
            guard let path = Bundle.main.path(forResource: pageName, ofType: "html") else {
                return nil
            }

            do {
                let html = try String(contentsOfFile: path, encoding: .utf8)
                WebBridgeLogger.shared.log(.info, "📦 [PageCache] Loaded from bundle: \(pageName)")
                return html
            } catch {
                WebBridgeLogger.shared.log(.error, "❌ [PageCache] Failed to load from bundle: \(error)")
                return nil
            }
        }
    }

    func loadFromHTTPServer(pageName: String) async throws -> String {
        throw WebBridgeError.networkRequestFailed(reason: "HTTP server loading not implemented")
    }

    func getBaseURL() async throws -> URL {
        if try await isTestServerRunning() {
            guard let url = URL(string: "http://localhost:8080/") else {
                throw WebBridgeError.invalidInput("Failed to create test server URL")
            }
            return url
        }

        return Bundle.main.bundleURL
    }

    func isTestServerRunning() async throws -> Bool {
        guard let url = URL(string: "http://localhost:8080/") else {
            throw WebBridgeError.invalidInput("Invalid test server URL")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        request.httpMethod = "HEAD"

        do {
            let (_, response) = try await urlSession.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }

            return false

        } catch let error as URLError {
            if error.code == .timedOut || error.code == .cannotConnectToHost || error.code == .networkConnectionLost {
                return false
            }
            throw WebBridgeError.networkRequestFailed(reason: error.localizedDescription)
        } catch {
            throw WebBridgeError.networkRequestFailed(reason: "Unknown error: \(error.localizedDescription)")
        }
    }

    func evictLeastRecentlyUsed() {
        guard !pageCache.isEmpty else { return }

        let sortedPages = pageCache.values.sorted { page1, page2 in
            let score1 = calculateEvictionScore(for: page1)
            let score2 = calculateEvictionScore(for: page2)
            return score1 < score2
        }

        if let toEvict = sortedPages.first {
            let evictedSize = toEvict.estimatedSizeKB / 1024
            pageCache.removeValue(forKey: toEvict.pageName)
            WebBridgeLogger.shared.log(.info, "🧹 [PageCache] Evicted '\(toEvict.pageName)' (hitCount: \(toEvict.hitCount), size: \(evictedSize)MB) due to count limit")
        }
    }

    func evictToFreeMemory(requiredMB: Int) {
        var freedMB = 0
        let targetFreeMB = requiredMB + (maxMemorySizeMB / 10)

        let sortedPages = pageCache.values.sorted { page1, page2 in
            let score1 = calculateEvictionScore(for: page1)
            let score2 = calculateEvictionScore(for: page2)
            return score1 < score2
        }

        for page in sortedPages {
            if freedMB >= targetFreeMB {
                break
            }

            let pageSizeMB = page.estimatedSizeKB / 1024
            pageCache.removeValue(forKey: page.pageName)
            freedMB += pageSizeMB

            WebBridgeLogger.shared.log(.info, "🧹 [PageCache] Evicted '\(page.pageName)' (hitCount: \(page.hitCount), size: \(pageSizeMB)MB) to free memory")
        }

        WebBridgeLogger.shared.log(.info, "🧹 [PageCache] Memory eviction: freed \(freedMB)MB")
    }

    func calculateEvictionScore(for page: CachedPage) -> Double {
        let hitScore = Double(page.hitCount) * 10.0

        let daysSinceCached = Date().timeIntervalSince(page.cachedAt) / 86400.0
        let timeScore = max(0, 100.0 - daysSinceCached * 10.0)

        let sizeScore = max(0, 50.0 - Double(page.estimatedSizeKB) / 1024.0)

        return hitScore + timeScore + sizeScore
    }

    func calculateCurrentMemoryUsage() -> Int {
        let totalKB = pageCache.values.reduce(0) { $0 + $1.estimatedSizeKB }
        return totalKB / 1024
    }
}
