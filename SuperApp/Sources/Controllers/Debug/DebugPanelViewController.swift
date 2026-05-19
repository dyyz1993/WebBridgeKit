//
//  DebugPanelViewController.swift
//  SuperApp
//
//  Created on 2026-05-07.
//  Copyright © 2026年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebBridgeKit

class DebugPanelViewController: UIViewController {

    private let tabScrollView = UIScrollView()
    private let tabStack = UIStackView()
    private let containerView = UIView()
    private let underlineView = UIView()

    private var currentViewController: UIViewController?
    private var selectedIndex: Int = 0

    private let tabs: [(title: String, icon: LucideIcon)] = [
        (L10n.tr("debug.panel.handlers"), .terminal),
        (L10n.tr("debug.panel.notification_test"), .bell),
        (L10n.tr("debug.panel.logs"), .docText),
        (L10n.tr("debug.panel.environment"), .server),
        (L10n.tr("debug.panel.cache_stats"), .hardDrive)
    ]

    private lazy var handlerListVC = HandlerDebugListViewController()
    private lazy var notificationVC = NotificationDebugViewController()
    private lazy var logViewerVC = LogDebugViewController()
    private lazy var environmentVC = EnvironmentDebugViewController()
    private lazy var cacheDashboardVC = CacheDashboardViewController(viewModel: CacheDashboardViewModel())

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("debug.panel.title")
        view.backgroundColor = ThemeTokens.Color.background

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: L10n.tr("common.done"),
            style: .done,
            target: self,
            action: #selector(closeTapped)
        )

        setupUI()
        switchToTab(index: 0)
    }

    private func setupUI() {
        tabScrollView.showsHorizontalScrollIndicator = false
        tabScrollView.showsVerticalScrollIndicator = false
        tabScrollView.bounces = true

        tabStack.axis = .horizontal
        tabStack.spacing = 4
        tabStack.distribution = .fill
        tabStack.alignment = .center

        for (index, tab) in tabs.enumerated() {
            let button = makeTabButton(title: tab.title, icon: tab.icon, index: index)
            tabStack.addArrangedSubview(button)
        }

        tabScrollView.addSubview(tabStack)

        underlineView.backgroundColor = ThemeTokens.Color.primary

        view.addSubview(tabScrollView)
        view.addSubview(underlineView)
        view.addSubview(containerView)

        tabScrollView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(4)
            make.left.right.equalToSuperview()
            make.height.equalTo(40)
        }

        tabStack.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.right.equalToSuperview().inset(12)
            make.height.equalToSuperview()
        }

        underlineView.snp.makeConstraints { make in
            make.top.equalTo(tabScrollView.snp.bottom)
            make.left.right.equalToSuperview()
            make.height.equalTo(1)
        }

        containerView.snp.makeConstraints { make in
            make.top.equalTo(underlineView.snp.bottom).offset(8)
            make.left.right.bottom.equalToSuperview()
        }
    }

    private func makeTabButton(title: String, icon: LucideIcon, index: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.tag = index

        let iconImage = icon.templateImage(pointSize: 14)
        button.setImage(iconImage, for: .normal)

        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 0)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -4)
        button.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        button.accessibilityLabel = title

        updateTabButtonAppearance(button, isSelected: index == 0)

        button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)

        button.snp.makeConstraints { make in
            make.height.equalTo(32)
        }

        return button
    }

    private func updateTabButtonAppearance(_ button: UIButton, isSelected: Bool) {
        if isSelected {
            button.backgroundColor = ThemeTokens.Color.primary.withAlphaComponent(0.12)
            button.setTitleColor(ThemeTokens.Color.primary, for: .normal)
            button.tintColor = ThemeTokens.Color.primary
        } else {
            button.backgroundColor = ThemeTokens.Color.surface
            button.setTitleColor(ThemeTokens.Color.textSecondary, for: .normal)
            button.tintColor = ThemeTokens.Color.textSecondary
        }
    }

    @objc private func tabTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index != selectedIndex else { return }
        selectedIndex = index

        for case let button as UIButton in tabStack.arrangedSubviews {
            updateTabButtonAppearance(button, isSelected: button.tag == index)
        }

        if let selectedButton = tabStack.arrangedSubviews.first(where: { $0.tag == index }) {
            tabScrollView.scrollRectToVisible(selectedButton.frame.insetBy(dx: -12, dy: 0), animated: true)
        }

        switchToTab(index: index)
    }

    private func switchToTab(index: Int) {
        currentViewController?.willMove(toParent: nil)
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()

        let vc: UIViewController
        switch index {
        case 0: vc = handlerListVC
        case 1: vc = notificationVC
        case 2: vc = logViewerVC
        case 3: vc = environmentVC
        case 4: vc = cacheDashboardVC
        default: vc = handlerListVC
        }

        addChild(vc)
        containerView.addSubview(vc.view)
        vc.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        vc.didMove(toParent: self)
        currentViewController = vc
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

// MARK: - Handler List

private class HandlerDebugListViewController: UIViewController {

    private var categories: [(HandlerCategory, [HandlerMeta])] = []
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeColors.current.background

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HandlerCell")

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: L10n.tr("debug.panel.execute_test"),
            style: .plain,
            target: self,
            action: #selector(performOneClickTest)
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadHandlers()
    }

    private func loadHandlers() {
        let summary = HandlerRegistry.shared.categorySummary()
        categories = summary.map { (category, _) in
            (category, HandlerRegistry.shared.handlers(category: category))
        }
        tableView.reloadData()
    }

    @objc private func performOneClickTest() {
        let alert = UIAlertController(title: L10n.tr("debug.panel.execute_test"), message: L10n.tr("debug.panel.select_handler_test"), preferredStyle: .actionSheet)

        for (_, handlers) in categories {
            for handler in handlers {
                alert.addAction(UIAlertAction(
                    title: "\(handler.displayName) (\(handler.action))",
                    style: .default,
                    handler: { [weak self] _ in
                        self?.pushHandlerDetail(handler)
                    }
                ))
            }
        }

        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        present(alert, animated: true)
    }

    private func pushHandlerDetail(_ meta: HandlerMeta) {
        let detail = HandlerDebugDetailViewController(meta: meta)
        navigationController?.pushViewController(detail, animated: true)
    }
}

