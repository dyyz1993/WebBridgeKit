import XCTest
@testable import WebBridgeKit

final class BuiltinAIToolsTests: XCTestCase {

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

    // MARK: - Tool Metadata: Read-write Tools

    func testExecuteHandlerMetadata() {
        let tool = BuiltinAITools.executeHandler
        XCTAssertEqual(tool.name, "execute_handler")
        XCTAssertEqual(tool.category, "action")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertEqual(tool.parameters.count, 2)
        let nameParam = tool.parameters.first { $0.name == "name" }
        XCTAssertTrue(nameParam?.required ?? false)
        let paramsParam = tool.parameters.first { $0.name == "params" }
        XCTAssertNotNil(paramsParam)
        XCTAssertFalse(paramsParam?.required ?? true)
    }

    func testClearCacheMetadata() {
        let tool = BuiltinAITools.clearCache
        XCTAssertEqual(tool.name, "clear_cache")
        XCTAssertEqual(tool.category, "action")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertEqual(tool.parameters.count, 1)
        XCTAssertEqual(tool.parameters[0].name, "prefix")
        XCTAssertFalse(tool.parameters[0].required)
    }

    func testSendTestPushMetadata() {
        let tool = BuiltinAITools.sendTestPush
        XCTAssertEqual(tool.name, "send_test_push")
        XCTAssertEqual(tool.category, "action")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertEqual(tool.parameters.count, 4)
        let titleParam = tool.parameters.first { $0.name == "title" }
        let bodyParam = tool.parameters.first { $0.name == "body" }
        XCTAssertTrue(titleParam?.required ?? false)
        XCTAssertTrue(bodyParam?.required ?? false)
        let groupParam = tool.parameters.first { $0.name == "group" }
        XCTAssertFalse(groupParam?.required ?? true)
        let urlParam = tool.parameters.first { $0.name == "url" }
        XCTAssertFalse(urlParam?.required ?? true)
    }

