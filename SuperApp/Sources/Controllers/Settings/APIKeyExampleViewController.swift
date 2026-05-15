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
import WebBridgeKit

/// API密钥使用示例视图控制器
class APIKeyExampleViewController: UIViewController {

    // MARK: - Properties

    private let examples: [CodeExample] = [
        CodeExample(
            title: NSLocalizedString("apikey.example.bark_basic", tableName: "Localizable", bundle: .main, value: "Bark 基础推送", comment: ""),
            language: "URL",
            code: """
            https://api.day.app/YOUR_KEY_HERE/推送标题/推送内容?group=WebBridgeKit
            """,
            description: NSLocalizedString("apikey.example.bark_basic_desc", tableName: "Localizable", bundle: .main, value: "最简单的推送方式，只需拼接 URL 即可发送通知", comment: "")
        ),
        CodeExample(
            title: NSLocalizedString("apikey.example.bark_autocopy", tableName: "Localizable", bundle: .main, value: "自动复制推送", comment: ""),
            language: "URL",
            code: """
            https://api.day.app/YOUR_KEY_HERE/复制测试?copy=测试内容&autoCopy=1
            """,
            description: NSLocalizedString("apikey.example.bark_autocopy_desc", tableName: "Localizable", bundle: .main, value: "推送到达后自动复制指定内容到剪贴板", comment: "")
        ),
        CodeExample(
            title: NSLocalizedString("apikey.example.bark_critical", tableName: "Localizable", bundle: .main, value: "严重警告推送", comment: ""),
            language: "URL",
            code: """
            https://api.day.app/YOUR_KEY_HERE/严重警告?level=critical&volume=5
            """,
            description: NSLocalizedString("apikey.example.bark_critical_desc", tableName: "Localizable", bundle: .main, value: "使用时区和重要性级别发送紧急通知", comment: "")
        ),
        CodeExample(
            title: NSLocalizedString("apikey.example.bark_icon", tableName: "Localizable", bundle: .main, value: "自定义图标推送", comment: ""),
            language: "URL",
            code: """
            https://api.day.app/YOUR_KEY_HERE/图标测试?icon=https://day.app/assets/images/avatar.jpg&badge=1
            """,
            description: NSLocalizedString("apikey.example.bark_icon_desc", tableName: "Localizable", bundle: .main, value: "自定义推送图标和角标", comment: "")
        ),
        CodeExample(
            title: NSLocalizedString("apikey.example.swift_integration", tableName: "Localizable", bundle: .main, value: "Swift 集成示例", comment: ""),
            language: "Swift",
            code: """
            import Alamofire

            let headers = ["X-API-Key": "YOUR_KEY_HERE"]
            AF.request("https://wbk.shanbox.19930810.xyz:8443/v1/pages", headers: headers)
                .responseJSON { response in
                    // 处理响应
                }
            """,
            description: NSLocalizedString("apikey.example.swift_integration_desc", tableName: "Localizable", bundle: .main, value: "在 Swift 中使用 API Key 调用接口", comment: "")
        ),
        CodeExample(
            title: NSLocalizedString("apikey.example.curl", tableName: "Localizable", bundle: .main, value: "cURL 示例", comment: ""),
            language: "Bash",
            code: """
            curl -H "X-API-Key: YOUR_KEY_HERE" \\
                 https://wbk.shanbox.19930810.xyz:8443/v1/pages
            """,
            description: NSLocalizedString("apikey.example.curl_desc", tableName: "Localizable", bundle: .main, value: "使用 cURL 命令行调用 API", comment: "")
        )
    ]

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.backgroundColor = ThemeColors.current.background
        return table
    }()

    private let headerLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.subheadline
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 0
        label.text = NSLocalizedString("apikey.example.header", tableName: "Localizable", bundle: .main, value: "以下是使用 API 密钥的各种示例，点击可复制代码", comment: "")
        return label
    }()

    private let disposeBag = DisposeBag()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("apikey.example.title", tableName: "Localizable", bundle: .main, value: "API 密钥使用示例", comment: "")
        setupUI()
        bindData()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = ThemeColors.current.background

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tableView.register(CodeExampleCell.self, forCellReuseIdentifier: "CodeExampleCell")
        tableView.delegate = self
        tableView.dataSource = self

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
        showAlert(
            title: NSLocalizedString("apikey.example.copied_title", tableName: "Localizable", bundle: .main, value: "已复制", comment: ""),
            message: NSLocalizedString("apikey.example.copied_message", tableName: "Localizable", bundle: .main, value: "代码已复制到剪贴板", comment: "")
        )
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("common.ok", tableName: "Localizable", bundle: .main, value: "确定", comment: ""), style: .default))
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
