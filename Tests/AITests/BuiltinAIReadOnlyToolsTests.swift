import XCTest
@testable import WebBridgeKit

extension BuiltinAIToolsTests {

    // MARK: - Tool Metadata: Read-only Tools

    func testListHandlersMetadata() {
        let tool = BuiltinAITools.listHandlers
        XCTAssertEqual(tool.name, "list_handlers")
        XCTAssertEqual(tool.category, "query")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertEqual(tool.parameters.count, 1)
        XCTAssertEqual(tool.parameters[0].name, "category")
        XCTAssertFalse(tool.parameters[0].required)
    }

    func testGetHandlerDetailMetadata() {
        let tool = BuiltinAITools.getHandlerDetail
        XCTAssertEqual(tool.name, "get_handler_detail")
        XCTAssertEqual(tool.category, "query")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertEqual(tool.parameters.count, 1)
        XCTAssertTrue(tool.parameters[0].required)
        XCTAssertEqual(tool.parameters[0].name, "name")
    }

    func testGetCacheStatsMetadata() {
        let tool = BuiltinAITools.getCacheStats
        XCTAssertEqual(tool.name, "get_cache_stats")
        XCTAssertEqual(tool.category, "query")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertTrue(tool.parameters.isEmpty)
    }

    func testGetCacheEntriesMetadata() {
        let tool = BuiltinAITools.getCacheEntries
        XCTAssertEqual(tool.name, "get_cache_entries")
        XCTAssertEqual(tool.category, "query")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertEqual(tool.parameters.count, 1)
        XCTAssertEqual(tool.parameters[0].name, "filter")
        XCTAssertFalse(tool.parameters[0].required)
    }

    func testGetMessageStatsMetadata() {
        let tool = BuiltinAITools.getMessageStats
        XCTAssertEqual(tool.name, "get_message_stats")
        XCTAssertEqual(tool.category, "query")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertTrue(tool.parameters.isEmpty)
    }

    func testGetRecentErrorsMetadata() {
        let tool = BuiltinAITools.getRecentErrors
        XCTAssertEqual(tool.name, "get_recent_errors")
        XCTAssertEqual(tool.category, "query")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertEqual(tool.parameters.count, 2)
        let countParam = tool.parameters.first { $0.name == "count" }
        XCTAssertNotNil(countParam)
        XCTAssertEqual(countParam?.type, "integer")
        XCTAssertFalse(countParam?.required ?? true)
        let levelParam = tool.parameters.first { $0.name == "level" }
        XCTAssertNotNil(levelParam)
        XCTAssertEqual(levelParam?.type, "string")
    }

    func testGetConfigMetadata() {
        let tool = BuiltinAITools.getConfig
        XCTAssertEqual(tool.name, "get_config")
        XCTAssertEqual(tool.category, "query")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertTrue(tool.parameters.isEmpty)
    }

    func testReadFileMetadata() {
        let tool = BuiltinAITools.readFile
        XCTAssertEqual(tool.name, "read_file")
        XCTAssertEqual(tool.category, "query")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertEqual(tool.parameters.count, 2)
        let pathParam = tool.parameters.first { $0.name == "path" }
        XCTAssertNotNil(pathParam)
        XCTAssertTrue(pathParam?.required ?? false)
        let dirParam = tool.parameters.first { $0.name == "directory" }
        XCTAssertNotNil(dirParam)
        XCTAssertFalse(dirParam?.required ?? true)
    }

    func testGetDiagnosticReportMetadata() {
        let tool = BuiltinAITools.getDiagnosticReport
        XCTAssertEqual(tool.name, "get_diagnostic_report")
        XCTAssertEqual(tool.category, "query")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertTrue(tool.parameters.isEmpty)
    }

    // MARK: - All Tools Collection

    func testAllToolsCount() {
        XCTAssertEqual(BuiltinAITools.all.count, 13)
    }

