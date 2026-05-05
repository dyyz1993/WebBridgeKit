//
//  APIKeyExampleViewController.swift
//  SuperApp
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
            title: "Bark 基础推送",
            language: "URL",
            code: """
            https://api.day.app/YOUR_KEY_HERE/推送标题/推送内容?group=WebBridgeKit
            """,
            description: "最基本的推送方式，包含标题、内容和分组"
        ),
        CodeExample(
            title: "Bark 自动复制 (iOS 14.5+)",
            language: "URL",
            code: """
            https://api.day.app/YOUR_KEY_HERE/复制测试?copy=测试内容&autoCopy=1
            """,
            description: "收到推送时自动将指定内容复制到剪贴板，非常适合传输验证码"
        ),
        CodeExample(
            title: "Bark 重要警告 (时效性通知)",
            language: "URL",
            code: """
            https://api.day.app/YOUR_KEY_HERE/严重警告?level=critical&volume=5
            """,
            description: "即使在静音或勿扰模式下也会发出声音，适用于监控报警等高优先级场景"
        ),
        CodeExample(
            title: "Bark 自定义图标与角标",
            language: "URL",
            code: """
            https://api.day.app/YOUR_KEY_HERE/图标测试?icon=https://day.app/assets/images/avatar.jpg&badge=1
            """,
            description: "自定义通知显示的图标，并设置 App 的角标数字"
        ),
        CodeExample(
            title: "Swift 集成示例",
            language: "Swift",
            code: """
            import Alamofire

            let headers = ["X-API-Key": "YOUR_KEY_HERE"]
            AF.request("https://api.webbridgekit.com/v1/pages", headers: headers)
                .responseJSON { response in
                    // 处理响应
                }
            """,
            description: "在 iOS 应用中使用 Alamofire 携带 API Key 进行请求"
        ),
        CodeExample(
            title: "cURL 命令行",
            language: "Bash",
            code: """
            curl -H "X-API-Key: YOUR_KEY_HERE" \\
                 https://api.webbridgekit.com/v1/pages
            """,
            description: "在终端或脚本中快速验证 API 有效性"
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
