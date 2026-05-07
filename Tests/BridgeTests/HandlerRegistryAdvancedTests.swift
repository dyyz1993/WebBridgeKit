import XCTest
@testable import WebBridgeKit

final class HandlerRegistryAdvancedTests: XCTestCase {

    private var registry: HandlerRegistry!

    override func setUp() {
        super.setUp()
        registry = HandlerRegistry.shared
        _ = HandlerMetaRegistry.registerAll
    }

    func testHandlersReturnsEmptyForCategoryWithNoRegistrations() {
        let emptyCategoryHandlers = registry.handlers(category: .debug)
        let debugOnlyTestHandlers = emptyCategoryHandlers.filter { $0.action.contains("noDebugHandlerTest_") }
        XCTAssertEqual(debugOnlyTestHandlers.count, 0)
    }

    func testGenerateAPIDocMarkdownIncludesCategoryHeaders() {
        let md = registry.generateAPIDocMarkdown()

        for category in HandlerCategory.allCases {
            if category.emoji.isEmpty { continue }
            XCTAssertTrue(md.contains(category.displayName),
                          "Markdown should contain category display name: \(category.displayName)")
        }
    }

    func testGenerateAPIDocMarkdownIncludesHandlerActionAndName() {
        let md = registry.generateAPIDocMarkdown()

        XCTAssertTrue(md.contains("camera"))
        XCTAssertTrue(md.contains("bluetooth"))
        XCTAssertTrue(md.contains("getLocation"))
    }

    func testGenerateAPIDocMarkdownIncludesPermissionsSectionForHandlersThatRequireThem() {
        let md = registry.generateAPIDocMarkdown()

        XCTAssertTrue(md.contains("Permissions:"))
    }

    func testGenerateAPIDocJSONContainsAllRegisteredHandlers() {
        let json = registry.generateAPIDocJSON()
        let allHandlers = registry.allHandlers()

        XCTAssertEqual(json.count, allHandlers.count,
                       "JSON doc should include all registered handlers")
    }

    func testGenerateAPIDocJSONEntriesHaveRequiredFields() {
        let json = registry.generateAPIDocJSON()

        for entry in json {
            XCTAssertNotNil(entry["action"], "Each entry must have 'action'")
            XCTAssertNotNil(entry["category"], "Each entry must have 'category'")
            XCTAssertNotNil(entry["displayName"], "Each entry must have 'displayName'")
            XCTAssertNotNil(entry["description"], "Each entry must have 'description'")
            XCTAssertNotNil(entry["requiresNetwork"], "Each entry must have 'requiresNetwork'")
            XCTAssertNotNil(entry["requiresHardware"], "Each entry must have 'requiresHardware'")
        }
    }

    func testHandlerForCaseSensitiveLookup() {
        registry.register(HandlerMeta(
            action: "CaseSensitive_test",
            category: .debug,
            displayName: "Case Test",
            description: "Case sensitivity test"
        ))

        XCTAssertNotNil(registry.handler(for: "CaseSensitive_test"))
        XCTAssertNil(registry.handler(for: "casesensitive_test"))
        XCTAssertNil(registry.handler(for: "CASESENSITIVE_TEST"))
    }

    func testAllHandlersIsSortedAlphabetically() {
        let allHandlers = registry.allHandlers()

        for i in 1..<allHandlers.count {
            XCTAssertLessThanOrEqual(allHandlers[i - 1].action, allHandlers[i].action,
                                      "Handlers should be sorted by action at index \(i)")
        }
    }

    func testCategorySummaryOnlyIncludesNonEmptyCategories() {
        let summary = registry.categorySummary()

        for (_, count) in summary {
            XCTAssertGreaterThan(count, 0, "Summary should not include empty categories")
        }
    }

    func testCategorySummaryCountMatchesActualHandlerCount() {
        let summary = registry.categorySummary()
        let totalCount = summary.reduce(0) { $0 + $1.1 }
        let actualCount = registry.count

        XCTAssertEqual(totalCount, actualCount,
                       "Category summary total should match registry count")
    }

    func testRegisterSameActionMultipleTimesOverwrites() {
        let v1 = HandlerMeta(
            action: "overwriteAdvanced_test",
            category: .hardware,
            displayName: "Version 1",
            description: "First version"
        )
        let v2 = HandlerMeta(
            action: "overwriteAdvanced_test",
            category: .media,
            displayName: "Version 2",
            description: "Second version"
        )
        let v3 = HandlerMeta(
            action: "overwriteAdvanced_test",
            category: .system,
            displayName: "Version 3",
            description: "Third version"
        )

        registry.register(v1)
        registry.register(v2)
        registry.register(v3)

        let result = registry.handler(for: "overwriteAdvanced_test")
        XCTAssertEqual(result?.category, .system)
        XCTAssertEqual(result?.displayName, "Version 3")
        XCTAssertEqual(result?.description, "Third version")

        let hardwareCount = registry.handlers(category: .hardware).filter { $0.action == "overwriteAdvanced_test" }.count
        let mediaCount = registry.handlers(category: .media).filter { $0.action == "overwriteAdvanced_test" }.count
        let systemCount = registry.handlers(category: .system).filter { $0.action == "overwriteAdvanced_test" }.count

        XCTAssertEqual(hardwareCount, 0)
        XCTAssertEqual(mediaCount, 0)
        XCTAssertEqual(systemCount, 1)
    }

    func testIsRegisteredReturnsFalseForEmptyString() {
        XCTAssertFalse(registry.isRegistered(action: ""))
    }

    func testIsRegisteredReturnsFalseForWhitespaceOnly() {
        XCTAssertFalse(registry.isRegistered(action: "   "))
    }

    func testHandlerForEmptyStringReturnsNil() {
        XCTAssertNil(registry.handler(for: ""))
    }

    func testBatchRegisterEmptyArrayDoesNotChangeCount() {
        let countBefore = registry.count
        registry.register([])
        XCTAssertEqual(registry.count, countBefore)
    }
}