    func testAllToolNamesAreUnique() {
        let names = BuiltinAITools.all.map { $0.name }
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testAllToolsHaveNonEmptyDescriptions() {
        for tool in BuiltinAITools.all {
            XCTAssertFalse(tool.description.isEmpty, "Tool \(tool.name) should have a description")
        }
    }

    func testAllToolsHaveValidCategories() {
        let validCategories: Set<String> = ["query", "action"]
        for tool in BuiltinAITools.all {
            XCTAssertTrue(validCategories.contains(tool.category), "Tool \(tool.name) has invalid category: \(tool.category)")
        }
    }

    func testAllToolsContainExpectedNames() {
        let names = Set(BuiltinAITools.all.map { $0.name })
        XCTAssertTrue(names.contains("list_handlers"))
        XCTAssertTrue(names.contains("get_handler_detail"))
        XCTAssertTrue(names.contains("get_cache_stats"))
        XCTAssertTrue(names.contains("get_cache_entries"))
        XCTAssertTrue(names.contains("get_message_stats"))
        XCTAssertTrue(names.contains("get_recent_errors"))
        XCTAssertTrue(names.contains("get_config"))
        XCTAssertTrue(names.contains("read_file"))
        XCTAssertTrue(names.contains("get_diagnostic_report"))
        XCTAssertTrue(names.contains("execute_handler"))
        XCTAssertTrue(names.contains("clear_cache"))
        XCTAssertTrue(names.contains("send_test_push"))
        XCTAssertTrue(names.contains("reload_config"))
    }

    // MARK: - list_handlers Execution

    func testListHandlersExecute() async throws {
        let result = try await BuiltinAITools.listHandlers.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["count"])
        XCTAssertNotNil(dict["handlers"])
        XCTAssertNotNil(dict["categories"])
    }

    func testListHandlersWithValidCategoryFilter() async throws {
        let result = try await BuiltinAITools.listHandlers.execute(params: ["category": "hardware"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["handlers"])
    }

    func testListHandlersWithInvalidCategoryFilter() async throws {
        let result = try await BuiltinAITools.listHandlers.execute(params: ["category": "nonexistent_category"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["handlers"])
    }

    func testListHandlersHandlersIsArray() async throws {
        let result = try await BuiltinAITools.listHandlers.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let handlers = dict["handlers"] as? [[String: Any]]
        XCTAssertNotNil(handlers)
    }

    func testListHandlersCategoriesIsArray() async throws {
        let result = try await BuiltinAITools.listHandlers.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let categories = dict["categories"] as? [[String: Any]]
        XCTAssertNotNil(categories)
    }

    // MARK: - get_handler_detail Execution

    func testGetHandlerDetailMissingNameThrows() async {
        do {
            _ = try await BuiltinAITools.getHandlerDetail.execute(params: [:])
            XCTFail("Should have thrown for missing name")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }

    func testGetHandlerDetailNonExistentHandler() async throws {
        let result = try await BuiltinAITools.getHandlerDetail.execute(params: ["name": "nonexistent_handler_xyz_123"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["found"] as? Bool, false)
        XCTAssertNotNil(dict["message"] as? String)
    }

    func testGetHandlerDetailWithEmptyName() async throws {
        let result = try await BuiltinAITools.getHandlerDetail.execute(params: ["name": ""])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["found"] as? Bool, false)
    }

    // MARK: - get_cache_stats Execution

    func testGetCacheStatsExecute() async throws {
        let result = try await BuiltinAITools.getCacheStats.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["global"])
        XCTAssertNotNil(dict["memory"])
        XCTAssertNotNil(dict["disk"])
    }

    func testGetCacheStatsGlobalHasExpectedKeys() async throws {
        let result = try await BuiltinAITools.getCacheStats.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let global = try XCTUnwrap(dict["global"] as? [String: Any])
        XCTAssertNotNil(global["totalRequests"])
        XCTAssertNotNil(global["hits"])
        XCTAssertNotNil(global["misses"])
        XCTAssertNotNil(global["hitRate"])
        XCTAssertNotNil(global["totalSize"])
        XCTAssertNotNil(global["totalSizeBytes"])
        XCTAssertNotNil(global["totalEntries"])
    }

    func testGetCacheStatsMemoryHasExpectedKeys() async throws {
        let result = try await BuiltinAITools.getCacheStats.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let memory = try XCTUnwrap(dict["memory"] as? [String: Any])
        XCTAssertNotNil(memory["hits"])
        XCTAssertNotNil(memory["misses"])
        XCTAssertNotNil(memory["hitRate"])
        XCTAssertNotNil(memory["size"])
        XCTAssertNotNil(memory["entries"])
    }

    func testGetCacheStatsDiskHasExpectedKeys() async throws {
        let result = try await BuiltinAITools.getCacheStats.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let disk = try XCTUnwrap(dict["disk"] as? [String: Any])
        XCTAssertNotNil(disk["hits"])
        XCTAssertNotNil(disk["misses"])
        XCTAssertNotNil(disk["hitRate"])
        XCTAssertNotNil(disk["size"])
        XCTAssertNotNil(disk["entries"])
    }

    // MARK: - get_cache_entries Execution

    func testGetCacheEntriesExecute() async throws {
        let result = try await BuiltinAITools.getCacheEntries.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["totalEntries"])
        XCTAssertNotNil(dict["recentCacheActivity"])
        XCTAssertNotNil(dict["note"])
    }

    func testGetCacheEntriesWithFilter() async throws {
        let result = try await BuiltinAITools.getCacheEntries.execute(params: ["filter": "test_key"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["recentCacheActivity"])
    }

    func testGetCacheEntriesWithEmptyFilter() async throws {
        let result = try await BuiltinAITools.getCacheEntries.execute(params: ["filter": ""])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["recentCacheActivity"])
    }

    func testGetCacheEntriesRecentActivityIsArray() async throws {
        let result = try await BuiltinAITools.getCacheEntries.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let activity = dict["recentCacheActivity"] as? [[String: Any]]
        XCTAssertNotNil(activity)
    }

    // MARK: - get_message_stats Execution

    func testGetMessageStatsExecute() async throws {
        let result = try await BuiltinAITools.getMessageStats.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["totalReceived"])
        XCTAssertNotNil(dict["totalSent"])
        XCTAssertNotNil(dict["totalFailed"])
        XCTAssertNotNil(dict["totalQueued"])
        XCTAssertNotNil(dict["unreadCount"])
        XCTAssertNotNil(dict["channels"])
        XCTAssertNotNil(dict["byChannel"])
        XCTAssertNotNil(dict["lastUpdated"])
    }

