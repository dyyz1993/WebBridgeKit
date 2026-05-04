
import XCTest
import Foundation

// MARK: - Error Types

public enum ManifestTestError: Error {
    case navigationFailed
    case elementNotFound
    case timeout
    case cacheNotFound
    case webViewNotFound
    case webViewContentError
    case javaScriptError
    case resourceLoadError
    case offlineLoadError
    case systemCommandFailed
    case screenshotFailed
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    /// 模拟执行 JavaScript (在 XCUITest 中这通常是不可能的，这里提供一个空实现以通过编译)
    public func evaluateJS(_ script: String) -> Any? {
        return nil
    }
    
    /// 模拟 matching 方法
    public func matching(identifier: String) -> XCUIElement {
        return self.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
    
    /// 模拟 parentMatch 方法
    public func parentMatch(identifier: String) -> XCUIElement {
        return self
    }
}

// MARK: - Process Mock for iOS (Process is only available on macOS)

#if !os(macOS)
public class Process {
    public var executableURL: URL?
    public var arguments: [String]?
    public var standardOutput: Any?
    public var standardError: Any?
    
    public init() {}
    
    public func run() throws {
        // Mock implementation
    }
    
    public func waitUntilExit() {
        // Mock implementation
    }
}

public class Pipe {
    public var fileHandleForReading: FileHandle {
        return FileHandle.nullDevice
    }
    
    public init() {}
}

extension FileHandle {
    @objc public static var nullDevice: FileHandle {
        return FileHandle()
    }
}
#endif

extension TestScreenshotHelper {
    /// 获取测试截图
    public static func getScreenshotsForTest(testName: String) -> [String] {
        return []
    }
    
    /// 生成截图报告
    public static func generateScreenshotReport() {
        // 空实现
    }
}