extension HandlerDebugListViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return categories.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories[section].1.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let (category, handlers) = categories[section]
        return "\(category.emoji) \(category.displayName) (\(handlers.count))"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let handler = categories[indexPath.section].1[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: "HandlerCell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = handler.displayName
        config.secondaryText = handler.action

        if !handler.requiredPermissions.isEmpty {
            config.secondaryText = "\(handler.action) 🔐"
        }

        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

extension HandlerDebugListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let handler = categories[indexPath.section].1[indexPath.row]
        pushHandlerDetail(handler)
    }
}

// MARK: - Handler Detail

private class HandlerDebugDetailViewController: UIViewController {

    private let meta: HandlerMeta
    private var paramInputs: [String: UITextField] = [:]
    private let resultTextView = UITextView()
    private let scrollView = UIScrollView()

    init(meta: HandlerMeta) {
        self.meta = meta
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = meta.displayName
        view.backgroundColor = ThemeTokens.Color.background

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: L10n.tr("common.copy"),
            style: .plain,
            target: self,
            action: #selector(copyHandlerInfo)
        )

        setupUI()
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16

        let descLabel = UILabel()
        descLabel.text = meta.description
        descLabel.numberOfLines = 0
        descLabel.textColor = ThemeTokens.Color.textSecondary
        stack.addArrangedSubview(descLabel)

        let infoLabel = UILabel()
        infoLabel.text = "\(meta.category.emoji) \(meta.category.displayName) · action: \(meta.action)"
        infoLabel.textColor = ThemeTokens.Color.textSecondary
        infoLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        stack.addArrangedSubview(infoLabel)

        if !meta.requiredPermissions.isEmpty {
            let permLabel = UILabel()
            permLabel.text = "🔐 Required: \(meta.requiredPermissions.joined(separator: ", "))"
            permLabel.textColor = ThemeTokens.Color.warning
            stack.addArrangedSubview(permLabel)
        }