    func testGetMessageStatsChannelsIsArray() async throws {
        let result = try await BuiltinAITools.getMessageStats.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let channels = dict["channels"] as? [String]
        XCTAssertNotNil(channels)
    }

    // MARK: - get_recent_errors Execution

    func testGetRecentErrorsDefaultParams() async throws {
        let result = try await BuiltinAITools.getRecentErrors.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["count"])
        XCTAssertNotNil(dict["errors"])
        XCTAssertNotNil(dict["summary"])
    }

    func testGetRecentErrorsWithCount() async throws {
        let result = try await BuiltinAITools.getRecentErrors.execute(params: ["count": 5])
        let dict = try XCTUnwrap(result as? [String: Any])
        let count = dict["count"] as? Int
        XCTAssertLessThanOrEqual(count ?? Int.max, 5)
    }

    func testGetRecentErrorsWithVerboseLevel() async throws {
        let result = try await BuiltinAITools.getRecentErrors.execute(params: ["level": "verbose"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["errors"])
    }

    func testGetRecentErrorsWithDebugLevel() async throws {
        let result = try await BuiltinAITools.getRecentErrors.execute(params: ["level": "debug"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["errors"])
    }

    func testGetRecentErrorsWithInfoLevel() async throws {
        let result = try await BuiltinAITools.getRecentErrors.execute(params: ["level": "info"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["errors"])
    }

    func testGetRecentErrorsWithWarningLevel() async throws {
        let result = try await BuiltinAITools.getRecentErrors.execute(params: ["level": "warning"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["errors"])
    }

    func testGetRecentErrorsWithErrorLevel() async throws {
        let result = try await BuiltinAITools.getRecentErrors.execute(params: ["level": "error"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["errors"])
    }

    func testGetRecentErrorsWithUnknownLevel() async throws {
        let result = try await BuiltinAITools.getRecentErrors.execute(params: ["level": "invalid_level"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["errors"])
    }

    func testGetRecentErrorsSummaryStructure() async throws {
        let result = try await BuiltinAITools.getRecentErrors.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let summary = try XCTUnwrap(dict["summary"] as? [String: Any])
        XCTAssertNotNil(summary["totalBufferEntries"])
        XCTAssertNotNil(summary["errorCount"])
        XCTAssertNotNil(summary["warningCount"])
    }

    func testGetRecentErrorsCountParamAsStringIgnored() async throws {
        let result = try await BuiltinAITools.getRecentErrors.execute(params: ["count": "ten"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["count"])
    }

    // MARK: - get_config Execution

    func testGetConfigExecute() async throws {
        let result = try await BuiltinAITools.getConfig.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["handlers"])
        XCTAssertNotNil(dict["message"])
        XCTAssertNotNil(dict["cache"])
        XCTAssertNotNil(dict["logging"])
        XCTAssertNotNil(dict["system"])
    }

    func testGetConfigHandlersSection() async throws {
        let result = try await BuiltinAITools.getConfig.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let handlers = try XCTUnwrap(dict["handlers"] as? [String: Any])
        XCTAssertNotNil(handlers["totalRegistered"])
        XCTAssertNotNil(handlers["categories"])
    }

    func testGetConfigSystemSection() async throws {
        let result = try await BuiltinAITools.getConfig.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let system = try XCTUnwrap(dict["system"] as? [String: Any])
        XCTAssertEqual(system["platform"] as? String, "iOS")
        XCTAssertNotNil(system["osVersion"])
        XCTAssertNotNil(system["deviceModel"])
    }

    func testGetConfigLoggingSection() async throws {
        let result = try await BuiltinAITools.getConfig.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let logging = try XCTUnwrap(dict["logging"] as? [String: Any])
        XCTAssertNotNil(logging["bufferEntries"])
        XCTAssertNotNil(logging["minLevel"])
        XCTAssertNotNil(logging["sessionId"])
    }

    // MARK: - read_file Execution

    func testReadFileMissingPathThrows() async {
        do {
            _ = try await BuiltinAITools.readFile.execute(params: [:])
            XCTFail("Should have thrown for missing path")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }

    func testReadFileNonExistentFile() async throws {
        let result = try await BuiltinAITools.readFile.execute(params: ["path": "nonexistent_file_xyz_123.txt"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["error"] as? String, "File not found")
    }

    func testReadFileWithDocumentsDirectory() async throws {
        let result = try await BuiltinAITools.readFile.execute(params: [
            "path": "test.txt",
            "directory": "documents"
        ])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["error"])
    }

    func testReadFileWithCachesDirectory() async throws {
        let result = try await BuiltinAITools.readFile.execute(params: [
            "path": "test.txt",
            "directory": "caches"
        ])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["error"])
    }

    func testReadFileWithTmpDirectory() async throws {
        let result = try await BuiltinAITools.readFile.execute(params: [
            "path": "nonexistent_\(UUID().uuidString).txt",
            "directory": "tmp"
        ])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["error"])
    }

    func testReadFileWithUnknownDirectoryDefaultsToDocuments() async throws {
        let result = try await BuiltinAITools.readFile.execute(params: [
            "path": "test.txt",
            "directory": "unknown_dir_xyz"
        ])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["error"])
    }

    // MARK: - get_diagnostic_report Execution

    func testGetDiagnosticReportExecute() async throws {
        let result = try await BuiltinAITools.getDiagnosticReport.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotNil(dict["timestamp"])
        XCTAssertNotNil(dict["handlers"])
        XCTAssertNotNil(dict["cache"])
        XCTAssertNotNil(dict["messages"])
        XCTAssertNotNil(dict["logging"])
        XCTAssertNotNil(dict["system"])
    }

    func testGetDiagnosticReportSystemPlatform() async throws {
        let result = try await BuiltinAITools.getDiagnosticReport.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let system = try XCTUnwrap(dict["system"] as? [String: Any])
        XCTAssertEqual(system["platform"] as? String, "iOS")
        XCTAssertNotNil(system["osVersion"])
        XCTAssertNotNil(system["kernelVersion"])
        XCTAssertNotNil(system["deviceModel"])
        XCTAssertNotNil(system["physicalMemory"])
        XCTAssertNotNil(system["uptime"])
        XCTAssertNotNil(system["processId"])
    }

    func testGetDiagnosticReportHandlersSection() async throws {
        let result = try await BuiltinAITools.getDiagnosticReport.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let handlers = try XCTUnwrap(dict["handlers"] as? [String: Any])
        XCTAssertNotNil(handlers["total"])
        XCTAssertNotNil(handlers["categories"])
    }

    func testGetDiagnosticReportMessagesSection() async throws {
        let result = try await BuiltinAITools.getDiagnosticReport.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let messages = try XCTUnwrap(dict["messages"] as? [String: Any])
        XCTAssertNotNil(messages["received"])
        XCTAssertNotNil(messages["sent"])
        XCTAssertNotNil(messages["failed"])
        XCTAssertNotNil(messages["unread"])
        XCTAssertNotNil(messages["channels"])
    }

    func testGetDiagnosticReportLoggingSection() async throws {
        let result = try await BuiltinAITools.getDiagnosticReport.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let logging = try XCTUnwrap(dict["logging"] as? [String: Any])
        XCTAssertNotNil(logging["bufferEntries"])
        XCTAssertNotNil(logging["errors"])
        XCTAssertNotNil(logging["warnings"])
    }
}
