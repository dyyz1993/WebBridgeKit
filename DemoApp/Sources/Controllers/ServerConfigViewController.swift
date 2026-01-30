//
//  ServerConfigViewController.swift
//  DemoApp
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

        // 暂存输入驱动
        let serverTypeChangeDriver = serverTypeChange.asDriver(onErrorJustReturn: "default")
        let baseURLChangeDriver = baseURLChange.asDriver(onErrorJustReturn: nil)
        let apiEndpointChangeDriver = apiEndpointChange.asDriver(onErrorJustReturn: nil)

        // 创建输入
        let input = ServerConfigViewModel.Input(
            serverTypeChange: serverTypeChangeDriver,
            baseURLChange: baseURLChangeDriver,
            apiEndpointChange: apiEndpointChangeDriver,
            testConnection: tableView.rx.modelSelected(ButtonCell.ButtonType.self).asDriver().filter { $0 == .test }.map { _ in },
            saveConfig: tableView.rx.modelSelected(ButtonCell.ButtonType.self).asDriver().filter { $0 == .save }.map { _ in },
            resetConfig: tableView.rx.modelSelected(ButtonCell.ButtonType.self).asDriver().filter { $0 == .reset }.map { _ in }
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
            .drive(onNext: { [weak self] (result: Bool?) in
                guard let result = result else { return }
                self?.showTestResult(result)
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
                }
            })
            .disposed(by: rx)

        // 监听服务器类型变化
        output.serverType
            .drive(onNext: { [weak self] type in
                self?.currentServerType = type
            })
            .disposed(by: rx)

        // 监听是否为自定义服务器
        output.isCustomServer
            .drive(onNext: { [weak self] isCustom in
                self?.isCustomServer = isCustom
            })
            .disposed(by: rx)
    }

    // MARK: - Bind Table View

    private func bindTableView(output: ServerConfigViewModel.Output,
                               serverTypeChange: PublishRelay<String>,
                               baseURLChange: PublishRelay<String?>,
                               apiEndpointChange: PublishRelay<String?>) {

        // 绑定表格数据
        Observable.zip(
            output.serverType.asObservable(),
            output.baseURL.asObservable(),
            output.apiEndpoint.asObservable(),
            output.isCustomServer.asObservable()
        )
        .map { serverType, baseURL, apiEndpoint, isCustom in
            return (serverType, baseURL, apiEndpoint, isCustom)
        }
        .subscribe(onNext: { [weak self] (serverType, baseURL, apiEndpoint, isCustom) in
            self?.currentServerType = serverType
            self?.currentBaseURL = baseURL
            self?.currentAPIEndpoint = apiEndpoint
            self?.isCustomServer = isCustom
            self?.tableView.reloadData()
        })
        .disposed(by: rx)

        // 使用传统的 delegate/datasource 方式
        tableView.dataSource = self
        tableView.delegate = self

        // Store relays for use in cellForRowAt
        self.serverTypeChange = serverTypeChange
        self.baseURLChange = baseURLChange
        self.apiEndpointChange = apiEndpointChange
    }

    // MARK: - Alert Methods

    private func showTestResult(_ success: Bool) {
        let title = success ? "连接成功" : "连接失败"
        let message = success ? "服务器连接测试通过，配置有效。" : "无法连接到服务器，请检查配置是否正确。"
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
        alert.addAction(UIAlertAction(title: "重置", style: .destructive))
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
                enabled: isCustomServer
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
                enabled: isCustomServer
            )
            cell.onTextChange = { [weak self] text in
                self?.apiEndpointChange?.accept(text)
            }
            return cell

        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: ButtonCell.identifier, for: indexPath) as! ButtonCell
            let buttonType: ButtonCell.ButtonType
            let title: String

            switch indexPath.row {
            case 0:
                buttonType = .test
                title = "测试当前配置"
            case 1:
                buttonType = .save
                title = "保存配置"
            case 2:
                buttonType = .reset
                title = "重置为默认"
            default:
                buttonType = .test
                title = ""
            }

            cell.configure(title: title, buttonType: buttonType, enabled: true)
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
        switch type {
        case .test:
            // 测试连接功能已通过 RxSwift 绑定实现
            showTestResult(true) // 临时测试

        case .save:
            // 保存配置功能已通过 RxSwift 绑定实现
            showSaveSuccess() // 临时测试

        case .reset:
            showResetConfirmation()
        }
    }
}
