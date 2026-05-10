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
        view.backgroundColor = ThemeTokens.Color.surface
        view.layer.cornerRadius = ThemeTokens.CornerRadius.xl
        view.layer.masksToBounds = true
        return view
    }()

    private let permanentKeyIcon: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        imageView.image = UIImage(systemName: "key.fill", withConfiguration: config)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = ThemeTokens.Color.success
        imageView.backgroundColor = ThemeTokens.Color.success.withAlphaComponent(0.15)
        imageView.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private let permanentKeyTitle: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("apikey.manage.permanent_key")
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.textColor = ThemeTokens.Color.text
        return label
    }()

    private let permanentKeyValue: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        label.textColor = ThemeTokens.Color.textSecondary
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
        button.tintColor = ThemeTokens.Color.primary
        return button
    }()

    private let refreshKeyButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let image = UIImage(systemName: "arrow.clockwise", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.setTitle(" \(L10n.tr("apikey.manage.refresh"))", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.tintColor = ThemeTokens.Color.warning
        return button
    }()

    private let testPermanentKeyButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let image = UIImage(systemName: "paperplane", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.setTitle(" \(L10n.tr("apikey.manage.test"))", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.tintColor = ThemeTokens.Color.success
        return button
    }()

    private let permanentKeySeparator: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.divider
        return view
    }()

    private let examplesButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = UIImage(systemName: "doc.text", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.setTitle(" \(L10n.tr("apikey.manage.view_examples"))", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.tintColor = ThemeTokens.Color.primary
        button.contentHorizontalAlignment = .left
        return button
    }()

    // 临时密钥标题
    private let temporaryKeysHeader: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("apikey.manage.temporary_keys")
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = ThemeTokens.Color.text
        return label
    }()

    private let temporaryKeysDescription: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("apikey.manage.temporary_keys_desc")
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = ThemeTokens.Color.textSecondary
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
        view.backgroundColor = ThemeTokens.Color.surface
        view.layer.cornerRadius = ThemeTokens.CornerRadius.xl
        view.layer.masksToBounds = true
        return view
    }()

    private let barkConfigTitle: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("apikey.manage.bark_config_title")
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = ThemeTokens.Color.text
        label.numberOfLines = 0
        return label
    }()

    private let barkKeyTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = L10n.tr("apikey.manage.bark_key_placeholder")
        tf.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        tf.borderStyle = .none
        tf.backgroundColor = ThemeTokens.Color.background
        tf.layer.cornerRadius = ThemeTokens.CornerRadius.md
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        tf.leftView = paddingView
        tf.leftViewMode = .always
        return tf
    }()

    private let barkServerTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = L10n.tr("apikey.manage.bark_server_placeholder")
        tf.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        tf.borderStyle = .none
        tf.backgroundColor = ThemeTokens.Color.background
        tf.layer.cornerRadius = ThemeTokens.CornerRadius.md
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        tf.leftView = paddingView
        tf.leftViewMode = .always
        return tf
    }()

    private let saveBarkConfigButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("apikey.manage.save_config"), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        button.backgroundColor = ThemeTokens.Color.primary
        button.setTitleColor(ThemeTokens.Color.surface, for: .normal)
        button.layer.cornerRadius = ThemeTokens.CornerRadius.md
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
        view.backgroundColor = ThemeTokens.Color.background

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
            make.height.equalTo(36)
        }

        refreshKeyButton.snp.makeConstraints { make in
            make.left.equalTo(copyPermanentKeyButton.snp.right).offset(12)
            make.centerY.equalTo(copyPermanentKeyButton)
            make.height.equalTo(36)
        }

        testPermanentKeyButton.snp.makeConstraints { make in
            make.left.equalTo(refreshKeyButton.snp.right).offset(12)
            make.centerY.equalTo(copyPermanentKeyButton)
            make.height.equalTo(36)
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
            make.height.equalTo(44)
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
            title: L10n.tr("apikey.manage.empty_title"),
            description: L10n.tr("apikey.manage.empty_description"),
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
        addButton.tintColor = ThemeTokens.Color.primary
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
            title: L10n.tr("apikey.manage.refresh_confirm_title"),
            message: L10n.tr("apikey.manage.refresh_confirm_message"),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.tr("apikey.manage.refresh_confirm"), style: .destructive) { [weak self] _ in
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

        let alert = UIAlertController(title: L10n.tr("apikey.manage.save_success"), message: L10n.tr("apikey.manage.bark_save_message"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
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
            title: L10n.tr("apikey.manage.create_title"),
            message: L10n.tr("apikey.manage.create_message"),
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = L10n.tr("apikey.manage.create_name_placeholder")
        }

        alert.addTextField { textField in
            textField.placeholder = L10n.tr("apikey.manage.create_group_placeholder")
        }

        let durations: [(String, TimeInterval)] = [
            (L10n.tr("apikey.manage.duration_1h"), 3600),
            (L10n.tr("apikey.manage.duration_1d"), 86400),
            (L10n.tr("apikey.manage.duration_7d"), 604800),
            (L10n.tr("apikey.manage.duration_30d"), 2592000)
        ]

        alert.addAction(UIAlertAction(title: L10n.tr("apikey.manage.next_step"), style: .default) { [weak self] _ in
            let name = alert.textFields?[0].text
            let groupId = alert.textFields?[1].text

            let durationAlert = UIAlertController(title: L10n.tr("apikey.manage.select_duration"), message: nil, preferredStyle: .actionSheet)
            for (title, duration) in durations {
                durationAlert.addAction(UIAlertAction(title: title, style: .default) { _ in
                    self?.viewModel.addTemporaryKey(duration: duration, name: name, groupId: groupId)
                })
            }
            durationAlert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))

            if let popoverController = durationAlert.popoverPresentationController {
                popoverController.barButtonItem = self?.navigationItem.rightBarButtonItem
            }

            self?.present(durationAlert, animated: true)
        })

        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        present(alert, animated: true)
    }

    private func showRefreshSuccess() {
        let alert = UIAlertController(
            title: L10n.tr("apikey.manage.refresh_success"),
            message: L10n.tr("apikey.manage.refresh_success_message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }

    private func showCopySuccess() {
        let alert = UIAlertController(
            title: L10n.tr("apikey.manage.copy_success"),
            message: L10n.tr("apikey.manage.copy_success_message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }

    private func showAddSuccess() {
        let alert = UIAlertController(
            title: L10n.tr("apikey.manage.add_success"),
            message: L10n.tr("apikey.manage.add_success_message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }

    private func showTestPushResult(success: Bool, message: String) {
        let alert = UIAlertController(
            title: success ? L10n.tr("apikey.manage.test_success") : L10n.tr("apikey.manage.test_failure"),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
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
        let deleteAction = UIContextualAction(style: .destructive, title: L10n.tr("common.delete")) { [weak self] _, _, completion in
            self?.deleteKeySubject.onNext(key.id)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")

        // 测试操作
        let testAction = UIContextualAction(style: .normal, title: L10n.tr("apikey.manage.test")) { [weak self] _, _, completion in
            self?.viewModel.sendTemporaryKeyTestPush(key: key)
            completion(true)
        }
        testAction.backgroundColor = ThemeTokens.Color.success
        testAction.image = UIImage(systemName: "paperplane.fill")

        // 编辑操作
        let editAction = UIContextualAction(style: .normal, title: L10n.tr("common.edit")) { [weak self] _, _, completion in
            self?.showEditGroupIdDialog(for: key)
            completion(true)
        }
        editAction.backgroundColor = ThemeTokens.Color.primary
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
            title: L10n.tr("apikey.manage.edit_group_title"),
            message: L10n.tr("apikey.manage.edit_group_message", key.name),
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = L10n.tr("apikey.manage.group_id")
            textField.text = key.boundGroupId
        }

        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.tr("common.save"), style: .default) { [weak self] _ in
            let newGroupId = alert.textFields?.first?.text
            self?.viewModel.updateKeyGroupId(id: key.id, groupId: newGroupId)
        })

        present(alert, animated: true)
    }
}
