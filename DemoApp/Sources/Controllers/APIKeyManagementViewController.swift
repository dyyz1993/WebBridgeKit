//
//  APIKeyManagementViewController.swift
//  DemoApp
//
//  Created on 2026-02-07.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

/// API Key 管理页面
class APIKeyManagementViewController: UIViewController {
    
    private let disposeBag = DisposeBag()
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.register(UITableViewCell.self, forCellReuseIdentifier: "KeyCell")
        return table
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindData()
    }
    
    private func setupUI() {
        title = "密钥管理"
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: nil,
            action: nil
        )
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func bindData() {
        // 绑定列表数据
        APIKeyManager.shared.keys
            .bind(to: tableView.rx.items(cellIdentifier: "KeyCell", cellType: UITableViewCell.self)) { index, key, cell in
                var content = cell.defaultContentConfiguration()
                content.text = key.name
                content.secondaryText = key.value
                content.secondaryTextProperties.color = .secondaryLabel
                content.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                cell.contentConfiguration = content
                
                let switchView = UISwitch()
                switchView.isOn = key.isEnabled
                switchView.rx.controlEvent(.valueChanged)
                    .withLatestFrom(switchView.rx.isOn)
                    .subscribe(onNext: { isOn in
                        var updatedKey = key
                        updatedKey.isEnabled = isOn
                        APIKeyManager.shared.updateKey(updatedKey)
                    })
                    .disposed(by: self.disposeBag)
                cell.accessoryView = switchView
            }
            .disposed(by: disposeBag)
            
        // 处理新增 Key
        navigationItem.rightBarButtonItem?.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.showAddKeyAlert()
            })
            .disposed(by: disposeBag)
            
        // 处理删除
        tableView.rx.itemDeleted
            .subscribe(onNext: { indexPath in
                // 获取对应 ID 并删除
                APIKeyManager.shared.keys
                    .take(1)
                    .subscribe(onNext: { keys in
                        let key = keys[indexPath.row]
                        APIKeyManager.shared.deleteKey(id: key.id)
                    })
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)
    }
    
    private func showAddKeyAlert() {
        let alert = UIAlertController(title: "新增密钥", message: "请输入密钥名称，例如：开发推送", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "名称" }
        alert.addTextField { $0.placeholder = "描述（可选）" }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "创建", style: .default) { [weak self] _ in
            let name = alert.textFields?[0].text ?? "未命名密钥"
            let desc = alert.textFields?[1].text
            APIKeyManager.shared.createKey(name: name, description: desc)
        })
        
        present(alert, animated: true)
    }
}