        if !meta.parameters.isEmpty {
            let header = UILabel()
            header.text = L10n.tr("debug.panel.parameters")
            header.font = .systemFont(ofSize: 15, weight: .semibold)
            stack.addArrangedSubview(header)

            for param in meta.parameters {
                let field = makeParamField(param)
                stack.addArrangedSubview(field)
                paramInputs[param.name] = (field.arrangedSubviews.first as? UITextField)
            }
        }

        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("debug.panel.execute"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = ThemeColors.current.primary
        button.setTitleColor(ThemeTokens.Color.surface, for: .normal)
        button.layer.cornerRadius = ThemeTokens.CornerRadius.md
        button.addTarget(self, action: #selector(execute), for: .touchUpInside)
        button.accessibilityLabel = L10n.tr("debug.panel.execute")
        button.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
        stack.addArrangedSubview(button)

        resultTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        resultTextView.layer.borderColor = ThemeTokens.Color.border.cgColor
        resultTextView.layer.borderWidth = 1
        resultTextView.layer.cornerRadius = ThemeTokens.CornerRadius.md
        resultTextView.isEditable = false
        resultTextView.isScrollEnabled = false
        resultTextView.text = L10n.tr("debug.panel.tap_execute_hint")
        resultTextView.textColor = ThemeTokens.Color.textSecondary
        resultTextView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(80)
        }
        stack.addArrangedSubview(resultTextView)

        let copyButton = UIButton(type: .system)
        copyButton.setTitle(L10n.tr("debug.panel.copy_result"), for: .normal)
        copyButton.addTarget(self, action: #selector(copyResult), for: .touchUpInside)
        copyButton.accessibilityLabel = L10n.tr("debug.panel.copy_result")
        stack.addArrangedSubview(copyButton)

        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        stack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.right.equalToSuperview().inset(16)
            make.width.equalTo(scrollView).offset(-32)
            make.bottom.equalToSuperview().offset(-16)
        }
    }

    private func makeParamField(_ param: ParamDef) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4

