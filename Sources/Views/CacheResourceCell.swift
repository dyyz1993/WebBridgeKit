//
//  CacheResourceCell.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit

/// 缓存资源单元格
public class CacheResourceCell: UITableViewCell {

    public static let identifier = "CacheResourceCell"

    // MARK: - UI Components

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        view.layer.masksToBounds = true
        return view
    }()

    private let typeIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemBlue
        return imageView
    }()

    private let typeIconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiarySystemBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.md
        view.layer.masksToBounds = true
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.subheadline
        label.textColor = UIColor.label
        label.numberOfLines = 2
        return label
    }()

    private let sizeLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.footnote
        label.textColor = UIColor.secondaryLabel
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.caption1
        label.textColor = UIColor.tertiaryLabel
        return label
    }()

    private let typeBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        view.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        view.layer.masksToBounds = true
        return view
    }()

    private let typeBadgeLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.caption2
        label.textColor = UIColor.systemBlue
        return label
    }()

    private let selectionButton: UIButton = {
        let button = UIButton(type: .custom)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let unselectedImage = UIImage(systemName: "circle", withConfiguration: config)
        let selectedImage = LucideIcon.success.templateImage(pointSize: 18, weight: .medium)
        button.setImage(unselectedImage, for: .normal)
        button.setImage(selectedImage, for: .selected)
        button.tintColor = .systemBlue
        return button
    }()

    // MARK: - Properties

    private var currentItem: CacheResourceItem?
    public var onSelectionToggle: ((String) -> Void)?

    public var item: CacheResourceItem? {
        didSet {
            currentItem = item
            updateUI()
        }
    }

    public var isItemSelected: Bool = false {
        didSet {
            selectionButton.isSelected = isItemSelected
        }
    }

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
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(typeIconContainer)
        containerView.addSubview(titleLabel)
        containerView.addSubview(sizeLabel)
        containerView.addSubview(dateLabel)
        containerView.addSubview(typeBadgeView)
        containerView.addSubview(selectionButton)

        typeIconContainer.addSubview(typeIconView)
        typeBadgeView.addSubview(typeBadgeLabel)

        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.left.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
            make.bottom.equalToSuperview().offset(-4)
        }

        typeIconContainer.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }

        typeIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(24)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalTo(typeIconContainer.snp.right).offset(12)
            make.right.equalTo(selectionButton.snp.left).offset(-12)
        }

        sizeLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.left.equalTo(titleLabel)
        }

        dateLabel.snp.makeConstraints { make in
            make.left.equalTo(sizeLabel.snp.right).offset(8)
            make.centerY.equalTo(sizeLabel)
        }

        typeBadgeView.snp.makeConstraints { make in
            make.top.equalTo(sizeLabel.snp.bottom).offset(6)
            make.left.equalTo(titleLabel)
            make.height.equalTo(20)
            make.bottom.equalToSuperview().offset(-12)
        }

        typeBadgeLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        }

        selectionButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        selectionButton.addTarget(self, action: #selector(selectionButtonTapped), for: .touchUpInside)
    }

    // MARK: - Update UI

    private func updateUI() {
        guard let item = currentItem else {
            titleLabel.text = ""
            sizeLabel.text = ""
            dateLabel.text = ""
            typeBadgeLabel.text = ""
            typeIconView.image = nil
            return
        }

        // 设置标题
        titleLabel.text = item.fileName

        // 设置大小
        sizeLabel.text = item.formattedSize

        // 设置日期
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        dateLabel.text = formatter.localizedString(for: item.date, relativeTo: Date())

        // 设置类型徽章
        typeBadgeLabel.text = item.type.displayName
        typeBadgeView.backgroundColor = item.type.iconColor.withAlphaComponent(0.1)
        typeBadgeLabel.textColor = item.type.iconColor

        // 设置类型图标
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        typeIconView.image = UIImage(systemName: item.type.iconName, withConfiguration: config)
        typeIconView.tintColor = item.type.iconColor
    }

    // MARK: - Actions

    @objc private func selectionButtonTapped() {
        guard let item = currentItem else { return }
        isItemSelected.toggle()
        selectionButton.isSelected = isItemSelected
        onSelectionToggle?(item.key)
    }

    // MARK: - Reuse

    public override func prepareForReuse() {
        super.prepareForReuse()
        currentItem = nil
        isItemSelected = false
        selectionButton.isSelected = false
    }
}
