//
//  TokenGenerateViewController.swift
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

/// 口令生成视图控制器
class TokenGenerateViewController: BaseViewController<TokenGenerateViewModel> {

    // MARK: - UI Components

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()

    private let contentView: UIView = {
        let view = UIView()
        return view
    }()

    // URL选择器
    private let urlSelectorLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.headline
        label.textColor = ThemeColors.current.text
        label.text = L10n.tr("token.generate.select_url")
        return label
    }()

    private lazy var urlPickerView: UIPickerView = {
        let picker = UIPickerView()
        picker.backgroundColor = ThemeColors.current.surface
        return picker
    }()

    // 时长选择器
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.headline
        label.textColor = ThemeColors.current.text
        label.text = L10n.tr("token.generate.duration")
        return label
    }()

    private lazy var durationSegmentedControl: UISegmentedControl = {
        let items = [
            L10n.tr("token.generate.duration_1d"),
            L10n.tr("token.generate.duration_7d"),
            L10n.tr("token.generate.duration_30d"),
            L10n.tr("token.generate.duration_permanent")
        ]
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 1
        return control
    }()

    // 生成按钮
    private lazy var generateButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("token.generate.button"), for: .normal)
        button.titleLabel?.font = ThemeTokens.Typography.headline
        button.backgroundColor = ThemeColors.current.primary
        button.setTitleColor(ThemeColors.current.surface, for: .normal)
        button.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        button.setTitleColor(ThemeColors.current.surface.withAlphaComponent(0.5), for: .disabled)
        return button
    }()

    // 结果卡片
    private let resultCardView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.xl
        view.isHidden = true
        return view
    }()

    private let resultTitleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.footnote
        label.textColor = ThemeColors.current.textSecondary
        label.text = L10n.tr("token.generate.result_title")
        label.numberOfLines = 1
        return label
    }()

    private let tokenLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 20, weight: .semibold)
        label.textColor = ThemeColors.current.text
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = ""
        return label
    }()

    private lazy var copyButton: UIButton = {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = LucideIcon.copy.templateImage()
            config.title = L10n.tr("common.copy")
            config.imagePadding = 4
            config.baseForegroundColor = ThemeColors.current.text
            let button = UIButton(configuration: config)
            button.titleLabel?.font = ThemeTokens.Typography.callout
            button.layer.cornerRadius = ThemeTokens.CornerRadius.md
            button.backgroundColor = ThemeColors.current.cardBackground
            return button
        } else {
            let button = UIButton(type: .system)
            button.setImage(LucideIcon.copy.templateImage(), for: .normal)
            button.setTitle(L10n.tr("common.copy"), for: .normal)
            button.titleLabel?.font = ThemeTokens.Typography.callout
            button.layer.cornerRadius = ThemeTokens.CornerRadius.md
            button.backgroundColor = ThemeColors.current.cardBackground
            button.tintColor = ThemeColors.current.text
            return button
        }
    }()

    private lazy var shareButton: UIButton = {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = LucideIcon.share.templateImage()
            config.title = L10n.tr("common.share")
            config.imagePadding = 4
            config.baseForegroundColor = ThemeColors.current.text
            let button = UIButton(configuration: config)
            button.titleLabel?.font = ThemeTokens.Typography.callout
            button.layer.cornerRadius = ThemeTokens.CornerRadius.md
            button.backgroundColor = ThemeColors.current.cardBackground
            return button
        } else {
            let button = UIButton(type: .system)
            button.setImage(LucideIcon.share.templateImage(), for: .normal)
            button.setTitle(L10n.tr("common.share"), for: .normal)
            button.titleLabel?.font = ThemeTokens.Typography.callout
            button.layer.cornerRadius = ThemeTokens.CornerRadius.md
            button.backgroundColor = ThemeColors.current.cardBackground
            button.tintColor = ThemeColors.current.text
            return button
        }
    }()

    private let buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = ThemeTokens.Spacing.md
        stackView.distribution = .fillEqually
        return stackView
    }()

    // 空状态视图
    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.isHidden = true
        return view
    }()

    // MARK: - Properties

    private var histories: [WebPageHistory] = []
    private var selectedURL: URL?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("token.generate.title")
        setupUI()
        setupPickerView()

        // Add accessibility identifiers for testing
        view.accessibilityIdentifier = "TokenGenerateViewController"
        urlPickerView.accessibilityIdentifier = "tokenGenerate.urlPickerView"
        urlPickerView.accessibilityLabel = L10n.tr("token.generate.select_url")
        durationSegmentedControl.accessibilityIdentifier = "tokenGenerate.durationSegmentedControl"
        durationSegmentedControl.accessibilityLabel = L10n.tr("token.generate.duration")
        generateButton.accessibilityIdentifier = "tokenGenerate.generateButton"
        generateButton.accessibilityLabel = L10n.tr("token.generate.button")
        copyButton.accessibilityIdentifier = "tokenGenerate.copyButton"
        copyButton.accessibilityLabel = L10n.tr("common.copy")
        shareButton.accessibilityIdentifier = "tokenGenerate.shareButton"
        shareButton.accessibilityLabel = L10n.tr("common.share")
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = ThemeColors.current.background

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(urlSelectorLabel)
        contentView.addSubview(urlPickerView)
        contentView.addSubview(durationLabel)
        contentView.addSubview(durationSegmentedControl)
        contentView.addSubview(generateButton)
        contentView.addSubview(resultCardView)
        resultCardView.addSubview(resultTitleLabel)
        resultCardView.addSubview(tokenLabel)
        resultCardView.addSubview(buttonStackView)
        buttonStackView.addArrangedSubview(copyButton)
        buttonStackView.addArrangedSubview(shareButton)
        view.addSubview(emptyStateView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        urlSelectorLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
        }

        urlPickerView.snp.makeConstraints { make in
            make.top.equalTo(urlSelectorLabel.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(120)
        }

        durationLabel.snp.makeConstraints { make in
            make.top.equalTo(urlPickerView.snp.bottom).offset(24)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
        }

        durationSegmentedControl.snp.makeConstraints { make in
            make.top.equalTo(durationLabel.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(32)
        }

        generateButton.snp.makeConstraints { make in
            make.top.equalTo(durationSegmentedControl.snp.bottom).offset(32)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(50)
        }

        resultCardView.snp.makeConstraints { make in
            make.top.equalTo(generateButton.snp.bottom).offset(24)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-24)
        }

        resultTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        tokenLabel.snp.makeConstraints { make in
            make.top.equalTo(resultTitleLabel.snp.bottom).offset(16)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        buttonStackView.snp.makeConstraints { make in
            make.top.equalTo(tokenLabel.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().offset(-16)
        }

        emptyStateView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 配置空状态
        emptyStateView.configure(
            icon: "link",
            title: L10n.tr("token.generate.empty_title"),
            description: L10n.tr("token.generate.empty_description"),
            actionTitle: nil
        )

        // 按钮样式
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
    }

    private func setupPickerView() {
        urlPickerView.dataSource = self
        urlPickerView.delegate = self
    }

    // MARK: - Bind ViewModel

    override func bindViewModel() {
        let selectedURL = urlPickerView.rx.itemSelected
            .map { [weak self] _ in self?.selectedURL }
            .asDriver(onErrorJustReturn: nil)

        let duration = durationSegmentedControl.rx.controlEvent(.valueChanged)
            .map { [weak self] _ -> Int in
                guard let self = self else { return 7 }
                switch self.durationSegmentedControl.selectedSegmentIndex {
                case 0: return 1      // 1天
                case 1: return 7      // 7天
                case 2: return 30     // 30天
                case 3: return -1     // 永久
                default: return 7
                }
            }
            .asDriver(onErrorJustReturn: 7)

        let generateTap = generateButton.rx.tap.asDriver()

        let copyTap = copyButton.rx.tap.asDriver()

        let shareTap = shareButton.rx.tap.asDriver()

        let input = TokenGenerateViewModel.Input(
            selectedURL: selectedURL,
            duration: duration,
            generateTap: generateTap,
            copyTap: copyTap,
            shareTap: shareTap
        )

        let output = viewModel.transform(input: input)

        // 绑定历史记录
        output.histories
            .drive(onNext: { [weak self] histories in
                self?.histories = histories
                self?.urlPickerView.reloadAllComponents()
                if !histories.isEmpty {
                    // 默认选中第一个
                    self?.selectedURL = URL(string: histories[0].url)
                }
            })
            .disposed(by: rx)

        // 绑定空状态
        output.isEmpty
            .drive(onNext: { [weak self] isEmpty in
                self?.emptyStateView.isHidden = !isEmpty
                self?.scrollView.isHidden = isEmpty
            })
            .disposed(by: rx)

        // 绑定生成的口令
        output.generatedToken
            .drive(onNext: { [weak self] token in
                guard let self = self, let token = token else { return }
                self.tokenLabel.text = token
                self.resultCardView.isHidden = false
                UIView.animate(withDuration: ThemeTokens.Animation.slow.duration) {
                    self.scrollView.layoutIfNeeded()
                }
            })
            .disposed(by: rx)

        // 绑定分享
        output.showShare
            .drive(onNext: { [weak self] token in
                guard let self = self, let token = token else { return }
                self.showShareSheet(token: token)
            })
            .disposed(by: rx)

        // 绑定复制成功
        output.copySuccess
            .drive(onNext: { [weak self] in
                self?.showCopySuccessToast()
            })
            .disposed(by: rx)

        // 绑定错误信息
        output.errorMessage
            .drive(onNext: { [weak self] message in
                guard let self = self, let message = message else { return }
                self.showErrorAlert(message: message)
            })
            .disposed(by: rx)
    }

    // MARK: - Actions

    @objc private func copyButtonTapped() {
        // 已通过 RxSwift 绑定处理
    }

    @objc private func shareButtonTapped() {
        // 已通过 RxSwift 绑定处理
    }

    // MARK: - Private Methods

    private func showCopySuccessToast() {
        let alert = UIAlertController(
            title: L10n.tr("token.generate.copied_title"),
            message: L10n.tr("token.generate.copied_message"),
            preferredStyle: .alert
        )
        present(alert, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }

    private func showShareSheet(token: String) {
        let text = L10n.tr("token.generate.share_text", token)

        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = CGRect(
                x: view.bounds.midX,
                y: view.bounds.midY,
                width: 0,
                height: 0
            )
            popoverController.permittedArrowDirections = []
        }

        present(activityVC, animated: true)
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: L10n.tr("common.notice"),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIPickerViewDataSource

extension TokenGenerateViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return max(histories.count, 1)  // 至少显示1行
    }
}

// MARK: - UIPickerViewDelegate

extension TokenGenerateViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if histories.isEmpty {
            return L10n.tr("token.generate.empty_title")
        }

        let history = histories[row]
        if let title = history.title, !title.isEmpty {
            return title
        } else {
            return history.url
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard row < histories.count else { return }
        if let url = URL(string: histories[row].url) {
            selectedURL = url
        }
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.font = ThemeTokens.Typography.callout
        label.textAlignment = .center

        if histories.isEmpty {
            label.text = L10n.tr("token.generate.empty_title")
            label.textColor = ThemeColors.current.textSecondary
        } else {
            let history = histories[row]
            if let title = history.title, !title.isEmpty {
                label.text = title
            } else {
                label.text = history.url
            }
            label.textColor = ThemeColors.current.text
        }

        return label
    }
}