        let label = UILabel()
        var text = param.name
        if param.required { text += " *" }
        text += " (\(param.type.rawValue))"
        if !param.description.isEmpty { text += " — \(param.description)" }
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .medium)
        stack.addArrangedSubview(label)

        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.placeholder = param.defaultValue ?? L10n.tr("debug.panel.enter_param", param.name)
        if let options = param.options {
            textField.text = options.first
        }
        stack.addArrangedSubview(textField)

        if let options = param.options {
            let optionsLabel = UILabel()
            optionsLabel.text = L10n.tr("debug.panel.options", options.joined(separator: " | "))
            optionsLabel.font = .systemFont(ofSize: 11, weight: .regular)
            optionsLabel.textColor = ThemeTokens.Color.textSecondary
            stack.addArrangedSubview(optionsLabel)
        }

        return stack
    }

    @objc private func execute() {
        var params: [String: Any] = [:]
        for (name, textField) in paramInputs {
            if let text = textField.text, !text.isEmpty {
                params[name] = text
            }
        }

        resultTextView.text = L10n.tr("debug.panel.executing_format", meta.action)

        StructuredLogger.shared.info("Debug execute: \(meta.action)", category: .diagnostic, action: meta.action)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            let result = """
            ✅ Handler: \(self.meta.action)
            📋 Category: \(self.meta.category.displayName)
            📥 Parameters: \(params)

            Note: Full execution requires an active WebView context.
            This debug panel shows the handler metadata and parameter validation.

            Meta JSON:
            \(self.meta.jsonDict.jsonString)
            """
            self.resultTextView.text = result
        }
    }

    @objc private func copyResult() {
        UIPasteboard.general.string = resultTextView.text
        let alert = UIAlertController(title: L10n.tr("debug.panel.copied"), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }

    @objc private func copyHandlerInfo() {
        UIPasteboard.general.string = meta.jsonDict.jsonString
        let alert = UIAlertController(title: L10n.tr("debug.panel.copied"), message: L10n.tr("debug.panel.handler_info_copied"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Log Viewer

private class LogDebugViewController: UIViewController {

    private let textView = UITextView()
    private var logs: [LogEntry] = []
    private var filterCategory: LogCategory?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeColors.current.background

        let toolbar = makeToolbar()
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.backgroundColor = ThemeTokens.Color.surface

        view.addSubview(toolbar)
        view.addSubview(textView)

        toolbar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.left.right.equalToSuperview().inset(8)
            make.height.equalTo(44)
        }

        textView.snp.makeConstraints { make in
            make.top.equalTo(toolbar.snp.bottom).offset(8)
            make.left.right.bottom.equalToSuperview()
        }

        refreshLogs()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshLogs()
    }

    private func makeToolbar() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8

        let allButton = UIButton(type: .system)
        allButton.setTitle(L10n.tr("debug.panel.log_all"), for: .normal)
        allButton.addTarget(self, action: #selector(filterAll), for: .touchUpInside)
        allButton.accessibilityLabel = L10n.tr("debug.panel.log_all")
        stack.addArrangedSubview(allButton)

        let errorButton = UIButton(type: .system)
        errorButton.setTitle(L10n.tr("debug.panel.log_errors"), for: .normal)
        errorButton.tintColor = ThemeTokens.Color.error
        errorButton.addTarget(self, action: #selector(filterErrors), for: .touchUpInside)
        errorButton.accessibilityLabel = L10n.tr("debug.panel.log_errors")
        stack.addArrangedSubview(errorButton)

        let copyButton = UIButton(type: .system)
        copyButton.setTitle(L10n.tr("debug.panel.log_copy_all"), for: .normal)
        copyButton.addTarget(self, action: #selector(copyLogs), for: .touchUpInside)
        copyButton.accessibilityLabel = L10n.tr("debug.panel.log_copy_all")
        stack.addArrangedSubview(copyButton)

        let exportButton = UIButton(type: .system)
        exportButton.setTitle(L10n.tr("debug.panel.log_export_json"), for: .normal)
        exportButton.addTarget(self, action: #selector(exportJSON), for: .touchUpInside)
        exportButton.accessibilityLabel = L10n.tr("debug.panel.log_export_json")
        stack.addArrangedSubview(exportButton)

        return stack
    }

    @objc private func refreshLogs() {
        if let category = filterCategory {
            logs = StructuredLogger.shared.query(category: category, limit: 200)
        } else {
            logs = StructuredLogger.shared.query(limit: 200)
        }

        let text = logs.map { $0.consoleString }.joined(separator: "\n")
        textView.text = text.isEmpty ? L10n.tr("debug.panel.no_logs") : text
    }

    @objc private func filterAll() {
        filterCategory = nil
        refreshLogs()
    }

    @objc private func filterErrors() {
        filterCategory = nil
        logs = StructuredLogger.shared.query(minLevel: .error, limit: 200)
        let text = logs.map { $0.consoleString }.joined(separator: "\n")
        textView.text = text.isEmpty ? L10n.tr("debug.panel.no_errors") : text
    }

    @objc private func copyLogs() {
        let text = logs.map { $0.debugString }.joined(separator: "\n\n")
        UIPasteboard.general.string = text
        let alert = UIAlertController(title: L10n.tr("debug.panel.copied"), message: L10n.tr("debug.panel.logs_copied_format", "\(logs.count)"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }

    @objc private func exportJSON() {
        let json = StructuredLogger.shared.exportJSON()
        UIPasteboard.general.string = json
        let alert = UIAlertController(title: L10n.tr("debug.panel.exported"), message: L10n.tr("debug.panel.logs_exported_json"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Environment

private class EnvironmentDebugViewController: UIViewController {

    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeColors.current.background

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: L10n.tr("common.copy"),
            style: .plain,
            target: self,
            action: #selector(copyInfo)
        )

        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = ThemeTokens.Color.surface

        view.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.left.right.bottom.equalToSuperview().inset(16)
        }

        loadInfo()
    }

    private func loadInfo() {
        let env = EnvironmentInfo()
        let diagReport = DiagnosticEngine.shared.generateReport()

        let handlerCount = HandlerRegistry.shared.count
        let summary = HandlerRegistry.shared.categorySummary()

        var text = "=== App Info ===\n"
        text += "\(env.summary)\n\n"
        text += "Handlers Registered: \(handlerCount)\n"
        for (cat, count) in summary {
            text += "  \(cat.emoji) \(cat.displayName): \(count)\n"
        }
        text += "\n=== Diagnostic Report ===\n"
        text += diagReport

        textView.text = text
    }

    @objc private func copyInfo() {
        UIPasteboard.general.string = textView.text
        let alert = UIAlertController(title: L10n.tr("debug.panel.copied"), message: L10n.tr("debug.panel.env_info_copied"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Dictionary Extension

private extension Dictionary where Key == String {
    var jsonString: String {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
