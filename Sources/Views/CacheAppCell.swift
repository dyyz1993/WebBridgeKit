//
//  CacheAppCell.swift
//  SuperApp
//
//  Created by Claude on 2025-02-04.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit

/// 缓存应用列表单元格
/// 改进版：更明显的 AppID 显示，复制按钮，卡片式布局
public class CacheAppCell: UITableViewCell {

    public static let identifier = "CacheAppCell"

    // MARK: - UI Components

    /// 卡片容器
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.surface
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = false
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        return view
    }()

    /// 应用图标
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = ThemeTokens.Color.primary
        imageView.backgroundColor = ThemeTokens.Color.surface
        imageView.layer.cornerRadius = 12
        imageView.layer.masksToBounds = true
        imageView.clipsToBounds = true
        return imageView
    }()

    /// AppID 标签（主要信息，大字体）
    private let appIDLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 17, weight: .semibold)
        label.textColor = ThemeTokens.Color.text
        label.numberOfLines = 1
        return label
    }()

    /// 应用名称（次要信息）
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = ThemeTokens.Color.textSecondary
        label.numberOfLines = 1
        return label
    }()

    /// 版本标签
    private let versionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = ThemeTokens.Color.primary
        label.numberOfLines = 1
        return label
    }()

    /// 页面数量标签
    private let pageCountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = ThemeTokens.Color.gradientEnd
        label.numberOfLines = 1
        return label
    }()

    /// 缓存大小标签
    private let cacheSizeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        label.textColor = ThemeTokens.Color.warning
        label.numberOfLines = 1
        return label
    }()

    /// 复制 AppID 按钮
    private lazy var copyButton: UIButton = {
        let button = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: "doc.on.doc")
            config.imagePlacement = .leading
            config.imagePadding = 4
            config.title = "复制"
            config.baseForegroundColor = ThemeTokens.Color.primary
            button.configuration = config
        } else {
            button.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
            button.setTitle("复制", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            button.tintColor = ThemeTokens.Color.primary
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
            button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        }
        return button
    }()

    /// 删除按钮（更大更明显）
    private lazy var deleteButton: UIButton = {
        let button = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: "trash.fill")
            config.imagePlacement = .all
            config.baseForegroundColor = ThemeTokens.Color.error
            config.baseBackgroundColor = ThemeTokens.Color.error.withAlphaComponent(0.1)
            config.cornerStyle = .capsule
            button.configuration = config
            button.configurationUpdateHandler = { btn in
                var config = btn.configuration
                config?.imagePadding = 8
                btn.configuration = config
            }
        } else {
            button.setImage(UIImage(systemName: "trash.fill"), for: .normal)
            button.tintColor = ThemeTokens.Color.error
            button.backgroundColor = ThemeTokens.Color.error.withAlphaComponent(0.1)
            button.layer.cornerRadius = 22
            button.layer.masksToBounds = true
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        }
        return button
    }()

    /// AppID 背景高亮（更容易识别）
    private let appIDBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.primary.withAlphaComponent(0.08)
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        return view
    }()

    /// 顶部信息容器
    private let topInfoStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()

    /// 底部信息容器
    private let bottomInfoStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        return stack
    }()

    /// 右侧按钮容器
    private let rightButtonStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.distribution = .fill
        return stack
    }()

    // MARK: - Properties

    private var currentAppInfo: CacheAppInfo?

    public var appInfo: CacheAppInfo? {
        didSet {
            currentAppInfo = appInfo
            updateUI()
        }
    }

    public var onDelete: ((String) -> Void)?
    public var onCopy: ((String) -> Void)?
    public var onTap: ((CacheAppInfo) -> Void)?

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupGestures()
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
        containerView.addSubview(appIDBackgroundView)
        containerView.addSubview(topInfoStackView)
        containerView.addSubview(bottomInfoStackView)
        containerView.addSubview(rightButtonStackView)

        // 设置 AppID 背景
        appIDBackgroundView.addSubview(appIDLabel)

        // 添加顶部信息元素
        topInfoStackView.addArrangedSubview(appIDBackgroundView)
        topInfoStackView.addArrangedSubview(nameLabel)

        // 添加底部信息元素
        bottomInfoStackView.addArrangedSubview(versionLabel)
        bottomInfoStackView.addArrangedSubview(pageCountLabel)
        bottomInfoStackView.addArrangedSubview(cacheSizeLabel)

        // 添加右侧按钮
        rightButtonStackView.addArrangedSubview(deleteButton)
        rightButtonStackView.addArrangedSubview(copyButton)

        // 布局
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-8)
        }

        appIDBackgroundView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(32)
        }

        appIDLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10))
        }

        rightButtonStackView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(60)
        }

        deleteButton.snp.makeConstraints { make in
            make.height.equalTo(44)
        }

        copyButton.snp.makeConstraints { make in
            make.height.equalTo(32)
        }

        containerView.addSubview(iconImageView)

        // iconImageView 布局（在添加到父视图后设置约束）
        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(64)
        }

        // 现在可以安全地设置引用 iconImageView 的约束
        topInfoStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalTo(iconImageView.snp.right).offset(16)
            make.right.equalTo(rightButtonStackView.snp.left).offset(-12)
        }

        bottomInfoStackView.snp.makeConstraints { make in
            make.top.equalTo(topInfoStackView.snp.bottom).offset(8)
            make.left.equalTo(iconImageView.snp.right).offset(16)
            make.right.equalTo(rightButtonStackView.snp.left).offset(-12)
            make.bottom.lessThanOrEqualToSuperview().offset(-16)
        }

        // 按钮事件
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
    }

    private func setupGestures() {
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cellTapped))
        tapGesture.cancelsTouchesInView = false
        contentView.addGestureRecognizer(tapGesture)
    }

    // MARK: - Update UI

    private func updateUI() {
        guard let appInfo = currentAppInfo else {
            appIDLabel.text = ""
            nameLabel.text = ""
            versionLabel.text = ""
            pageCountLabel.text = ""
            cacheSizeLabel.text = ""
            iconImageView.image = nil
            return
        }

        // AppID 作为主要信息
        appIDLabel.text = appInfo.appID

        // 名称作为次要信息
        nameLabel.text = appInfo.name ?? "未命名应用"

        // 版本
        versionLabel.text = "v\(appInfo.version)"

        // 页面数量
        let pageCount = appInfo.pageKeys.count
        pageCountLabel.text = "\(pageCount) 个页面"

        // 缓存大小
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        cacheSizeLabel.text = formatter.string(fromByteCount: appInfo.cacheSize)

        // 设置图标
        if let icon = appInfo.icon, let image = UIImage(data: icon) {
            iconImageView.image = image
            iconImageView.backgroundColor = .clear
        } else {
            // 使用 AppIconGenerator 生成图标
            if let generatedIcon = AppIconGenerator.generateIcon(from: appInfo.name, size: CGSize(width: 64, height: 64)) {
                iconImageView.image = generatedIcon
                iconImageView.backgroundColor = .clear
            } else {
                iconImageView.image = nil
                iconImageView.backgroundColor = ThemeTokens.Color.primary.withAlphaComponent(0.1)
            }
        }

        // 根据页面数量调整 AppID 背景颜色
        if pageCount > 5 {
            appIDBackgroundView.backgroundColor = ThemeTokens.Color.gradientEnd.withAlphaComponent(0.1)
        } else if pageCount > 1 {
            appIDBackgroundView.backgroundColor = ThemeTokens.Color.primary.withAlphaComponent(0.08)
        } else {
            appIDBackgroundView.backgroundColor = ThemeTokens.Color.surface.withAlphaComponent(0.5)
        }
    }

    // MARK: - Actions

    @objc private func deleteButtonTapped() {
        guard let appInfo = currentAppInfo else { return }
        onDelete?(appInfo.appID)
    }

    @objc private func copyButtonTapped() {
        guard let appInfo = currentAppInfo else { return }
        onCopy?(appInfo.appID)

        // 复制到剪贴板
        UIPasteboard.general.string = appInfo.appID

        // 显示反馈动画
        showCopyFeedback()
    }

    @objc private func cellTapped() {
        guard let appInfo = currentAppInfo else { return }
        onTap?(appInfo)
    }

    private func showCopyFeedback() {
        // 复制按钮动画反馈
        UIView.animate(withDuration: 0.1, animations: {
            self.copyButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.copyButton.transform = .identity
            }
        })

        // 临时改变按钮文字（iOS 15+）
        if #available(iOS 15.0, *) {
            let originalConfig = copyButton.configuration
            var newConfig = originalConfig
            newConfig?.title = "已复制"
            newConfig?.baseForegroundColor = ThemeTokens.Color.success
            copyButton.configuration = newConfig

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.copyButton.configuration = originalConfig
            }
        }
    }

    // MARK: - Reuse

    public override func prepareForReuse() {
        super.prepareForReuse()
        currentAppInfo = nil
        iconImageView.image = nil
        onDelete = nil
        onCopy = nil
        onTap = nil
        appIDLabel.text = nil
        nameLabel.text = nil
        versionLabel.text = nil
        pageCountLabel.text = nil
        cacheSizeLabel.text = nil
        iconImageView.backgroundColor = ThemeTokens.Color.surface
        appIDBackgroundView.backgroundColor = ThemeTokens.Color.primary.withAlphaComponent(0.08)
    }
}

// MARK: - Cache App Info Model

/// 缓存应用信息
public struct CacheAppInfo {
    public let appID: String
    public let name: String?
    public let version: String
    public let cacheSize: Int64
    public let icon: Data?
    public let pageKeys: [String]

    public init(appID: String, name: String?, version: String, cacheSize: Int64, icon: Data?, pageKeys: [String]) {
        self.appID = appID
        self.name = name
        self.version = version
        self.cacheSize = cacheSize
        self.icon = icon
        self.pageKeys = pageKeys
    }
}
