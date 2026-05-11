//
//  CacheAppDetailViewController.swift
//  SuperApp
//
//  Created by Claude on 2025-02-04.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa


/// 缓存应用详情页面
/// 显示特定 AppID 下的所有缓存页面
public class CacheAppDetailViewController: UIViewController {

    // MARK: - Properties

    private let appInfo: CacheAppInfo
    private let disposeBag = DisposeBag()

    public var onDeletePage: ((String) -> Void)?

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.backgroundColor = ThemeTokens.Color.background
        table.register(CachePageCell.self, forCellReuseIdentifier: CachePageCell.identifier)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 60
        return table
    }()

    private lazy var headerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 200))
        view.backgroundColor = .clear

        let container = UIView()
        container.backgroundColor = ThemeTokens.Color.surface
        container.layer.cornerRadius = ThemeTokens.CornerRadius.xl
        container.layer.masksToBounds = false
        let shadow = ThemeTokens.Shadows.Card
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = Float(shadow.opacity)
        container.layer.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
        container.layer.shadowRadius = shadow.radius

        let iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        iconImageView.layer.masksToBounds = true
        iconImageView.clipsToBounds = true
        iconImageView.tag = 100

        let appIDLabel = UILabel()
        appIDLabel.font = UIFont.monospacedSystemFont(ofSize: 18, weight: .bold)
        appIDLabel.textColor = ThemeTokens.Color.text
        appIDLabel.numberOfLines = 0
        appIDLabel.textAlignment = .center
        appIDLabel.tag = 101

        let nameLabel = UILabel()
        nameLabel.font = ThemeTokens.Typography.callout
        nameLabel.textColor = ThemeTokens.Color.textSecondary
        nameLabel.numberOfLines = 1
        nameLabel.textAlignment = .center
        nameLabel.tag = 102

        let infoLabel = UILabel()
        infoLabel.font = ThemeTokens.Typography.footnote
        infoLabel.textColor = ThemeTokens.Color.textTertiary
        infoLabel.numberOfLines = 0
        infoLabel.textAlignment = .center
        infoLabel.tag = 103

        let stackView = UIStackView(arrangedSubviews: [iconImageView, appIDLabel, nameLabel, infoLabel])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .center

        container.addSubview(stackView)
        view.addSubview(container)

        container.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-16)
        }

        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.greaterThanOrEqualToSuperview().offset(20)
            make.right.lessThanOrEqualToSuperview().offset(-20)
        }

        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(80)
        }

        return view
    }()

    // MARK: - Initialization

    public init(appInfo: CacheAppInfo) {
        self.appInfo = appInfo
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureHeaderView()
        bindTableView()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "缓存详情"
        view.backgroundColor = ThemeTokens.Color.background

        // 添加返回按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )

        // 添加清除全部按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "清除全部",
            style: .plain,
            target: self,
            action: #selector(clearAllTapped)
        )

        view.addSubview(tableView)
        tableView.tableHeaderView = headerView

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func configureHeaderView() {
        guard let iconImageView = headerView.viewWithTag(100) as? UIImageView,
              let appIDLabel = headerView.viewWithTag(101) as? UILabel,
              let nameLabel = headerView.viewWithTag(102) as? UILabel,
              let infoLabel = headerView.viewWithTag(103) as? UILabel else {
            return
        }

        appIDLabel.text = appInfo.appID
        nameLabel.text = appInfo.name ?? "未命名应用"

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        let sizeString = formatter.string(fromByteCount: appInfo.cacheSize)

        infoLabel.text = "v\(appInfo.version) • \(appInfo.pageKeys.count) 个页面 • \(sizeString)"

        if let icon = appInfo.icon, let image = UIImage(data: icon) {
            iconImageView.image = image
        } else if let generatedIcon = AppIconGenerator.generateIcon(from: appInfo.name, size: CGSize(width: 80, height: 80)) {
            iconImageView.image = generatedIcon
        } else {
            iconImageView.backgroundColor = ThemeTokens.Color.primary.withAlphaComponent(0.1)
        }
    }

    private func bindTableView() {
        let pageKeys = appInfo.pageKeys

        Observable.just(pageKeys)
            .bind(to: tableView.rx.items(cellIdentifier: CachePageCell.identifier, cellType: CachePageCell.self)) { [weak self] index, pageKey, cell in
                cell.pageKey = pageKey
                cell.index = index + 1
                cell.onCopy = { pageKey in
                    UIPasteboard.general.string = pageKey
                    HUDService.shared.showSuccess(withStatus: "页面 Key 已复制")
                    HUDService.shared.dismiss(withDelay: 1.5)
                }
                cell.onDelete = { [weak self] pageKey in
                    self?.onDeletePage?(pageKey)
                }
            }
            .disposed(by: disposeBag)
    }

    // MARK: - Actions

    @objc private func doneTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func clearAllTapped() {
        let alert = UIAlertController(
            title: "确认清除",
            message: "确定要删除此应用的所有缓存吗？这将删除 \(appInfo.pageKeys.count) 个页面的缓存。",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            // 逐个删除所有页面
            for pageKey in self?.appInfo.pageKeys ?? [] {
                ManifestCacheManager.shared.removeCache(for: pageKey)
            }

            HUDService.shared.showSuccess(withStatus: "所有缓存已删除")
            HUDService.shared.dismiss(withDelay: 1.5)

            // 返回上一页
            self?.navigationController?.popViewController(animated: true)
        })

        present(alert, animated: true)
    }
}

