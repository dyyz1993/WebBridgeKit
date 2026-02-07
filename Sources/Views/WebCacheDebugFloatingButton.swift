//
//  WebCacheDebugFloatingButton.swift
//  WebBridgeKit
//
//  Created on 2026-02-02.
//

import UIKit
import WebKit

/// Floating debug button for monitoring WebView cache status
public class WebCacheDebugFloatingButton: UIView {

    // MARK: - Types

    public enum CacheStatus {
        case hit
        case downloading
        case noCache
        case error

        var color: UIColor {
            switch self {
            case .hit: return .systemGreen
            case .downloading: return .systemOrange
            case .noCache: return .systemGray
            case .error: return .systemRed
            }
        }

        var icon: String {
            switch self {
            case .hit: return "✓"
            case .downloading: return "↓"
            case .noCache: return "•"
            case .error: return "✗"
            }
        }

        var description: String {
            switch self {
            case .hit: return "Cache Hit"
            case .downloading: return "Downloading"
            case .noCache: return "No Cache"
            case .error: return "Cache Error"
            }
        }
    }

    public struct CacheEvent {
        let url: String
        let status: CacheStatus
        let timestamp: Date
        let resourceCount: Int
        let cacheSize: Int64

        public init(url: String, status: CacheStatus, resourceCount: Int, cacheSize: Int64) {
            self.url = url
            self.status = status
            self.timestamp = Date()
            self.resourceCount = resourceCount
            self.cacheSize = cacheSize
        }
    }

    // MARK: - Properties

    private let buttonSize: CGFloat = 50
    private let panelWidth: CGFloat = 320
    private let panelHeight: CGFloat = 400

    private var currentStatus: CacheStatus = .noCache
    private var currentURL: String = ""
    private var cachedResourcesCount: Int = 0
    private var cacheSize: Int64 = 0
    private var cacheEvents: [CacheEvent] = []
    private let maxEvents = 10

    private var isExpanded = false

