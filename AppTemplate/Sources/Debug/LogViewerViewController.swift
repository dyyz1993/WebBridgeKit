//
//  LogViewerViewController.swift
//  AppTemplate
//

import UIKit
import WebBridgeKit

/// 日志查看器 - 实时查看结构化日志
class LogViewerViewController: UIViewController {
    
    private let textView = UITextView()
    private var logs: [LogEntry] = []
    private var filterCategory: LogCategory?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Logs"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Refresh",
            style: .plain,
            target: self,
            action: #selector(refreshLogs)
        )
        
        let toolbar = makeToolbar()
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.backgroundColor = .secondarySystemBackground
        
        view.addSubview(toolbar)
        view.addSubview(textView)
        
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbar.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 8),
            toolbar.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -8),
            toolbar.heightAnchor.constraint(equalToConstant: 44),
            
            textView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 8),
            textView.leftAnchor.constraint(equalTo: view.leftAnchor),
            textView.rightAnchor.constraint(equalTo: view.rightAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
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
        copyButton.setTitle("📋 Copy All", for: .normal)
        copyButton.addTarget(self, action: #selector(copyLogs), for: .touchUpInside)
        stack.addArrangedSubview(copyButton)
        
        let exportButton = UIButton(type: .system)
        exportButton.setTitle("📤 Export JSON", for: .normal)
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
        textView.text = text.isEmpty ? "No logs yet. Interact with the app to generate logs." : text
    }
    
    @objc private func filterAll() {
        filterCategory = nil
        refreshLogs()
    }
    
    @objc private func filterErrors() {
        filterCategory = nil
        logs = StructuredLogger.shared.query(minLevel: .error, limit: 200)
        let text = logs.map { $0.consoleString }.joined(separator: "\n")
        textView.text = text.isEmpty ? "No errors! 🎉" : text
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
