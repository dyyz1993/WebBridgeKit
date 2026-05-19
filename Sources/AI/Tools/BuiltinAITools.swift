import Foundation

public enum BuiltinAITools {

    // MARK: - All Tools

    public static let all: [AITool] = [
        listHandlers,
        getHandlerDetail,
        getCacheStats,
        getCacheEntries,
        getMessageStats,
        getRecentErrors,
        getConfig,
        readFile,
        getDiagnosticReport,
        executeHandler,
        clearCache,
        sendTestPush,
        reloadConfig
    ]
}