    // UI Components
    private let floatingButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .systemGray
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.3
        button.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        return button
    }()

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("✕", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 10
        return button
    }()

    private let debugPanel: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.2
        view.alpha = 0
        view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        return view
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.distribution = .fill
        return stack
    }()

    // MARK: - Initialization

    public init(position: CGPoint = CGPoint(x: 100, y: 100)) {
        super.init(frame: CGRect(x: position.x, y: position.y, width: buttonSize, height: buttonSize))
        setupUI()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupGestures()
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear

        // Setup floating button
        floatingButton.frame = bounds
        floatingButton.setTitle("•", for: .normal)
        floatingButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        addSubview(floatingButton)

        // Setup close button
        closeButton.frame = CGRect(x: buttonSize - 24, y: -4, width: 20, height: 20)
        closeButton.isHidden = true
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        addSubview(closeButton)

        // Setup debug panel
        setupDebugPanel()
    }

    private func setupDebugPanel() {
        // Title
        let titleLabel = createLabel(text: "Cache Debug Panel", font: .systemFont(ofSize: 18, weight: .bold))

        // Current URL section
        let urlLabel = createLabel(text: "Current URL:", font: .systemFont(ofSize: 14, weight: .semibold))
        let urlValueLabel = createLabel(text: "N/A", font: .systemFont(ofSize: 12), textColor: .systemGray)
        urlValueLabel.numberOfLines = 2
        urlValueLabel.tag = 100

        // Status section
        let statusLabel = createLabel(text: "Status:", font: .systemFont(ofSize: 14, weight: .semibold))
        let statusValueLabel = createLabel(text: "No Cache", font: .systemFont(ofSize: 14), textColor: .systemGray)
        statusValueLabel.tag = 101

        // Resources section
        let resourcesLabel = createLabel(text: "Cached Resources:", font: .systemFont(ofSize: 14, weight: .semibold))
        let resourcesValueLabel = createLabel(text: "0 items", font: .systemFont(ofSize: 14))
        resourcesValueLabel.tag = 102

        // Cache size section
        let sizeLabel = createLabel(text: "Cache Size:", font: .systemFont(ofSize: 14, weight: .semibold))
        let sizeValueLabel = createLabel(text: "0 B", font: .systemFont(ofSize: 14))
        sizeValueLabel.tag = 103

        // Recent events section
        let eventsLabel = createLabel(text: "Recent Events (Last 10):", font: .systemFont(ofSize: 14, weight: .semibold))

        let eventsStack = UIStackView()
        eventsStack.axis = .vertical
        eventsStack.spacing = 8
        eventsStack.tag = 104

        // Add all to main stack
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(createSeparator())
        stackView.addArrangedSubview(urlLabel)
        stackView.addArrangedSubview(urlValueLabel)
        stackView.addArrangedSubview(createSeparator())
        stackView.addArrangedSubview(statusLabel)
        stackView.addArrangedSubview(statusValueLabel)
        stackView.addArrangedSubview(createSeparator())
        stackView.addArrangedSubview(resourcesLabel)
        stackView.addArrangedSubview(resourcesValueLabel)
        stackView.addArrangedSubview(createSeparator())
        stackView.addArrangedSubview(sizeLabel)
        stackView.addArrangedSubview(sizeValueLabel)
        stackView.addArrangedSubview(createSeparator())
        stackView.addArrangedSubview(eventsLabel)
        stackView.addArrangedSubview(eventsStack)

        // Configure stack view
        stackView.translatesAutoresizingMaskIntoConstraints = false
        debugPanel.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: debugPanel.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: debugPanel.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: debugPanel.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: debugPanel.bottomAnchor, constant: -16)
        ])
    }

    private func createLabel(text: String, font: UIFont, textColor: UIColor = .label) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = textColor
        label.numberOfLines = 0
        return label
    }

    private func createSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }

    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }

    // MARK: - Actions

    @objc private func buttonTapped() {
        if isExpanded {
            collapsePanel()
        } else {
            expandPanel()
        }
    }

    @objc private func closeButtonTapped() {
        removeFromSuperview()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard !isExpanded else { return }

        let translation = gesture.translation(in: superview)
        center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
        gesture.setTranslation(.zero, in: superview)

        // Keep within bounds
        if let superview = superview {
            let bounds = superview.bounds
            frame = bounds.intersection(frame)
        }
    }

    // MARK: - Panel Animation

    private func expandPanel() {
        guard let superview = superview else { return }
        isExpanded = true
        closeButton.isHidden = false

        // Calculate panel position
        var panelFrame: CGRect
        let rightEdge = frame.maxX
        let bottomEdge = frame.maxY

        if rightEdge + panelWidth <= superview.bounds.width {
            // Place to the right
            panelFrame = CGRect(x: rightEdge + 8, y: frame.minY, width: panelWidth, height: panelHeight)
        } else if frame.minX - panelWidth >= 0 {
            // Place to the left
            panelFrame = CGRect(x: frame.minX - panelWidth - 8, y: frame.minY, width: panelWidth, height: panelHeight)
        } else if bottomEdge + panelHeight <= superview.bounds.height {
            // Place below
            panelFrame = CGRect(x: frame.minX, y: bottomEdge + 8, width: panelWidth, height: panelHeight)
        } else {
            // Place above
            panelFrame = CGRect(x: frame.minX, y: frame.minY - panelHeight - 8, width: panelWidth, height: panelHeight)
        }

        debugPanel.frame = panelFrame
        superview.addSubview(debugPanel)
        superview.bringSubviewToFront(self)

        updatePanelContent()

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.debugPanel.alpha = 1
            self.debugPanel.transform = .identity
        }
    }

    private func collapsePanel() {
        isExpanded = true

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            self.debugPanel.alpha = 0
            self.debugPanel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        } completion: { _ in
            self.debugPanel.removeFromSuperview()
            self.isExpanded = false
            self.closeButton.isHidden = true
        }
    }

    private func updatePanelContent() {
        guard let urlValueLabel = stackView.viewWithTag(100) as? UILabel,
              let statusValueLabel = stackView.viewWithTag(101) as? UILabel,
              let resourcesValueLabel = stackView.viewWithTag(102) as? UILabel,
              let sizeValueLabel = stackView.viewWithTag(103) as? UILabel,
              let eventsStack = stackView.viewWithTag(104) as? UIStackView else {
            return
        }

        urlValueLabel.text = currentURL.isEmpty ? "N/A" : currentURL
        statusValueLabel.text = currentStatus.description
        statusValueLabel.textColor = currentStatus.color
        resourcesValueLabel.text = "\(cachedResourcesCount) items"
        sizeValueLabel.text = formatBytes(cacheSize)

        // Update events
        eventsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if cacheEvents.isEmpty {
            let emptyLabel = createLabel(text: "No events yet", font: .systemFont(ofSize: 12), textColor: .systemGray)
            eventsStack.addArrangedSubview(emptyLabel)
        } else {
            for event in cacheEvents {
                let eventLabel = createLabel(
                    text: formatEvent(event),
                    font: .systemFont(ofSize: 11),
                    textColor: event.status.color
                )
                eventsStack.addArrangedSubview(eventLabel)
            }
        }
    }

    private func formatEvent(_ event: CacheEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        let time = formatter.string(from: event.timestamp)
        let shortURL = event.url.count > 40 ? String(event.url.prefix(40)) + "..." : event.url
        return "[\(time)] \(event.status.icon) \(shortURL)"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.2f KB", kb)
        } else {
            return "\(bytes) B"
        }
    }

    // MARK: - Public API

    /// Update the cache status
    public func updateStatus(url: String, status: CacheStatus, resourceCount: Int, cacheSize: Int64) {
        currentURL = url
        currentStatus = status
        cachedResourcesCount = resourceCount
        self.cacheSize = cacheSize

        // Update button appearance
        UIView.animate(withDuration: 0.2) {
            self.floatingButton.backgroundColor = status.color
            self.floatingButton.setTitle(status.icon, for: .normal)
        }

        // Add event
        let event = CacheEvent(url: url, status: status, resourceCount: resourceCount, cacheSize: cacheSize)
        cacheEvents.insert(event, at: 0)

        if cacheEvents.count > maxEvents {
            cacheEvents.removeLast()
        }

        // Update panel if expanded
        if isExpanded {
            updatePanelContent()
        }
    }

    /// Add a custom event to the event log
    public func addEvent(url: String, status: CacheStatus, resourceCount: Int = 0, cacheSize: Int64 = 0) {
        let event = CacheEvent(url: url, status: status, resourceCount: resourceCount, cacheSize: cacheSize)
        cacheEvents.insert(event, at: 0)

        if cacheEvents.count > maxEvents {
            cacheEvents.removeLast()
        }

        if isExpanded {
            updatePanelContent()
        }
    }

    /// Clear all cache events
    public func clearEvents() {
        cacheEvents.removeAll()
        if isExpanded {
            updatePanelContent()
        }
    }

    /// Get all recorded events
    public var events: [CacheEvent] {
        return cacheEvents
    }
}

