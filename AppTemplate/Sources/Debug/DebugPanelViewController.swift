//
//  DebugPanelViewController.swift
//  AppTemplate
//
//  Created on 2025-05-05.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import WebBridgeKit
import SnapKit

/// 🧠 统一的调试面板入口
/// 所有基于 App 的 Handler + 诊断系统都可以从这个面板访问
public class DebugPanelViewController: UIViewController {

    private var categories: [(HandlerCategory, [HandlerMeta])] = []
    private var handlerMap: [String: HandlerMeta] = [:]

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.delegate = self
        table.dataSource = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "HandlerCell")
        table.register(ButtonCell.self, forCellReuseIdentifier: "ButtonCell")
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()

    // MARK: - Lifecycle

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    // MARK: - UI Setup

    private func setupUI() {
        title = "🧠 Handlers"
        view.backgroundColor = .systemBackground

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

    private func loadData() {
        let summary = HandlerRegistry.shared.categorySummary()
        categories = summary.map { (category, _) in
            (category, HandlerRegistry.shared.handlers(category: category))
        }

        // Build handler map for quick lookup
        handlerMap.removeAll()
        for (_, handlers) in categories {
            for handler in handlers {
                handlerMap[handler.action] = handler
            }
        }

        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func performOneClickTest() {
        let alert = UIAlertController(title: "执行测试", message: "选择要执行的 Handler 测试", preferredStyle: .actionSheet)

        for (_, handlers) in categories {
            for handler in handlers {
                alert.addAction(UIAlertAction(
                    title: "\(handler.displayName) (\(handler.action))",
                    style: .default,
                    handler: { [weak self] _ in
                        self?.executeHandler(handler)
                    }
                ))
            }
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func executeHandler(_ meta: HandlerMeta) {
        StructuredLogger.shared.info(
            "Executing test for handler: \(meta.displayName)",
            category: .debug,
            action: meta.action
        )

        // TODO: Wire to real HandlerRegistry when ready
        let alert = UIAlertController(
            title: "执行测试",
            message: "测试 \(meta.displayName) (\(meta.action))",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension DebugPanelViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return categories.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories[section].1.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let handler = categories[indexPath.section].1[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: "HandlerCell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = handler.displayName
        config.secondaryText = handler.action
        config.image = UIImage(systemName: "chevron.right")
        config.imageProperties.tintColor = .tertiarySystemFill

        if !handler.requiredPermissions.isEmpty {
            config.secondaryText = "\(handler.action) 🔐"
        }

        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let (category, handlers) = categories[section]
        return "\(category.emoji) \(category.displayName) (\(handlers.count))"
    }
}

// MARK: - UITableViewDelegate

extension DebugPanelViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let handler = categories[indexPath.section].1[indexPath.row]
        let detail = HandlerDetailViewController(meta: handler)
        navigationController?.pushViewController(detail, animated: true)
    }
}

// MARK: - ButtonCell

private class ButtonCell: UITableViewCell {
    let button = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        contentView.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
    }

    func configure(title: String, action: @escaping () -> Void) {
        button.setTitle(title, for: .normal)
        button.removeTarget(nil, action: nil, for: .touchUpInside)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }
}
