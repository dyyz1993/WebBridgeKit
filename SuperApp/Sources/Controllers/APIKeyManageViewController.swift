//
//  APIKeyManageViewController.swift
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

/// 密钥管理视图控制器
class APIKeyManageViewController: BaseViewController<APIKeyManageViewModel> {

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.backgroundColor = .clear
        return scroll
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    // 永久密钥卡片
    private let permanentKeyCard: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private let permanentKeyIcon: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        imageView.image = UIImage(systemName: "key.fill", withConfiguration: config)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.systemGreen
        imageView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
        imageView.layer.cornerRadius = 12
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private let permanentKeyTitle: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("apikey.manage.permanent_key")
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.textColor = UIColor.label
        return label
    }()

    private let permanentKeyValue: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()

    private let copyPermanentKeyButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let image = UIImage(systemName: "doc.on.doc", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.setTitle(" \(L10n.tr("common.copy"))", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.tintColor = UIColor.systemBlue
        return button
    }()

    private let refreshKeyButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let image = UIImage(systemName: "arrow.clockwise", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.setTitle(" \(L10n.tr("apikey.manage.refresh"))", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.tintColor = UIColor.systemOrange
        return button
    }()

    private let testPermanentKeyButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let image = UIImage(systemName: "paperplane", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.setTitle(" \(L10n.tr("apikey.manage.test"))", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.tintColor = UIColor.systemGreen
        return button
    }()

    private let permanentKeySeparator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.separator
        return view
    }()

    private let examplesButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = UIImage(systemName: "doc.text", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.setTitle(" \(L10n.tr("apikey.manage.view_examples"))", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.tintColor = UIColor.systemBlue
        button.contentHorizontalAlignment = .left
        return button
    }()

    // 临时密钥标题
    private let temporaryKeysHeader: UILabel = {
        let label = UILabel()
        label.text = "临时密钥"
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = UIColor.label
        return label
    }()

    private let temporaryKeysDescription: UILabel = {
        let label = UILabel()
        label.text = "创建有时效性的临时密钥用于临时访问"
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    // 临时密钥表格
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.register(APIKeyCell.self, forCellReuseIdentifier: APIKeyCell.identifier)
        table.tableFooterView = UIView()
        table.isScrollEnabled = false
        return table
    }()

    // Bark 配置卡片
    private let barkConfigCard: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private let barkConfigTitle: UILabel = {
        let label = UILabel()
        label.text = "Bark 推送配置 (开发调试)"
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = UIColor.label
        return label
    }()

    private let barkKeyTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "在此输入您的 Bark Key (从手机 Bark App 获取)"
        tf.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        tf.borderStyle = .none
        tf.backgroundColor = UIColor.tertiarySystemBackground
        tf.layer.cornerRadius = 8
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        tf.leftViewMode = .always
        return tf
    }()

    private let barkServerTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "服务器地址 (默认: https://api.day.app)"
        tf.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        tf.borderStyle = .none
        tf.backgroundColor = UIColor.tertiarySystemBackground
        tf.layer.cornerRadius = 8
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        tf.leftViewMode = .always
        return tf
    }()

    private let saveBarkConfigButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("保存配置", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()

    // 空状态视图
    private let emptyStateView = EmptyStateView()

    // MARK: - Properties

    private var currentTemporaryKeys: [APIKey] = []
    private let deleteKeySubject = PublishSubject<String>()
    private let refreshKeySubject = PublishSubject<Void>()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("apikey.manage.title")
        setupUI()
        setupRightBarButton()
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = UIColor.systemGroupedBackground

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        // 添加永久密钥卡片
        contentView.addSubview(permanentKeyCard)
        permanentKeyCard.addSubview(permanentKeyIcon)
        permanentKeyCard.addSubview(permanentKeyTitle)
        permanentKeyCard.addSubview(permanentKeyValue)
        permanentKeyCard.addSubview(copyPermanentKeyButton)
        permanentKeyCard.addSubview(refreshKeyButton)
        permanentKeyCard.addSubview(testPermanentKeyButton)
        permanentKeyCard.addSubview(permanentKeySeparator)
        permanentKeyCard.addSubview(examplesButton)

        permanentKeyCard.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        permanentKeyIcon.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(16)
            make.width.height.equalTo(48)
        }

        permanentKeyTitle.snp.makeConstraints { make in
            make.left.equalTo(permanentKeyIcon.snp.right).offset(12)
            make.top.equalToSuperview().offset(18)
            make.right.equalToSuperview().offset(-16)
        }

        permanentKeyValue.snp.makeConstraints { make in
            make.left.equalTo(permanentKeyIcon.snp.right).offset(12)
            make.top.equalTo(permanentKeyTitle.snp.bottom).offset(8)
            make.right.equalToSuperview().offset(-16)
        }

        copyPermanentKeyButton.snp.makeConstraints { make in
            make.left.equalTo(permanentKeyIcon.snp.right).offset(12)
            make.top.equalTo(permanentKeyValue.snp.bottom).offset(12)
            make.height.equalTo(32)
        }

        refreshKeyButton.snp.makeConstraints { make in
            make.left.equalTo(copyPermanentKeyButton.snp.right).offset(12)
            make.centerY.equalTo(copyPermanentKeyButton)
            make.height.equalTo(32)
        }

        testPermanentKeyButton.snp.makeConstraints { make in
            make.left.equalTo(refreshKeyButton.snp.right).offset(12)
            make.centerY.equalTo(copyPermanentKeyButton)
            make.height.equalTo(32)
        }

        permanentKeySeparator.snp.makeConstraints { make in
            make.top.equalTo(copyPermanentKeyButton.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(0.5)
        }

        examplesButton.snp.makeConstraints { make in
            make.top.equalTo(permanentKeySeparator.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(32)
            make.bottom.equalToSuperview().offset(-16)
        }

        // 添加临时密钥标题
        contentView.addSubview(temporaryKeysHeader)
        temporaryKeysHeader.snp.makeConstraints { make in
            make.top.equalTo(permanentKeyCard.snp.bottom).offset(24)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        contentView.addSubview(temporaryKeysDescription)
        temporaryKeysDescription.snp.makeConstraints { make in
            make.top.equalTo(temporaryKeysHeader.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        // 添加表格
        contentView.addSubview(tableView)
        contentView.addSubview(emptyStateView)

        // 添加 Bark 配置
        contentView.addSubview(barkConfigCard)
        barkConfigCard.addSubview(barkConfigTitle)
        barkConfigCard.addSubview(barkKeyTextField)
        barkConfigCard.addSubview(barkServerTextField)
        barkConfigCard.addSubview(saveBarkConfigButton)

        tableView.snp.makeConstraints { make in
            make.top.equalTo(temporaryKeysDescription.snp.bottom).offset(12)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.height.equalTo(200) // 初始高度
        }

        barkConfigCard.snp.makeConstraints { make in
            make.top.equalTo(tableView.snp.bottom).offset(24)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-32)
        }

        barkConfigTitle.snp.makeConstraints { make in
            make.top.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        barkKeyTextField.snp.makeConstraints { make in
            make.top.equalTo(barkConfigTitle.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(44)
        }

        barkServerTextField.snp.makeConstraints { make in
            make.top.equalTo(barkKeyTextField.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(44)
        }

        saveBarkConfigButton.snp.makeConstraints { make in
            make.top.equalTo(barkServerTextField.snp.bottom).offset(16)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().offset(-16)
        }

        emptyStateView.snp.makeConstraints { make in
            make.top.equalTo(temporaryKeysDescription.snp.bottom).offset(12)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.height.equalTo(200)
        }

        // 空状态视图配置
        emptyStateView.configure(
            icon: "clock.badge.xmark",
            title: "暂无临时密钥",
            description: "点击右上角 + 按钮创建临时密钥",
            actionTitle: nil
        )

        // 按钮事件
        copyPermanentKeyButton.addTarget(self, action: #selector(copyPermanentKeyTapped), for: .touchUpInside)
        refreshKeyButton.addTarget(self, action: #selector(refreshKeyTapped), for: .touchUpInside)
        testPermanentKeyButton.addTarget(self, action: #selector(testPermanentKeyTapped), for: .touchUpInside)
        examplesButton.addTarget(self, action: #selector(showExamplesTapped), for: .touchUpInside)
        saveBarkConfigButton.addTarget(self, action: #selector(saveBarkConfigTapped), for: .touchUpInside)

        // 初始化加载配置
        barkKeyTextField.text = viewModel.getBarkKey()
        barkServerTextField.text = viewModel.getBarkServer()
    }

    private func setupRightBarButton() {
        let addButton = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addTemporaryKeyTapped)
        )
        addButton.tintColor = UIColor.systemBlue
        navigationItem.rightBarButtonItem = addButton
    }

    // MARK: - Bind ViewModel

    override func bindViewModel() {
        let copyKey = copyPermanentKeyButton.rx.tap.asDriver()
        let refreshKey = refreshKeySubject.asDriver(onErrorJustReturn: ())
        let addTemporaryKey = Driver<Void>.never() // 通过按钮直接处理
        let deleteKey = deleteKeySubject.asDriver(onErrorJustReturn: "")
        let showExamples = examplesButton.rx.tap.asDriver()

        let input = APIKeyManageViewModel.Input(
            copyKey: copyKey,
            refreshKey: refreshKey,
            addTemporaryKey: addTemporaryKey,
            deleteKey: deleteKey,
            showExamples: showExamples
        )

        let output = viewModel.transform(input: input)

        // 绑定永久密钥
        output.permanentKey
            .drive(onNext: { [weak self] key in
                self?.permanentKeyValue.text = self?.viewModel.maskKey(key)
            })
            .disposed(by: rx)

        // 绑定临时密钥列表
        output.temporaryKeys
            .drive(onNext: { [weak self] keys in
                self?.updateTableView(with: keys)
            })
            .disposed(by: rx)

        // 刷新成功
        output.refreshSuccess
            .drive(onNext: { [weak self] success in
                if success {
                    self?.showRefreshSuccess()
                }
            })
            .disposed(by: rx)

        // 复制成功
        output.copySuccess
            .drive(onNext: { [weak self] in
                self?.showCopySuccess()
            })
            .disposed(by: rx)

        // 添加临时密钥成功
        output.addedTemporaryKey
            .drive(onNext: { [weak self] key in
                if key != nil {
                    self?.showAddSuccess()
                }
            })
            .disposed(by: rx)

        // 显示使用示例
        output.showExamples
            .drive(onNext: { [weak self] in
                self?.showExamples()
            })
            .disposed(by: rx)

        // 设置 TableView 数据源和代理
        tableView.dataSource = self
        tableView.delegate = self

        // 绑定测试推送结果
        output.testPushResult
            .drive(onNext: { [weak self] result in
                self?.showTestPushResult(success: result.success, message: result.message)
            })
            .disposed(by: rx)
    }

    // MARK: - Actions

    @objc private func copyPermanentKeyTapped() {
        // 已经通过 RxSwift 绑定处理
    }

    @objc private func refreshKeyTapped() {
        let alert = UIAlertController(
            title: "刷新永久密钥",
            message: "刷新后旧的永久密钥将失效，确认要继续吗？",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确认刷新", style: .destructive) { [weak self] _ in
            // 触发刷新
            self?.refreshKeySubject.onNext(())
        })

        present(alert, animated: true)
    }

    @objc private func testPermanentKeyTapped() {
        viewModel.sendPermanentKeyTestPush()
    }

    @objc private func addTemporaryKeyTapped() {
        showKeyCreationDialog()
    }

    @objc private func saveBarkConfigTapped() {
        let key = barkKeyTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let server = barkServerTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        viewModel.saveBarkConfig(key: key, server: server)

        let alert = UIAlertController(title: "保存成功", message: "Bark 配置已更新", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)

        view.endEditing(true)
    }

    @objc private func showExamplesTapped() {
        // 已经通过 RxSwift 绑定处理
    }

    // MARK: - Private Methods

    private func updateTableView(with keys: [APIKey]) {
        currentTemporaryKeys = keys

        if keys.isEmpty {
            tableView.isHidden = true
            emptyStateView.isHidden = false
            contentView.layoutIfNeeded()
        } else {
            tableView.isHidden = false
            emptyStateView.isHidden = true

            // 更新表格高度
            let rowCount = keys.count
            let rowHeight: CGFloat = 80
            let headerHeight: CGFloat = 0
            let newHeight = CGFloat(rowCount) * rowHeight + headerHeight

            tableView.snp.updateConstraints { make in
                make.height.equalTo(newHeight)
            }

            tableView.reloadData()
        }
    }

    private func showKeyCreationDialog() {
        let alert = UIAlertController(
            title: "创建临时密钥",
            message: "请输入密钥名称和绑定的群组 ID（可选）",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "密钥名称（如：GitHub 推送）"
        }

        alert.addTextField { textField in
            textField.placeholder = "群组 ID (可选)"
        }

        let durations: [(String, TimeInterval)] = [
            ("1 小时", 3600),
            ("1 天", 86400),
            ("7 天", 604800),
            ("30 天", 2592000)
        ]

        // 这里为了简化 UI，使用二级弹窗选择时长
        alert.addAction(UIAlertAction(title: "下一步", style: .default) { [weak self] _ in
            let name = alert.textFields?[0].text
            let groupId = alert.textFields?[1].text

            let durationAlert = UIAlertController(title: "选择有效期", message: nil, preferredStyle: .actionSheet)
            for (title, duration) in durations {
                durationAlert.addAction(UIAlertAction(title: title, style: .default) { _ in
                    self?.viewModel.addTemporaryKey(duration: duration, name: name, groupId: groupId)
                })
            }
            durationAlert.addAction(UIAlertAction(title: "取消", style: .cancel))

            // iPad 支持
            if let popoverController = durationAlert.popoverPresentationController {
                popoverController.barButtonItem = self?.navigationItem.rightBarButtonItem
            }

            self?.present(durationAlert, animated: true)
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func showRefreshSuccess() {
        let alert = UIAlertController(
            title: "刷新成功",
            message: "永久密钥已刷新",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func showCopySuccess() {
        let alert = UIAlertController(
            title: "复制成功",
            message: "密钥已复制到剪贴板",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func showAddSuccess() {
        let alert = UIAlertController(
            title: "创建成功",
            message: "临时密钥已创建",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func showTestPushResult(success: Bool, message: String) {
        let alert = UIAlertController(
            title: success ? "测试成功" : "测试失败",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func showExamples() {
        let examplesVC = APIKeyExampleViewController()
        navigationController?.pushViewController(examplesVC, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension APIKeyManageViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentTemporaryKeys.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: APIKeyCell.identifier, for: indexPath) as? APIKeyCell else {
            return UITableViewCell()
        }

        let key = currentTemporaryKeys[indexPath.row]
        cell.configure(with: key, maskKey: false)
        cell.onCopyTap = { [weak self] keyValue in
            UIPasteboard.general.string = keyValue
            self?.showCopySuccess()
        }

        return cell
    }
}

// MARK: - UITableViewDelegate

extension APIKeyManageViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let key = currentTemporaryKeys[indexPath.row]

        // 删除操作
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            self?.deleteKeySubject.onNext(key.id)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")

        // 测试操作
        let testAction = UIContextualAction(style: .normal, title: "测试") { [weak self] _, _, completion in
            self?.viewModel.sendTemporaryKeyTestPush(key: key)
            completion(true)
        }
        testAction.backgroundColor = UIColor.systemGreen
        testAction.image = UIImage(systemName: "paperplane.fill")

        // 编辑操作
        let editAction = UIContextualAction(style: .normal, title: "编辑") { [weak self] _, _, completion in
            self?.showEditGroupIdDialog(for: key)
            completion(true)
        }
        editAction.backgroundColor = UIColor.systemBlue
        editAction.image = UIImage(systemName: "square.and.pencil")

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, testAction, editAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}

// MARK: - Actions

extension APIKeyManageViewController {

    private func showEditGroupIdDialog(for key: APIKey) {
        let alert = UIAlertController(
            title: "编辑群组绑定",
            message: "修改密钥 \"\(key.name)\" 绑定的群组 ID",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "群组 ID"
            textField.text = key.boundGroupId
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            let newGroupId = alert.textFields?.first?.text
            self?.viewModel.updateKeyGroupId(id: key.id, groupId: newGroupId)
        })

        present(alert, animated: true)
    }
}