// MARK: - Cache Page Cell

/// 缓存页面列表单元格
public class CachePageCell: UITableViewCell {

    public static let identifier = "CachePageCell"

    // MARK: - UI Components

    private let indexLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 20, weight: .bold)
        label.textColor = ThemeTokens.Color.primary
        label.textAlignment = .center
        label.widthAnchor.constraint(equalToConstant: 40).isActive = true
        return label
    }()

    private let pageKeyLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        label.textColor = ThemeTokens.Color.text
        label.numberOfLines = 2
        return label
    }()

    private lazy var copyButton: UIButton = {
        let button = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = LucideIcon.copy.templateImage()
            config.baseForegroundColor = ThemeTokens.Color.primary
            button.configuration = config
        } else {
            button.setImage(LucideIcon.copy.templateImage(), for: .normal)
            button.tintColor = ThemeTokens.Color.primary
        }
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }()

    private lazy var deleteButton: UIButton = {
        let button = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = LucideIcon.trash.templateImage()
            config.baseForegroundColor = ThemeTokens.Color.error
            button.configuration = config
        } else {
            button.setImage(LucideIcon.trash.templateImage(), for: .normal)
            button.tintColor = ThemeTokens.Color.error
        }
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }()

    private let buttonStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = ThemeTokens.Spacing.sm
        return stack
    }()

    // MARK: - Properties

    private var currentPageKey: String?

    public var pageKey: String? {
        didSet {
            currentPageKey = pageKey
            updateUI()
        }
    }

    public var index: Int = 0 {
        didSet {
            indexLabel.text = "\(index)."
        }
    }

    public var onCopy: ((String) -> Void)?
    public var onDelete: ((String) -> Void)?

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

        buttonStackView.addArrangedSubview(copyButton)
        buttonStackView.addArrangedSubview(deleteButton)

        let stackView = UIStackView(arrangedSubviews: [indexLabel, pageKeyLabel, buttonStackView])
        stackView.axis = .horizontal
        stackView.spacing = ThemeTokens.Spacing.md
        stackView.alignment = .center

        contentView.addSubview(stackView)

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
        }

        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
    }

    private func updateUI() {
        pageKeyLabel.text = currentPageKey ?? "未知页面"
    }

    // MARK: - Actions

    @objc private func copyButtonTapped() {
        guard let pageKey = currentPageKey else { return }
        onCopy?(pageKey)
    }

    @objc private func deleteButtonTapped() {
        guard let pageKey = currentPageKey else { return }
        onDelete?(pageKey)
    }

    // MARK: - Reuse

    public override func prepareForReuse() {
        super.prepareForReuse()
        currentPageKey = nil
        pageKeyLabel.text = nil
        indexLabel.text = nil
        onCopy = nil
        onDelete = nil
    }
}
