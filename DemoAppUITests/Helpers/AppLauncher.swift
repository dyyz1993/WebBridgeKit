import XCTest
import Foundation
#if os(macOS)
import Foundation
#endif

class AppLauncher {
    static let shared = AppLauncher()
    private init() {}

    // MARK: - Properties

    #if os(macOS)
    private var testServerProcess: Process?
    private let testServerPort = 8080
    #endif

    // MARK: - App Launch Methods

    /// Launch app with default testing configuration
    func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITesting"]
        app.launchEnvironment = ["UITesting": "YES"]
        app.launch()
        return app
    }

    /// Launch app with performance testing configuration
    func launchAppForPerformanceTesting() -> XCUIApplication {
        let app = XCUIApplication()

        // Add UI testing flag
        app.launchArguments += ["-UITesting"]

        // Performance testing configuration
        app.launchArguments += [
            "-PerformanceTesting",
            "-CacheLoggingEnabled"
        ]

        // Environment variables for performance testing
        app.launchEnvironment = [
            "UITesting": "YES",
            "PERFORMANCE_TESTING": "YES",
            "CACHE_LOGGING": "ENABLED",
            "NETWORK_MONITORING": "ENABLED"
        ]

        app.launch()
        return app
    }

    /// Launch app with network conditioning for slow network testing
    func launchAppWithNetworkConditioning(latency: Int, bandwidth: Int) -> XCUIApplication {
        let app = XCUIApplication()

        app.launchArguments += [
            "-UITesting",
            "-PerformanceTesting",
            "-NetworkConditioning"
        ]

        app.launchEnvironment = [
            "UITesting": "YES",
            "PERFORMANCE_TESTING": "YES",
            "NETWORK_LATENCY": "\(latency)",
            "NETWORK_BANDWIDTH": "\(bandwidth)"
        ]

        app.launch()
        return app
    }

    /// Terminate the app
    func terminateApp(_ app: XCUIApplication) {
        app.terminate()
    }

    // MARK: - Test Server Management

    /// Start the test server for performance testing
    func startTestServer() -> Bool {
        #if os(macOS)
        // Check if server is already running
        if isTestServerRunning() {
            print("✅ Test server is already running on port \(testServerPort)")
            return true
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")

        // Path to test server script
        let scriptPath = "/Users/xuyingzhou/Project/temporary/WebBridgeKit/scripts/test_server.py"
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            print("❌ Test server script not found at: \(scriptPath)")
            return false
        }

        process.arguments = [scriptPath]

        // Setup output pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            testServerProcess = process

            // Give server time to start
            Thread.sleep(forTimeInterval: 1.0)

            if isTestServerRunning() {
                print("✅ Test server started successfully on port \(testServerPort)")
                return true
            } else {
                print("❌ Test server failed to start")
                return false
            }
        } catch {
            print("❌ Failed to start test server: \(error)")
            return false
        }
        #else
        print("ℹ️ Test server not supported on iOS")
        return false
        #endif
    }

    /// Stop the test server
    func stopTestServer() {
        #if os(macOS)
        guard let process = testServerProcess, process.isRunning else {
            print("ℹ️ Test server is not running")
            return
        }

        process.terminate()

        // Wait for process to terminate gracefully
        var attempts = 0
        while process.isRunning && attempts < 10 {
            Thread.sleep(forTimeInterval: 0.5)
            attempts += 1
        }

        // Force kill if still running
        if process.isRunning {
            process.interrupt()
            Thread.sleep(forTimeInterval: 0.5)

            if process.isRunning {
                print("⚠️ Force killing test server process")
                process.terminate()
            }
        }

        testServerProcess = nil
        print("✅ Test server stopped")
        #else
        print("ℹ️ Test server not supported on iOS")
        #endif
    }

    /// Check if test server is running
    func isTestServerRunning() -> Bool {
        #if os(macOS)
        var isRunning = false

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-i", ":\(testServerPort)"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                isRunning = output.contains("LISTEN")
            }
        } catch {
            // lsof failed, assume server is not running
        }

        return isRunning
        #else
        return false
        #endif
    }

    /// Get test server URL
    func getTestServerURL() -> String {
        #if os(macOS)
        return "http://localhost:\(testServerPort)"
        #else
        return "http://localhost:8080"
        #endif
    }

    /// Get test server resource URL
    func getTestResourceURL(for resource: String) -> String {
        return "\(getTestServerURL())/\(resource)"
    }

    // MARK: - Performance Test Configuration

    /// Get default performance test timeout
    var defaultPerformanceTestTimeout: TimeInterval {
        return 30.0
    }

    /// Get slow network test timeout
    var slowNetworkTestTimeout: TimeInterval {
        return 60.0
    }

    // MARK: - Cleanup

    /// Clean up all test resources
    func cleanup() {
        stopTestServer()
    }

    deinit {
        cleanup()
    }
}
