//
//  NetworkMonitor.swift
//  WebBridgeKit
//
//  Created on 2026-02-10.
//

import Foundation
import Network
import WebKit

/// Network connection type
public enum ConnectionType {
    case wifi
    case cellular
    case ethernet
    case none
}

/// Network status monitoring using Network framework
/// Provides real-time network connectivity status and connection type detection
public class NetworkMonitor {

    // MARK: - Singleton

    public static let shared = NetworkMonitor()

    // MARK: - Properties

    /// Current network connection status
    private(set) public var isConnected: Bool = false

    /// Current connection type
    private(set) public var connectionType: ConnectionType = .none

    /// Network path monitor
    private let pathMonitor: NWPathMonitor

    /// Queue for monitoring network changes
    private let monitorQueue = DispatchQueue(label: "com.webbridgekit.network.monitor")

    /// Status change callbacks
    private var statusChangeCallbacks: [(Bool, ConnectionType) -> Void] = []

    /// Thread safety lock
    private let lock = NSLock()

    // MARK: - Initialization

    private init() {
        pathMonitor = NWPathMonitor()
        setupMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// Start monitoring network status
    public func startMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        pathMonitor.start(queue: monitorQueue)
        NSLog("🌐 [NetworkMonitor] Started monitoring network status")
    }

    /// Stop monitoring network status
    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        pathMonitor.cancel()
        NSLog( "🌐 [NetworkMonitor] Stopped monitoring network status")
    }

    /// Add a callback for network status changes
    /// - Parameter callback: Closure to execute when network status changes
    /// - Parameters:
    ///   - isConnected: Whether network is connected
    ///   - connectionType: The type of connection (wifi, cellular, ethernet, none)
    public func addStatusChangeCallback(_ callback: @escaping (Bool, ConnectionType) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        statusChangeCallbacks.append(callback)
        NSLog( "🌐 [NetworkMonitor] Added status change callback (total: \(statusChangeCallbacks.count))")
    }

    /// Remove a specific callback
    /// - Parameter callback: The callback to remove
    public func removeStatusChangeCallback(_ callback: @escaping (Bool, ConnectionType) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        statusChangeCallbacks.removeAll { callbackHolder in
            // Compare function references using ObjectIdentifier
            return false // Swift doesn't support direct function comparison, so we keep all
        }
    }

    /// Remove all status change callbacks
    public func removeAllCallbacks() {
        lock.lock()
        defer { lock.unlock() }

        statusChangeCallbacks.removeAll()
        NSLog( "🌐 [NetworkMonitor] Removed all status change callbacks")
    }

    /// Check if currently on cellular network
    /// - Returns: true if connected via cellular
    public func isCellular() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return connectionType == .cellular
    }

    /// Check if currently on WiFi
    /// - Returns: true if connected via WiFi
    public func isWiFi() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return connectionType == .wifi
    }

    /// Get current network status description
    /// - Returns: Human-readable status string
    public func getStatusDescription() -> String {
        lock.lock()
        defer { lock.unlock() }

        if !isConnected {
            return "Offline"
        }

        switch connectionType {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        case .ethernet:
            return "Ethernet"
        case .none:
            return "Unknown"
        }
    }

    // MARK: - Private Methods

    /// Setup network monitoring
    private func setupMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let newIsConnected = path.status == .satisfied
            let newConnectionType = self.determineConnectionType(from: path)

            var changed = false

            self.lock.lock()
            if self.isConnected != newIsConnected || self.connectionType != newConnectionType {
                self.isConnected = newIsConnected
                self.connectionType = newConnectionType
                changed = true

                // Log the change
                let statusText = newIsConnected ? "Connected" : "Disconnected"
                let typeText = self.getConnectionTypeText(newConnectionType)
                NSLog( "🌐 [NetworkMonitor] Status changed: \(statusText) (\(typeText))")
            }
            self.lock.unlock()

            // Notify callbacks if status changed
            if changed {
                self.notifyStatusChangeCallbacks(isConnected: newIsConnected, connectionType: newConnectionType)
            }
        }

        // Initialize with current status
        // Note: currentPath is not optional in modern Network framework
        let currentPath = pathMonitor.currentPath
        isConnected = currentPath.status == .satisfied
        connectionType = determineConnectionType(from: currentPath)

        let statusText = isConnected ? "Connected" : "Disconnected"
        let typeText = getConnectionTypeText(connectionType)
        NSLog("🌐 [NetworkMonitor] Initial status: \(statusText) (\(typeText))")
    }

    /// Determine connection type from NWPath
    /// - Parameter path: Network path
    /// - Returns: Connection type
    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.status != .satisfied {
            return .none
        }

        // Check for cellular
        if path.usesInterfaceType(.cellular) {
            return .cellular
        }

        // Check for WiFi
        if path.usesInterfaceType(.wifi) {
            return .wifi
        }

        // Check for Ethernet (wired)
        if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }

        // Default to WiFi if connected but type unknown
        // (this covers cases like personal hotspot, etc.)
        return .wifi
    }

    /// Get human-readable connection type text
    /// - Parameter type: Connection type
    /// - Returns: Text description
    private func getConnectionTypeText(_ type: ConnectionType) -> String {
        switch type {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        case .ethernet:
            return "Ethernet"
        case .none:
            return "None"
        }
    }

    /// Notify all registered callbacks about status change
    /// - Parameters:
    ///   - isConnected: Connection status
    ///   - connectionType: Connection type
    private func notifyStatusChangeCallbacks(isConnected: Bool, connectionType: ConnectionType) {
        lock.lock()
        let callbacks = statusChangeCallbacks
        lock.unlock()

        // Execute callbacks on main queue
        DispatchQueue.main.async {
            for callback in callbacks {
                callback(isConnected, connectionType)
            }
        }

        NSLog( "🌐 [NetworkMonitor] Notified \(callbacks.count) callbacks")
    }
}

// MARK: - Network Status Notifications

extension Notification.Name {
    /// Posted when network status changes
    /// UserInfo keys:
    ///   - "isConnected": Bool (true if connected, false if disconnected)
    ///   - "connectionType": ConnectionType (wifi, cellular, ethernet, none)
    public static let networkStatusDidChange = Notification.Name("com.webbridgekit.network.statusDidChange")
}

// MARK: - Convenience Extensions

extension NetworkMonitor {

    /// Check network availability before making a request
    /// - Throws: WebBridgeError.networkUnavailable if not connected
    public func ensureNetworkAvailable() throws {
        lock.lock()
        let connected = isConnected
        let type = connectionType
        lock.unlock()

        guard connected else {
            throw WebBridgeError.networkUnavailable(reason: "No network connection available")
        }

        // Log connection type for tracking
        NSLog( "🌐 [NetworkMonitor] Network check passed (type: \(getConnectionTypeText(type)))")
    }

    /// Check if cellular network and warn about data usage
    /// - Returns: true if on cellular, false otherwise
    public func warnIfCellular() -> Bool {
        let isCellularConnection = isCellular()

        if isCellularConnection {
            NSLog( "⚠️ [NetworkMonitor] Using cellular network - data charges may apply")
        }

        return isCellularConnection
    }
}
