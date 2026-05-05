//
//  EnvironmentViewController.swift
//  AppTemplate
//

import UIKit
import WebBridgeKit

/// 环境信息页面
class EnvironmentViewController: UIViewController {
    
    private let textView = UITextView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Environment"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "📋 Copy",
            style: .plain,
            target: self,
            action: #selector(copyInfo)
        )
        
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = .secondarySystemBackground
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16),
            textView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let env = EnvironmentInfo()
        textView.text = env.debugString
    }
    
    @objc private func copyInfo() {
        let env = EnvironmentInfo()
        UIPasteboard.general.string = env.debugString
        let alert = UIAlertController(title: "Copied!", message: "Environment info copied", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
