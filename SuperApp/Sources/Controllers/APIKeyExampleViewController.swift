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

    private let examples = [
        CodeExample(
            title: L10n.tr("apikey.example.bark_basic"),
            language: "URL",
            code: """
            https://api.day.app/YOUR_KEY_HERE/推送标题/推送内容?group=WebBridgeKit
            """,
            description: L10n.tr("apikey.example.bark_basic_desc")
        ),
        CodeExample(
            title: L10n.tr("apikey.example.bark_autocopy"),
            language: "URL",
            code: """
            https://api.day.app/YOUR_KEY_HERE/复制测试?copy=测试内容&autoCopy=1
            """,
            description: L10n.tr("apikey.example.bark_autocopy_desc")
        ),
        CodeExample(
            title: L10n.tr("apikey.example.bark_critical"),
            language: "URL",
            code: """
            https://api.day.app/YOUR_KEY_HERE/严重警告?level=critical&volume=5
            """,
            description: L10n.tr("apikey.example.bark_critical_desc")
        ),
        CodeExample(
            title: L10n.tr("apikey.example.bark_icon"),
            language: "URL",
            code: """
            https://api.day.app/YOUR_KEY_HERE/图标测试?icon=https://day.app/assets/images/avatar.jpg&badge=1
            """,
            description: L10n.tr("apikey.example.bark_icon_desc")
        ),
        CodeExample(
            title: L10n.tr("apikey.example.swift_integration"),
            language: "Swift",
            code: """
            import Alamofire

            let headers = ["X-API-Key": "YOUR_KEY_HERE"]
            AF.request("https://api.webbridgekit.com/v1/pages", headers: headers)
                .responseJSON { response in
                    // 处理响应
                }
            """,
            description: L10n.tr("apikey.example.swift_integration_desc")
        ),
        CodeExample(
            title: L10n.tr("apikey.example.curl"),
            language: "Bash",
            code: """
            curl -H "X-API-Key: YOUR_KEY_HERE" \\
                 https://api.webbridgekit.com/v1/pages
            """,
            description: L10n.tr("apikey.example.curl_desc")
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
        label.text = L10n.tr("apikey.example.header")
        return label
    }()

    private let disposeBag = DisposeBag()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("apikey.example.title")
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
        showAlert(title: L10n.tr("apikey.example.copied_title"), message: L10n.tr("apikey.example.copied_message"))
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
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