// MARK: - WebViewController Extension

public extension WebViewController {

    private struct AssociatedKeys {
        static var debugFloatingButton = "debugFloatingButton"
    }

    /// The debug floating button associated with this view controller
    var debugFloatingButton: WebCacheDebugFloatingButton? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.debugFloatingButton) as? WebCacheDebugFloatingButton
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.debugFloatingButton, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Add a floating debug button to the web view
    /// - Parameter position: Initial position for the button (default: top-right corner)
    /// - Returns: The created debug button
    @discardableResult
    func addCacheDebugButton(at position: CGPoint? = nil) -> WebCacheDebugFloatingButton {
        // Remove existing button if present
        debugFloatingButton?.removeFromSuperview()

        let defaultPosition = CGPoint(x: view.bounds.width - 70, y: 100)
        let buttonPosition = position ?? defaultPosition

        let button = WebCacheDebugFloatingButton(position: buttonPosition)
        view.addSubview(button)

        self.debugFloatingButton = button
        return button
    }

    /// Remove the debug floating button
    func removeCacheDebugButton() {
        debugFloatingButton?.removeFromSuperview()
        debugFloatingButton = nil
    }

    /// Update cache status from the debug button
    /// - Parameters:
    ///   - url: The current URL
    ///   - status: The cache status
    ///   - resourceCount: Number of cached resources
    ///   - cacheSize: Total cache size in bytes
    func updateCacheDebugStatus(url: String, status: WebCacheDebugFloatingButton.CacheStatus, resourceCount: Int = 0, cacheSize: Int64 = 0) {
        debugFloatingButton?.updateStatus(url: url, status: status, resourceCount: resourceCount, cacheSize: cacheSize)
    }
}
