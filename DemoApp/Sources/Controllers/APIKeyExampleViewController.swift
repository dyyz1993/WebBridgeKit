//
//  APIKeyExampleViewController.swift
//  DemoApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

/// API密钥使用示例视图控制器
class APIKeyExampleViewController: UIViewController {

    // MARK: - Properties

    private let examples = [
        CodeExample(
            title: "Swift 请求",
            language: "Swift",
            code: """
            import Alamofire

            let headers = ["X-API-Key": "YOUR_KEY_HERE"]
            AF.request("https://api.webbridgekit.com/v1/pages", headers: headers)
                .responseJSON { response in
                    // 处理响应
                }
            """,
            description: "使用 Alamofire 发送带 API Key 的请求"
        ),
        CodeExample(
            title: "cURL 请求",
            language: "Bash",
            code: """
            curl -H "X-API-Key: YOUR_KEY_HERE" \\
                 https://api.webbridgekit.com/v1/pages
            """,
            description: "使用 cURL 命令行工具发送请求"
        ),
        CodeExample(
            title: "JavaScript 请求",
            language: "JavaScript",
            code: """
            fetch('https://api.webbridgekit.com/v1/pages', {
              method: 'GET',
              headers: {
                'X-API-Key': 'YOUR_KEY_HERE',
                'Content-Type': 'application/json'
              }
            })
            .then(response => response.json())
            .then(data => console.log(data));
            """,
            description: "使用 JavaScript Fetch API 发送请求"
        ),
        CodeExample(
            title: "Python 请求",
            language: "Python",
            code: """
            import requests

            headers = {'X-API-Key': 'YOUR_KEY_HERE'}
            response = requests.get(
                'https://api.webbridgekit.com/v1/pages',
                headers=headers
            )

            # 处理响应
            data = response.json()
            """,
            description: "使用 Python requests 库发送请求"
        )
    ]

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.backgroundColor = .systemGroupedBackground
        return table
    }()

    private let headerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = "以下是使用 API Key 的示例代码，点击示例或复制按钮即可复制代码。"
        return label
    }()

    private let disposeBag = DisposeBag()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "使用示例"
        setupUI()
        bindData()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tableView.register(CodeExampleCell.self, forCellReuseIdentifier: "CodeExampleCell")
        tableView.delegate = self
        tableView.dataSource = self

        // 设置 header
        let headerSize = headerLabel.sizeThatFits(CGSize(width: view.bounds.width - 32, height: .greatestFiniteMagnitude))
        headerLabel.frame = CGRect(x: 16, y: 16, width: view.bounds.width - 32, height: headerSize.height)

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: headerSize.height + 24))
        headerView.addSubview(headerLabel)
        tableView.tableHeaderView = headerView
    }

    private func bindData() {
        tableView.rx.itemSelected
            .subscribe(onNext: { [weak self] indexPath in
                self?.copyExample(at: indexPath.row)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Actions

    private func copyExample(at index: Int) {
        guard index >= 0 && index < examples.count else { return }
        let example = examples[index]
        UIPasteboard.general.string = example.code
        showAlert(title: "已复制", message: "示例代码已复制到剪贴板")
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension APIKeyExampleViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return examples.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "CodeExampleCell",
            for: indexPath
        ) as? CodeExampleCell else {
            return UITableViewCell()
        }

        let example = examples[indexPath.row]
        cell.configure(with: example)

        // 设置复制按钮回调
        cell.onCopyTapped = { [weak self] in
            self?.copyExample(at: indexPath.row)
        }

        return cell
    }
}

// MARK: - UITableViewDelegate

extension APIKeyExampleViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        copyExample(at: indexPath.row)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
}
