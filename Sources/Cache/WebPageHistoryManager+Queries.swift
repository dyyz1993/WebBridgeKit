//
//  WebPageHistoryManager+Queries.swift
//  WebBridgeKit
//
//  Extracted from WebPageHistoryManager.swift
//

import Foundation
import RealmSwift

// MARK: - Synchronous Compatibility Layer (DEPRECATED)
// These methods risk deadlock via DispatchSemaphore on the calling thread.
// Use the async equivalents on WebPageHistoryManager instead.

extension WebPageHistoryManager {

    @available(*, deprecated, message: "Use async addOrUpdateHistory(url:title:favicon:). Sync methods risk deadlock.")
    public func addOrUpdateHistory(url: URL, title: String? = nil, favicon: Data? = nil) {
        Task {
            try? await addOrUpdateHistory(url: url, title: title, favicon: favicon)
        }
    }

    @available(*, deprecated, message: "Use async deleteHistory(id:). Sync methods risk deadlock.")
    public func deleteHistory(id: String) {
        Task {
            try? await deleteHistory(id: id)
        }
    }

    @available(*, deprecated, message: "Use async clearAllHistory(). Sync methods risk deadlock.")
    public func clearAllHistory() {
        Task {
            try? await clearAllHistory()
        }
    }

    @available(*, deprecated, message: "Use async cleanupLowFrequencyItems(limit:). Sync methods risk deadlock.")
    public func cleanupLowFrequencyItems(limit: Int = 100) {
        Task {
            try? await cleanupLowFrequencyItems(limit: limit)
        }
    }

    @available(*, deprecated, message: "Use async getAllHistories(). Sync methods risk deadlock via DispatchSemaphore.")
    public func getAllHistories() -> [WebPageHistory] {
        var result: [WebPageHistory] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await getAllHistories()
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to get all histories: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    @available(*, deprecated, message: "Use async getCachedHistories(). Sync methods risk deadlock via DispatchSemaphore.")
    public func getCachedHistories() -> [WebPageHistory] {
        var result: [WebPageHistory] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await getCachedHistories()
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to get cached histories: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    @available(*, deprecated, message: "Use async findHistory(url:). Sync methods risk deadlock via DispatchSemaphore.")
    public func findHistory(url: URL) -> WebPageHistory? {
        var result: WebPageHistory?
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await findHistory(url: url)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to find history by URL: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    @available(*, deprecated, message: "Use async findHistory(id:). Sync methods risk deadlock via DispatchSemaphore.")
    public func findHistory(id: String) -> WebPageHistory? {
        var result: WebPageHistory?
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await findHistory(id: id)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to find history by ID: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    @available(*, deprecated, message: "Use async searchHistories(keyword:). Sync methods risk deadlock via DispatchSemaphore.")
    public func searchHistories(keyword: String) -> [WebPageHistory] {
        var result: [WebPageHistory] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await searchHistories(keyword: keyword)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to search histories: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    @available(*, deprecated, message: "Use async getTotalCount(). Sync methods risk deadlock via DispatchSemaphore.")
    public func getTotalCount() -> Int {
        var result: Int = 0
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await getTotalCount()
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to get total count: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    @available(*, deprecated, message: "Use async getTodayVisitCount(). Sync methods risk deadlock via DispatchSemaphore.")
    public func getTodayVisitCount() -> Int {
        var result: Int = 0
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await getTodayVisitCount()
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to get today visit count: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    @available(*, deprecated, message: "Use async getMostVisited(limit:). Sync methods risk deadlock via DispatchSemaphore.")
    public func getMostVisited(limit: Int = 10) -> [WebPageHistory] {
        var result: [WebPageHistory] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await getMostVisited(limit: limit)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to get most visited: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }
}
