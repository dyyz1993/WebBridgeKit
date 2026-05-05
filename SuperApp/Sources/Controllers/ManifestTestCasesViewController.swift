//
//  ManifestTestCasesViewController.swift
//  SuperApp
//
//  Created by Claude on 2025-02-04.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import QuickLook
import SVProgressHUD
import WebBridgeKit

/// Manifest 测试用例页面
/// 展示所有测试用例，支持运行测试和查看日志
class ManifestTestCasesViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: ManifestTestCasesViewModel
    private let disposeBag = DisposeBag()
    private let previewController = QLPreviewController()

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .systemGroupedBackground
        table.separatorStyle = .none
        table.register(TestCaseCell.self, forCellReuseIdentifier: TestCaseCell.identifier)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 100
        table.accessibilityIdentifier = "ManifestTestCasesTableView" // 添加 ID 方便测试定位
        return table
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.tintColor = .systemBlue
        return control
    }()

    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.configure(
            icon: "doc.text.below.ecg",
            title: "暂无测试用例",
            description: "请添加测试用例到 test_resources 目录",
            actionTitle: nil
        )
        return view
    }()

    private lazy var headerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 80))
        view.backgroundColor = .clear

        let infoLabel = UILabel()
        infoLabel.font = .systemFont(ofSize: 14, weight: .regular)
        infoLabel.textColor = .secondaryLabel
        infoLabel.text = "点击运行按钮执行测试，测试结果会记录到日志文件"
        infoLabel.textAlignment = .center
        infoLabel.numberOfLines = 0

        view.addSubview(infoLabel)
        infoLabel.snp.makeConstraints { make in
            make.center.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20))
        }

        return view
    }()

    // MARK: - Initialization

    init(viewModel: ManifestTestCasesViewModel = ManifestTestCasesViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "测试用例"
        view.backgroundColor = .systemGroupedBackground

        // 添加导航栏按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "运行全部",
            style: .plain,
            target: self,
            action: #selector(runAllTests)
        )

        // 设置代理
        tableView.dataSource = self
        tableView.delegate = self

        // 添加子视图
        view.addSubview(tableView)
        view.addSubview(emptyStateView)

        tableView.addSubview(refreshControl)

        // 布局
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualTo(300)
        }

        tableView.tableHeaderView = headerView
    }

    private func bindViewModel() {
        let input = ManifestTestCasesViewModel.Input(
            refresh: refreshControl.rx.controlEvent(.valueChanged).asDriver(),
            runTest: runTestSubject.asDriver(onErrorJustReturn: (0, self)),
            viewLogs: viewLogsSubject.asDriver(onErrorJustReturn: 0)
        )

        let output = viewModel.transform(input: input)

        // 绑定数据
        output.testCases
            .drive(onNext: { [weak self] _ in
                self?.tableView.reloadData()
            })
            .disposed(by: disposeBag)

        // 绑定空状态
        output.isEmpty
            .drive(onNext: { [weak self] isEmpty in
                self?.tableView.isHidden = isEmpty
                self?.emptyStateView.isHidden = !isEmpty
            })
            .disposed(by: disposeBag)

        // 绑定加载状态
        output.loading
            .drive(onNext: { isLoading in
                if isLoading {
                    SVProgressHUD.show()
                } else {
                    SVProgressHUD.dismiss()
                }
            })
            .disposed(by: disposeBag)

        // 绑定测试运行状态
        output.testRunning
            .drive(onNext: { [weak self] isRunning in
                if isRunning {
                    self?.navigationItem.rightBarButtonItem?.isEnabled = false
                    SVProgressHUD.showInfo(withStatus: "测试运行中...")
                } else {
                    self?.navigationItem.rightBarButtonItem?.isEnabled = true
                    SVProgressHUD.dismiss()
                }
            })
            .disposed(by: disposeBag)

        // 查看日志
        output.logFileURL
            .drive(onNext: { [weak self] url in
                self?.showLogFile(url: url)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Actions

    private let runTestSubject = PublishRelay<(Int, UIViewController)>()
    private let viewLogsSubject = PublishRelay<Int>()

    @objc func runAllTests() {
        runTestsSequentially()
    }

    private func runTestsSequentially() {
        // 获取测试用例数量
        let testCases = viewModel.testCases.value

        guard !testCases.isEmpty else { return }

        // 依次运行测试
        for index in 0..<testCases.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 2) { [weak self] in
                guard let self = self else { return }
                self.runTestSubject.accept((index, self))
            }
        }
    }

    private func showLogFile(url: URL) {
        previewController.dataSource = self
        previewController.currentPreviewItemIndex = 0

        // 临时存储日志文件 URL
        logFileURL = url

        present(previewController, animated: true)
    }

    private var logFileURL: URL?
}

// MARK: - UITableViewDataSource

extension ManifestTestCasesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.testCases.value.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: TestCaseCell.identifier,
            for: indexPath
        ) as? TestCaseCell else {
            return UITableViewCell()
        }

        let testCase = viewModel.testCases.value[indexPath.row]
        cell.testCase = testCase
        cell.onRun = { [weak self] in
            guard let self = self else { return }
            self.runTestSubject.accept((indexPath.row, self))
        }

        return cell
    }
}

// MARK: - UITableViewDelegate

extension ManifestTestCasesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let testCase = viewModel.testCases.value[indexPath.row]

        // 如果测试已完成，显示日志
        if testCase.result != nil {
            viewLogsSubject.accept(indexPath.row)
        }
    }
}

// MARK: - QLPreviewControllerDataSource

extension ManifestTestCasesViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in previewController: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ previewController: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return logFileURL! as QLPreviewItem
    }
}

import WebKit

class TestWebViewController: UIViewController {
    let webView: WKWebView
    let debugLabel = UILabel()

    init(configuration: WKWebViewConfiguration) {
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        webView.accessibilityIdentifier = "TestWebView"
        webView.backgroundColor = .blue // 设置背景色以便调试
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        debugLabel.textColor = .white
        debugLabel.backgroundColor = .black.withAlphaComponent(0.7) // 更深背景，对比度更高
        debugLabel.accessibilityIdentifier = "DebugLabel"
        debugLabel.numberOfLines = 0
        debugLabel.font = .boldSystemFont(ofSize: 12) // 加粗并稍微变大
        debugLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(debugLabel)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // 将 DebugLabel 放在底部中央，更容易观察
            debugLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            debugLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            debugLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            debugLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])

        view.bringSubviewToFront(debugLabel)

        NotificationCenter.default.addObserver(forName: .updateDebugLabel, object: nil, queue: .main) { [weak self] notification in
            if let text = notification.userInfo?["text"] as? String {
                NSLog("📱 [TestVC] Received Notification: UpdateDebugLabel with text: %@", text)

                let currentText = self?.debugLabel.text ?? ""
                let newText = currentText.isEmpty ? text : currentText + "\n" + text
                self?.debugLabel.text = newText

                // 强制刷新布局以确保 UI 更新
                self?.view.layoutIfNeeded()

                // 打印当前标签内容以便调试
                NSLog("📱 [TestVC] DebugLabel content is now: %@", self?.debugLabel.text ?? "nil")
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
