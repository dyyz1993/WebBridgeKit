//
//  ServerConfigViewController.swift
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

/// 服务器配置视图控制器
class ServerConfigViewController: BaseViewController<ServerConfigViewModel> {

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.backgroundColor = UIColor.systemGroupedBackground
        table.register(SegmentedCell.self, forCellReuseIdentifier: SegmentedCell.identifier)
        table.register(TextFieldCell.self, forCellReuseIdentifier: TextFieldCell.identifier)
        table.register(ButtonCell.self, forCellReuseIdentifier: ButtonCell.identifier)
        table.separatorStyle = .singleLine
        table.tableFooterView = UIView()
        table.keyboardDismissMode = .interactive
        return table
    }()

    private let loadingView: LoadingView = {
        let view = LoadingView()
        view.isHidden = true
        return view
    }()

    // MARK: - Section Data

    private enum Section: Int, CaseIterable {
        case serverType = 0
        case serverAddress
        case apiEndpoint
        case actions

        var title: String {
            switch self {
            case .serverType: return "服务器类型"
            case .serverAddress: return "服务器地址"
            case .apiEndpoint: return "API端点"
            case .actions: return "操作"
            }
        }
    }

    // MARK: - Properties

    private var currentServerType: String = "default"
    private var currentBaseURL: String?
    private var currentAPIEndpoint: String?
    private var isCustomServer: Bool = false
    
    private var baseURLValidationError: String?
    private var apiEndpointValidationError: String?

    // Relays for cell callbacks
    private var serverTypeChange: PublishRelay<String>?
    private var baseURLChange: PublishRelay<String?>?
    private var apiEndpointChange: PublishRelay<String?>?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "服务器配置"
        setupUI()
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = UIColor.systemGroupedBackground

        view.addSubview(tableView)
        view.addSubview(loadingView)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - Bind ViewModel

    override func bindViewModel() {
        // 输入流
        let serverTypeChange = PublishRelay<String>()
        let baseURLChange = PublishRelay<String?>()
        let apiEndpointChange = PublishRelay<String?>()

        // 创建输入
        let input = ServerConfigViewModel.Input(
            serverTypeChange: serverTypeChange.asDriver(onErrorJustReturn: "default"),
            baseURLChange: baseURLChange.asDriver(onErrorJustReturn: nil),
            apiEndpointChange: apiEndpointChange.asDriver(onErrorJustReturn: nil),
            testConnection: Driver.never(), // 会在 handleButtonAction 中触发
            saveConfig: Driver.never(),     // 会在 handleButtonAction 中触发
            resetConfig: Driver.never()     // 会在 handleButtonAction 中触发
        )

        let output = viewModel.transform(input: input)

        // 绑定数据到表格
        bindTableView(output: output, serverTypeChange: serverTypeChange, baseURLChange: baseURLChange, apiEndpointChange: apiEndpointChange)

        // 绑定加载状态
        output.isLoading
            .drive(loadingView.rx.isAnimating)
            .disposed(by: rx)

        output.isLoading
            .map { !$0 }
            .drive(tableView.rx.isUserInteractionEnabled)
            .disposed(by: rx)

        // 监听测试结果
        output.testResult
            .drive(onNext: { [weak self] result in
                guard let (success, error) = result else { return }
                self?.showTestResult(success: success, error: error)
            })
            .disposed(by: rx)

        // 监听 BaseURL 验证结果
        output.baseURLValidation
            .drive(onNext: { [weak self] error in
                self?.baseURLValidationError = error
                // 只在自定义服务器模式下刷新
                if self?.isCustomServer == true {
                    self?.tableView.reloadRows(at: [IndexPath(row: 0, section: Section.serverAddress.rawValue)], with: .none)
                }
            })
            .disposed(by: rx)
            
        // 监听 APIEndpoint 验证结果
        output.apiEndpointValidation
            .drive(onNext: { [weak self] error in
                self?.apiEndpointValidationError = error
                // 只在自定义服务器模式下刷新
                if self?.isCustomServer == true {
                    self?.tableView.reloadRows(at: [IndexPath(row: 0, section: Section.apiEndpoint.rawValue)], with: .none)
                }
            })
            .disposed(by: rx)

        // 监听保存成功
        output.saveSuccess
            .drive(onNext: { [weak self] (success: Bool) in
                if success {
                    self?.showSaveSuccess()
                }
            })
            .disposed(by: rx)

        // 监听重置成功
        output.resetSuccess
            .drive(onNext: { [weak self] (success: Bool) in
                if success {
                    self?.showResetSuccess()
                    self?.tableView.reloadData()
                }
            })
            .disposed(by: rx)

        // 监听服务器类型变化
        output.serverType
            .drive(onNext: { [weak self] type in
                self?.currentServerType = type
                self?.tableView.reloadData()
            })
            .disposed(by: rx)

        // 监听是否为自定义服务器
        output.isCustomServer
            .drive(onNext: { [weak self] isCustom in
                self?.isCustomServer = isCustom
                self?.tableView.reloadData()
            })
            .disposed(by: rx)
            
        // 监听 BaseURL 和 APIEndpoint 变化
        output.baseURL
            .drive(onNext: { [weak self] url in
                self?.currentBaseURL = url
            })
            .disposed(by: rx)
            
        output.apiEndpoint
            .drive(onNext: { [weak self] endpoint in
                self?.currentAPIEndpoint = endpoint
            })
            .disposed(by: rx)
            
        // 保存 relays
        self.serverTypeChange = serverTypeChange
        self.baseURLChange = baseURLChange
        self.apiEndpointChange = apiEndpointChange
    }

    // MARK: - Bind Table View

    private func bindTableView(output: ServerConfigViewModel.Output,
                               serverTypeChange: PublishRelay<String>,
                               baseURLChange: PublishRelay<String?>,
                               apiEndpointChange: PublishRelay<String?>) {
        // 使用传统的 delegate/datasource 方式
        tableView.dataSource = self
        tableView.delegate = self
    }

    // MARK: - Alert Methods

    private func showTestResult(success: Bool, error: String?) {
        let title = success ? "连接成功" : "连接失败"
        let message = success ? "服务器连接测试通过，配置有效。" : (error ?? "无法连接到服务器，请检查配置是否正确。")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func showSaveSuccess() {
        let alert = UIAlertController(title: "保存成功", message: "服务器配置已成功保存。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func showResetSuccess() {
        let alert = UIAlertController(title: "重置成功", message: "已恢复为默认服务器配置。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func showResetConfirmation() {
        let alert = UIAlertController(title: "确认重置", message: "确定要重置为默认服务器配置吗？当前自定义配置将丢失。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重置", style: .destructive) { [weak self] _ in
            // 发送重置动作
            self?.viewModel.resetConfig()
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension ServerConfigViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }

        switch sectionType {
        case .serverType, .serverAddress, .apiEndpoint:
            return 1
        case .actions:
            return 3 // Test, Save, Reset
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch sectionType {
        case .serverType:
            let cell = tableView.dequeueReusableCell(withIdentifier: SegmentedCell.identifier, for: indexPath) as! SegmentedCell
            let selectedIndex = currentServerType == "default" ? 0 : 1
            cell.configure(title: "选择服务器类型", selectedIndex: selectedIndex)
            cell.onSegmentChange = { [weak self] index in
                let type = index == 0 ? "default" : "custom"
                self?.serverTypeChange?.accept(type)
            }
            return cell

        case .serverAddress:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.identifier, for: indexPath) as! TextFieldCell
            cell.configure(
                title: "Base URL",
                placeholder: "https://api.example.com",
                text: currentBaseURL,
                enabled: isCustomServer,
                error: isCustomServer ? baseURLValidationError : nil
            )
            cell.onTextChange = { [weak self] text in
                self?.baseURLChange?.accept(text)
            }
            return cell

        case .apiEndpoint:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.identifier, for: indexPath) as! TextFieldCell
            cell.configure(
                title: "API Endpoint",
                placeholder: "/v1",
                text: currentAPIEndpoint,
                enabled: isCustomServer,
                error: isCustomServer ? apiEndpointValidationError : nil
            )
            cell.onTextChange = { [weak self] text in
                self?.apiEndpointChange?.accept(text)
            }
            return cell

        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: ButtonCell.identifier, for: indexPath) as! ButtonCell
            let buttonType: ButtonCell.ButtonType
            let title: String
            var enabled = true

            switch indexPath.row {
            case 0:
                buttonType = .test
                title = "测试当前配置"
            case 1:
                buttonType = .save
                title = "保存配置"
                enabled = isCustomServer || currentServerType == "default"
            case 2:
                buttonType = .reset
                title = "重置为默认"
                enabled = isCustomServer
            default:
                buttonType = .test
                title = ""
            }

            cell.configure(title: title, buttonType: buttonType, enabled: enabled)
            cell.onButtonTap = { [weak self] in
                self?.handleButtonAction(buttonType)
            }

            return cell
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        return sectionType.title
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - UITableViewDelegate

extension ServerConfigViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
}

// MARK: - Actions

extension ServerConfigViewController {

    private func handleButtonAction(_ type: ButtonCell.ButtonType) {
        view.endEditing(true)
        switch type {
        case .test:
            viewModel.testConnection()
        case .save:
            viewModel.saveConfig()
        case .reset:
            showResetConfirmation()
        }
    }
}
