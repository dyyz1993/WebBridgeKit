//
//  WebPageHistoryCell.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import SnapKit
import UIKit

// Framework imports

/// 历史记录列表单元格
class WebPageHistoryCell: UITableViewCell {

    // MARK: - UI Components

    /// 缓存状态图标
    private let cacheStatusImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.systemGreen
        return imageView
    }()

    /// 标题标签
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = WKColor.grey.darken4
        label.numberOfLines = 2
        return label
    }()

    /// URL 标签
    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = WKColor.grey.base
        label.numberOfLines = 1
        return label
    }()

    /// 访问信息标签
    private let visitInfoLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        label.textColor = WKColor.grey.lighten2
        return label
    }()

    /// 缓存大小标签
    private let cacheSizeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = WKColor.lightBlue.darken3
        label.layer.borderColor = WKColor.lightBlue.darken3.cgColor
        label.layer.borderWidth = 1
        label.layer.cornerRadius = 3
        label.textAlignment = .center
        return label
    }()

    // MARK: - Properties

    private var currentHistory: WebPageHistory?

    var history: WebPageHistory? {
        didSet {
            currentHistory = history
            updateUI()
        }
    }

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = WKColor.background.primary

        contentView.addSubview(cacheStatusImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(urlLabel)
        contentView.addSubview(visitInfoLabel)
        contentView.addSubview(cacheSizeLabel)

        cacheStatusImageView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
            make.left.equalToSuperview().offset(15)
            make.centerY.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalTo(cacheStatusImageView.snp.right).offset(12)
            make.right.equalTo(cacheSizeLabel.snp.left).offset(-8)
        }

        urlLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.left.equalTo(cacheStatusImageView.snp.right).offset(12)
            make.right.equalToSuperview().offset(-15)
        }

        visitInfoLabel.snp.makeConstraints { make in
            make.top.equalTo(urlLabel.snp.bottom).offset(4)
            make.left.equalTo(cacheStatusImageView.snp.right).offset(12)
            make.bottom.equalToSuperview().offset(-12)
        }

        cacheSizeLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-15)
            make.height.equalTo(18)
        }
    }

    // MARK: - Update UI

    private func updateUI() {
        guard let history = currentHistory else {
            titleLabel.text = ""
            urlLabel.text = ""
            visitInfoLabel.text = ""
            cacheStatusImageView.image = nil
            cacheSizeLabel.isHidden = true
            return
        }

        // 设置标题
        titleLabel.text = history.title ?? history.url

        // 设置 URL
        if let url = URL(string: history.url) {
            urlLabel.text = url.host ?? history.url
        } else {
            urlLabel.text = history.url
        }

        // 设置访问信息
        let visitText: String
        if history.visitCount > 1 {
            visitText = String(format: NSLocalizedString("%d visits", comment: ""), history.visitCount)
        } else {
            visitText = NSLocalizedString("1 visit", comment: "")
        }

        let timeText = formatRelativeTime(history.lastVisitDate)
        visitInfoLabel.text = "\(timeText) • \(visitText)"

        // 设置缓存状态
        if history.isCached {
            cacheStatusImageView.image = UIImage(systemName: "checkmark.circle.fill")
            cacheStatusImageView.tintColor = UIColor.systemGreen

            // 显示缓存大小
            cacheSizeLabel.text = history.formattedSize
            cacheSizeLabel.isHidden = false
        } else {
            cacheStatusImageView.image = UIImage(systemName: "circle")
            cacheStatusImageView.tintColor = WKColor.grey.lighten2
            cacheSizeLabel.isHidden = true
        }
    }

    // MARK: - Helper Methods

    private func formatRelativeTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let components = calendar.dateComponents([.hour, .minute], from: date, to: now)
            if let hours = components.hour, hours > 0 {
                return L10n.tr("discover.time.hour_ago", "\(hours)")
            } else if let minutes = components.minute, minutes > 0 {
                return L10n.tr("discover.time.min_ago", "\(minutes)")
            } else {
                return L10n.tr("discover.time.just_now")
            }
        } else if calendar.isDateInYesterday(date) {
            return L10n.tr("discover.time.yesterday")
        } else {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if days < 7 {
                return L10n.tr("discover.time.days_ago", "\(days)")
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.locale = Locale.current
                return formatter.string(from: date)
            }
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        cacheStatusImageView.image = nil
        currentHistory = nil
    }
}
