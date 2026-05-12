//
//  WebPageHistoryManager+Queries.swift
//  WebBridgeKit
//
//  Extracted from WebPageHistoryManager.swift
//

import Foundation
import RealmSwift

// MARK: - Synchronous Compatibility Layer
// These methods provide backward compatibility with existing code
// that calls the manager synchronously. They wrap the async methods.

extension WebPageHistoryManager {

    /// Synchronous version of addOrUpdateHistory for backward compatibility
    public func addOrUpdateHistory(url: URL, title: String? = nil, favicon: Data? = nil) {
        Task {
            try? await addOrUpdateHistory(url: url, title: title, favicon: favicon)
        }
    }

    /// Synchronous version of deleteHistory for backward compatibility
    public func deleteHistory(id: String) {
        Task {
            try? await deleteHistory(id: id)
        }
    }

    /// Synchronous version of clearAllHistory for backward compatibility
    public func clearAllHistory() {
        Task {
            try? await clearAllHistory()
        }
    }

    /// Synchronous version of cleanupLowFrequencyItems for backward compatibility
    public func cleanupLowFrequencyItems(limit: Int = 100) {
        Task {
            try? await cleanupLowFrequencyItems(limit: limit)
        }
    }

    /// Synchronous version of getAllHistories for backward compatibility
    /// Returns empty array on error
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

    /// Synchronous version of getCachedHistories for backward compatibility
    /// Returns empty array on error
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

    /// Synchronous version of findHistory(url:) for backward compatibility
    /// Returns nil on error
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

    /// Synchronous version of findHistory(id:) for backward compatibility
    /// Returns nil on error
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

    /// Synchronous version of searchHistories for backward compatibility
    /// Returns empty array on error
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

    /// Synchronous version of getTotalCount for backward compatibility
    /// Returns 0 on error
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

    /// Synchronous version of getTodayVisitCount for backward compatibility
    /// Returns 0 on error
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

    /// Synchronous version of getMostVisited for backward compatibility
    /// Returns empty array on error
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