    func testReloadConfigMetadata() {
        let tool = BuiltinAITools.reloadConfig
        XCTAssertEqual(tool.name, "reload_config")
        XCTAssertEqual(tool.category, "action")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertEqual(tool.parameters.count, 1)
        XCTAssertTrue(tool.parameters[0].required)
        XCTAssertEqual(tool.parameters[0].name, "type")
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

    // MARK: - execute_handler Execution

    func testExecuteHandlerMissingNameThrows() async {
        do {
            _ = try await BuiltinAITools.executeHandler.execute(params: [:])
            XCTFail("Should have thrown for missing handler name")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }

    func testExecuteHandlerNonExistent() async throws {
        let result = try await BuiltinAITools.executeHandler.execute(params: ["name": "nonexistent_xyz"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, false)
        XCTAssertNotNil(dict["error"] as? String)
        XCTAssertNotNil(dict["availableHandlers"])
    }

    func testExecuteHandlerWithParams() async throws {
        let result = try await BuiltinAITools.executeHandler.execute(params: [
            "name": "getSystemInfo",
            "params": ["detail": true] as [String: Any]
        ])
        let dict = result as? [String: Any]
        XCTAssertNotNil(dict)
    }

    func testExecuteHandlerWithoutParams() async throws {
        let result = try await BuiltinAITools.executeHandler.execute(params: ["name": "vibrate"])
        let dict = result as? [String: Any]
        XCTAssertNotNil(dict)
    }

    func testExecuteHandlerAvailableHandlersIsArray() async throws {
        let result = try await BuiltinAITools.executeHandler.execute(params: ["name": "nonexistent"])
        let dict = try XCTUnwrap(result as? [String: Any])
        let available = dict["availableHandlers"] as? [String]
        XCTAssertNotNil(available)
    }

    // MARK: - clear_cache Execution

    func testClearCacheAll() async throws {
        let result = try await BuiltinAITools.clearCache.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
        XCTAssertEqual(dict["action"] as? String, "clearAll")
        XCTAssertNotNil(dict["previousStats"])
    }

    func testClearCacheWithPrefix() async throws {
        let result = try await BuiltinAITools.clearCache.execute(params: ["prefix": "test_prefix"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
        XCTAssertEqual(dict["action"] as? String, "partial")
        XCTAssertEqual(dict["clearedKey"] as? String, "test_prefix")
    }

    func testClearCacheWithEmptyPrefixClearsAll() async throws {
        let result = try await BuiltinAITools.clearCache.execute(params: ["prefix": ""])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
        XCTAssertEqual(dict["action"] as? String, "clearAll")
    }

    func testClearCachePreviousStatsStructure() async throws {
        let result = try await BuiltinAITools.clearCache.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let stats = try XCTUnwrap(dict["previousStats"] as? [String: Any])
        XCTAssertNotNil(stats["totalRequests"])
        XCTAssertNotNil(stats["entries"])
        XCTAssertNotNil(stats["size"])
    }

    // MARK: - send_test_push Execution

    func testSendTestPushMissingTitleThrows() async {
        do {
            _ = try await BuiltinAITools.sendTestPush.execute(params: ["body": "test"])
            XCTFail("Should have thrown for missing title")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }

    func testSendTestPushMissingBodyThrows() async {
        do {
            _ = try await BuiltinAITools.sendTestPush.execute(params: ["title": "test"])
            XCTFail("Should have thrown for missing body")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }

    func testSendTestPushMissingBothThrows() async {
        do {
            _ = try await BuiltinAITools.sendTestPush.execute(params: [:])
            XCTFail("Should have thrown for missing title and body")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }

    func testSendTestPushNoBarkChannel() async throws {
        let result = try await BuiltinAITools.sendTestPush.execute(params: [
            "title": "Test Title",
            "body": "Test Body"
        ])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, false)
        XCTAssertNotNil(dict["error"] as? String)
        XCTAssertNotNil(dict["availableChannels"])
    }

    func testSendTestPushWithOptionalParams() async throws {
        let result = try await BuiltinAITools.sendTestPush.execute(params: [
            "title": "Title",
            "body": "Body",
            "group": "test_group",
            "url": "https://example.com"
        ])
        let dict = result as? [String: Any]
        XCTAssertNotNil(dict)
    }

    // MARK: - reload_config Execution

    func testReloadConfigLogging() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "logging"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
        let reloaded = try XCTUnwrap(dict["reloaded"] as? [String])
        XCTAssertTrue(reloaded.contains("logging (buffer cleared)"))
        XCTAssertNotNil(dict["newState"])
    }

    func testReloadConfigLoggingNewState() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "logging"])
        let dict = try XCTUnwrap(result as? [String: Any])
        let newState = try XCTUnwrap(dict["newState"] as? [String: Any])
        XCTAssertNotNil(newState["bufferEntries"])
        XCTAssertNotNil(newState["minLevel"])
        XCTAssertNotNil(newState["sessionId"])
    }

    func testReloadConfigCacheStats() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "cache_stats"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
        let reloaded = try XCTUnwrap(dict["reloaded"] as? [String])
        XCTAssertTrue(reloaded.contains("cache_stats"))
    }

    func testReloadConfigCacheStatsNewState() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "cache_stats"])
        let dict = try XCTUnwrap(result as? [String: Any])
        let newState = try XCTUnwrap(dict["newState"] as? [String: Any])
        XCTAssertNotNil(newState["totalRequests"])
        XCTAssertNotNil(newState["hitRate"])
        XCTAssertNotNil(newState["entries"])
    }

    func testReloadConfigAll() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "all"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
        let reloaded = try XCTUnwrap(dict["reloaded"] as? [String])
        XCTAssertTrue(reloaded.contains("logging"))
        XCTAssertTrue(reloaded.contains("cache_stats"))
    }

    func testReloadConfigAllNewState() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "all"])
        let dict = try XCTUnwrap(result as? [String: Any])
        let newState = try XCTUnwrap(dict["newState"] as? [String: Any])
        XCTAssertNotNil(newState["logging"])
        XCTAssertNotNil(newState["cache"])
    }

    func testReloadConfigUnknownType() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "unknown_type_xyz"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, false)
        XCTAssertNotNil(dict["error"] as? String)
    }

    func testReloadConfigMissingTypeThrows() async {
        do {
            _ = try await BuiltinAITools.reloadConfig.execute(params: [:])
            XCTFail("Should have thrown for missing type")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }

    func testReloadConfigCaseInsensitive() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "LOGGING"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
    }

    func testReloadConfigMixedCase() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "Cache_Stats"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
    }

    // MARK: - MCP Tool Definitions for All Builtin Tools

    func testAllToolsHaveMCPDefinitions() {
        for tool in BuiltinAITools.all {
            let def = tool.toMCPToolDefinition()
            XCTAssertEqual(def["name"] as? String, tool.name, "Tool \(tool.name) MCP name mismatch")
            XCTAssertEqual(def["description"] as? String, tool.description, "Tool \(tool.name) MCP description mismatch")
            let schema = def["inputSchema"] as? [String: Any]
            XCTAssertNotNil(schema, "Tool \(tool.name) should have inputSchema")
            XCTAssertEqual(schema?["type"] as? String, "object", "Tool \(tool.name) inputSchema type should be object")
        }
    }

    func testAllToolsMCPDefinitionsIncludeRequiredParams() {
        for tool in BuiltinAITools.all {
            let def = tool.toMCPToolDefinition()
            let schema = def["inputSchema"] as? [String: Any]
            let required = schema?["required"] as? [String] ?? []
            let expectedRequired = tool.parameters.filter { $0.required }.map { $0.name }
            XCTAssertEqual(required.sorted(), expectedRequired.sorted(), "Tool \(tool.name) required params mismatch")
        }
    }

    func testAllToolsMCPDefinitionsIncludeAllProperties() {
        for tool in BuiltinAITools.all {
            let def = tool.toMCPToolDefinition()
            let schema = def["inputSchema"] as? [String: Any]
            let properties = schema?["properties"] as? [String: Any]
            XCTAssertNotNil(properties, "Tool \(tool.name) should have properties in inputSchema")
            for param in tool.parameters {
                let prop = properties?[param.name] as? [String: Any]
                XCTAssertNotNil(prop, "Tool \(tool.name) should have property for \(param.name)")
                XCTAssertEqual(prop?["type"] as? String, param.type, "Tool \(tool.name) param \(param.name) type mismatch")
                XCTAssertEqual(prop?["description"] as? String, param.description, "Tool \(tool.name) param \(param.name) description mismatch")
            }
        }
    }

    func testToolWithNoParamsHasEmptyProperties() {
        let tool = AITool(name: "noparams", description: "No params", parameters: []) { _ in return "ok" }
        let def = tool.toMCPToolDefinition()
        let schema = def["inputSchema"] as? [String: Any]
        let properties = schema?["properties"] as? [String: Any]
        XCTAssertTrue(properties?.isEmpty ?? false)
        XCTAssertNil(schema?["required"])
    }

    func testToolWithOnlyOptionalParamsHasNoRequired() {
        let tool = AITool(
            name: "optional_only",
            description: "All optional",
            parameters: [
                AIParameter(name: "a", type: "string", description: "Optional A"),
                AIParameter(name: "b", type: "integer", description: "Optional B")
            ]
        ) { _ in return "ok" }
        let def = tool.toMCPToolDefinition()
        let schema = def["inputSchema"] as? [String: Any]
        XCTAssertNil(schema?["required"])
    }
}
