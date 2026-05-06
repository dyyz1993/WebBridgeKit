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

    private let segmentedControl = UISegmentedControl(items: ["Handlers", "通知测试", "日志", "环境"])
    private let containerView = UIView()

    private var currentViewController: UIViewController?

    private lazy var handlerListVC = HandlerDebugListViewController()
    private lazy var notificationVC = NotificationDebugViewController()
    private lazy var logViewerVC = LogDebugViewController()
    private lazy var environmentVC = EnvironmentDebugViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "调试面板"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "完成",
            style: .done,
            target: self,
            action: #selector(closeTapped)
        )

        setupUI()
        switchToTab(index: 0)
    }

    private func setupUI() {
        view.addSubview(segmentedControl)
        view.addSubview(containerView)

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        segmentedControl.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.left.right.equalToSuperview().inset(16)
        }

        containerView.snp.makeConstraints { make in
            make.top.equalTo(segmentedControl.snp.bottom).offset(8)
            make.left.right.bottom.equalToSuperview()
        }
    }

    @objc private func segmentChanged() {
        switchToTab(index: segmentedControl.selectedSegmentIndex)
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
        view.backgroundColor = .systemGroupedBackground

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HandlerCell")

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "执行测试",
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
        let alert = UIAlertController(title: "执行测试", message: "选择要执行的 Handler 测试", preferredStyle: .actionSheet)

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

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
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
        view.backgroundColor = .systemGroupedBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Copy Info",
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
        descLabel.textColor = .secondaryLabel
        stack.addArrangedSubview(descLabel)

        let infoLabel = UILabel()
        infoLabel.text = "\(meta.category.emoji) \(meta.category.displayName) · action: \(meta.action)"
        infoLabel.textColor = .tertiaryLabel
        infoLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        stack.addArrangedSubview(infoLabel)

        if !meta.requiredPermissions.isEmpty {
            let permLabel = UILabel()
            permLabel.text = "🔐 Required: \(meta.requiredPermissions.joined(separator: ", "))"
            permLabel.textColor = .systemOrange
            stack.addArrangedSubview(permLabel)
        }

        if !meta.parameters.isEmpty {
            let header = UILabel()
            header.text = "Parameters"
            header.font = .systemFont(ofSize: 15, weight: .semibold)
            stack.addArrangedSubview(header)

            for param in meta.parameters {
                let field = makeParamField(param)
                stack.addArrangedSubview(field)
                paramInputs[param.name] = (field.arrangedSubviews.first as? UITextField)
            }
        }

        let button = UIButton(type: .system)
        button.setTitle("▶️ Execute", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: #selector(execute), for: .touchUpInside)
        stack.addArrangedSubview(button)

        let resultHeader = UILabel()
        resultHeader.text = "Result"
        resultHeader.font = .systemFont(ofSize: 15, weight: .semibold)
        stack.addArrangedSubview(resultHeader)

        resultTextView.isEditable = false
        resultTextView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        resultTextView.heightAnchor.constraint(equalToConstant: 200).isActive = true
        resultTextView.backgroundColor = .secondarySystemBackground
        resultTextView.layer.cornerRadius = 8
        resultTextView.text = "Tap Execute to test..."
        stack.addArrangedSubview(resultTextView)

        let copyButton = UIButton(type: .system)
        copyButton.setTitle("📋 Copy Result", for: .normal)
        copyButton.addTarget(self, action: #selector(copyResult), for: .touchUpInside)
        stack.addArrangedSubview(copyButton)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leftAnchor.constraint(equalTo: view.leftAnchor),
            scrollView.rightAnchor.constraint(equalTo: view.rightAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stack.leftAnchor.constraint(equalTo: scrollView.leftAnchor, constant: 16),
            stack.rightAnchor.constraint(equalTo: scrollView.rightAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
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
        textField.placeholder = param.defaultValue ?? "Enter \(param.name)"
        if let options = param.options {
            textField.text = options.first
        }
        stack.addArrangedSubview(textField)

        if let options = param.options {
            let optionsLabel = UILabel()
            optionsLabel.text = "Options: \(options.joined(separator: " | "))"
            optionsLabel.font = .systemFont(ofSize: 11, weight: .regular)
            optionsLabel.textColor = .tertiaryLabel
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

        resultTextView.text = "Executing \(meta.action)...\nParams: \(params)"

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
        let alert = UIAlertController(title: "Copied!", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func copyHandlerInfo() {
        UIPasteboard.general.string = meta.jsonDict.jsonString
        let alert = UIAlertController(title: "Copied!", message: "Handler info copied as JSON", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
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
        view.backgroundColor = .systemGroupedBackground

        let toolbar = makeToolbar()
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.backgroundColor = .secondarySystemBackground

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
        allButton.setTitle("All", for: .normal)
        allButton.addTarget(self, action: #selector(filterAll), for: .touchUpInside)
        stack.addArrangedSubview(allButton)

        let errorButton = UIButton(type: .system)
        errorButton.setTitle("Errors", for: .normal)
        errorButton.tintColor = .systemRed
        errorButton.addTarget(self, action: #selector(filterErrors), for: .touchUpInside)
        stack.addArrangedSubview(errorButton)

        let copyButton = UIButton(type: .system)
        copyButton.setTitle("Copy All", for: .normal)
        copyButton.addTarget(self, action: #selector(copyLogs), for: .touchUpInside)
        stack.addArrangedSubview(copyButton)

        let exportButton = UIButton(type: .system)
        exportButton.setTitle("Export JSON", for: .normal)
        exportButton.addTarget(self, action: #selector(exportJSON), for: .touchUpInside)
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
        textView.text = text.isEmpty ? "No logs yet." : text
    }

    @objc private func filterAll() {
        filterCategory = nil
        refreshLogs()
    }

    @objc private func filterErrors() {
        filterCategory = nil
        logs = StructuredLogger.shared.query(minLevel: .error, limit: 200)
        let text = logs.map { $0.consoleString }.joined(separator: "\n")
        textView.text = text.isEmpty ? "No errors!" : text
    }

    @objc private func copyLogs() {
        let text = logs.map { $0.debugString }.joined(separator: "\n\n")
        UIPasteboard.general.string = text
        let alert = UIAlertController(title: "Copied!", message: "\(logs.count) log entries copied", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func exportJSON() {
        let json = StructuredLogger.shared.exportJSON()
        UIPasteboard.general.string = json
        let alert = UIAlertController(title: "Exported!", message: "Logs exported as JSON to clipboard", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Environment

private class EnvironmentDebugViewController: UIViewController {

    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Copy",
            style: .plain,
            target: self,
            action: #selector(copyInfo)
        )

        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = .secondarySystemBackground

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
        let alert = UIAlertController(title: "Copied!", message: "Environment info copied", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
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
