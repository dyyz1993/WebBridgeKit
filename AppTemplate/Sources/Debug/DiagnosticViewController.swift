//
//  DiagnosticViewController.swift
//  AppTemplate
//

import UIKit
import WebBridgeKit

/// 诊断页面 - 健康检查 + 一键全检
class DiagnosticViewController: UIViewController {
    
    private let textView = UITextView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Diagnostic"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "🔄 Run Checks",
            style: .plain,
            target: self,
            action: #selector(runChecks)
        )
        
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = .secondarySystemBackground
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        let copyButton = UIButton(type: .system)
        copyButton.setTitle("📋 Copy Report", for: .normal)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.addTarget(self, action: #selector(copyReport), for: .touchUpInside)
        
        view.addSubview(textView)
        view.addSubview(copyButton)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16),
            textView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: copyButton.topAnchor, constant: -16),
            
            copyButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16),
            copyButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),
            copyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            copyButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        runChecks()
    }
    
    @objc private func runChecks() {
        let report = DiagnosticEngine.shared.generateReport()
        textView.text = report
    }
    
    @objc private func copyReport() {
        let report = DiagnosticEngine.shared.generateReport()
        UIPasteboard.general.string = report
        let alert = UIAlertController(title: "Copied!", message: "Diagnostic report copied to clipboard", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
