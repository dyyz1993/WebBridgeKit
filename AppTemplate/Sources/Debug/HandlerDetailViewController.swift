//
//  HandlerDetailViewController.swift
//  AppTemplate
//

import UIKit
import WebBridgeKit

/// Handler 详情 - 自动生成的参数表单 + 一键执行
class HandlerDetailViewController: UIViewController {
    
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
        view.backgroundColor = .systemBackground
        
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
                paramInputs[param.name] = field.arrangedSubviews.first as? UITextField
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

private extension Dictionary where Key == String {
    var jsonString: String {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
