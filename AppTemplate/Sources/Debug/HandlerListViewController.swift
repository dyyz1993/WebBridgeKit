//
//  HandlerListViewController.swift
//  AppTemplate
//

import UIKit
import WebBridgeKit

/// Handler 列表 - 自动从 HandlerRegistry 发现所有 Handler
class HandlerListViewController: UITableViewController {
    
    private var categories: [(HandlerCategory, [HandlerMeta])] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Handlers (\(HandlerRegistry.shared.count))"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        loadHandlers()
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
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return categories.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories[section].1.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let (category, handlers) = categories[section]
        return "\(category.emoji) \(category.displayName) (\(handlers.count))"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let handler = categories[indexPath.section].1[indexPath.row]
        
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
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let handler = categories[indexPath.section].1[indexPath.row]
        let detail = HandlerDetailViewController(meta: handler)
        navigationController?.pushViewController(detail, animated: true)
    }
}
