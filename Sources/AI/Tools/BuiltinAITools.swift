import Foundation

public enum BuiltinAITools {

    // MARK: - All Tools

    public static let all: [AITool] = {
        var tools: [AITool] = [
        listHandlers,
        getHandlerDetail,
        getCacheStats,
        getCacheEntries,
        getMessageStats,
        getRecentErrors,
        getConfig,
        readFile,
        executeHandler,
        clearCache,
        sendTestPush,
        reloadConfig
        ]

        #if DEBUG
        tools.insert(getDiagnosticReport, at: 8)
        #endif

        return tools
    }()
}
