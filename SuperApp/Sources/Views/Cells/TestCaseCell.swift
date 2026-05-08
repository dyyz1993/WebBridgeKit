//
//  TestCaseCell.swift
//  SuperApp
//
//  Created by Claude on 2025-02-04.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebBridgeKit

/// 测试用例列表单元格
class TestCaseCell: UITableViewCell {

    static let identifier = "TestCaseCell"

    // MARK: - UI Components

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        view.layer.masksToBounds = true
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = LucideIcon.docTextFill.image(pointSize: 24)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = ThemeColors.current.primary
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = UIColor.label
        label.numberOfLines = 1
        label.accessibilityIdentifier = "testCaseCell.titleLabel"
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 2
        return label
    }()

    private let statusBadge: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        view.clipsToBounds = true
        return view
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.text = "待运行"
        return label
    }()

    private let runButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("运行", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        button.tintColor = ThemeColors.current.primary
        button.backgroundColor = ThemeColors.current.primary.withAlphaComponent(0.1)
        button.layer.cornerRadius = ThemeTokens.CornerRadius.md
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        button.accessibilityIdentifier = "testCaseCell.runButton"
        return button
    }()

    // MARK: - Properties

    private var currentTestCase: ManifestTestCase?

    var testCase: ManifestTestCase? {
        didSet {
            currentTestCase = testCase
            updateUI()
        }
    }

    var onRun: (() -> Void)?

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        contentView.backgroundColor = .clear
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(statusBadge)
        statusBadge.addSubview(statusLabel)
        containerView.addSubview(runButton)

        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-8)
        }

        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }

        runButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.height.equalTo(32)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.right.equalTo(runButton.snp.left).offset(-8)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.right.equalTo(runButton.snp.left).offset(-8)
        }

        statusBadge.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(6)
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.bottom.lessThanOrEqualToSuperview().offset(-12)
        }

        statusLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        }

        runButton.addTarget(self, action: #selector(runButtonTapped), for: .touchUpInside)
    }

    // MARK: - Update UI

    private func updateUI() {
        guard let testCase = currentTestCase else {
            titleLabel.text = ""
            descriptionLabel.text = ""
            statusLabel.text = "待运行"
            statusBadge.backgroundColor = UIColor.systemGray5
            statusLabel.textColor = UIColor.secondaryLabel
            return
        }

        titleLabel.text = testCase.name
        descriptionLabel.text = testCase.description

        // 根据状态更新 UI
        switch testCase.status {
        case .pending:
            statusLabel.text = "待运行"
            statusBadge.backgroundColor = UIColor.systemGray5
            statusLabel.textColor = UIColor.secondaryLabel
        case .running:
            statusLabel.text = "运行中..."
            statusBadge.backgroundColor = ThemeTokens.Colors.Light.primary.withAlphaComponent(0.1)
            statusLabel.textColor = ThemeTokens.Colors.Light.primary
        case .success:
            statusLabel.text = "成功"
            statusBadge.backgroundColor = ThemeTokens.Colors.Light.success.withAlphaComponent(0.1)
            statusLabel.textColor = ThemeTokens.Colors.Light.success
        case .failure:
            statusLabel.text = "失败"
            statusBadge.backgroundColor = ThemeTokens.Colors.Light.error.withAlphaComponent(0.1)
            statusLabel.textColor = ThemeTokens.Colors.Light.error
        }
    }

    // MARK: - Actions

    @objc private func runButtonTapped() {
        onRun?()
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        currentTestCase = nil
        onRun = nil
        titleLabel.text = nil
        descriptionLabel.text = nil
        statusLabel.text = "待运行"
        statusBadge.backgroundColor = UIColor.systemGray5
        statusLabel.textColor = UIColor.secondaryLabel
    }
}

// MARK: - Test Case Model

/// Manifest 测试用例
class ManifestTestCase {
    enum Status {
        case pending
        case running
        case success
        case failure
    }

    let id: String
    let name: String
    let description: String
    let manifestFileName: String
    let manifestURL: URL
    var status: Status
    var result: TestResult?

    init(
        id: String,
        name: String,
        description: String,
        manifestFileName: String,
        manifestURL: URL,
        status: Status = .pending,
        result: TestResult? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.manifestFileName = manifestFileName
        self.manifestURL = manifestURL
        self.status = status
        self.result = result
    }
}

/// 测试结果
struct TestResult {
    let success: Bool
    let duration: TimeInterval
    let cacheSize: Int64
    let logFileURL: URL
    let error: Error?
}
