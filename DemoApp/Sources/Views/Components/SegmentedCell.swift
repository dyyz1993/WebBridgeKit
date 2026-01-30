//
//  SegmentedCell.swift
//  DemoApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit

/// 分段控件列表项单元格
class SegmentedCell: UITableViewCell {

    static let identifier = "SegmentedCell"

    // MARK: - UI Components

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = UIColor.label
        return label
    }()

    private let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl()
        control.insertSegment(withTitle: "默认", at: 0, animated: false)
        control.insertSegment(withTitle: "自定义", at: 1, animated: false)
        control.selectedSegmentIndex = 0
        return control
    }()

    // MARK: - Properties

    var onSegmentChange: ((Int) -> Void)?

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
        selectionStyle = .none
        backgroundColor = UIColor.systemBackground

        contentView.addSubview(titleLabel)
        contentView.addSubview(segmentedControl)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        segmentedControl.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-12)
        }

        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
    }

    // MARK: - Configure

    func configure(title: String, selectedIndex: Int) {
        titleLabel.text = title
        segmentedControl.selectedSegmentIndex = selectedIndex
    }

    // MARK: - Actions

    @objc private func segmentChanged() {
        onSegmentChange?(segmentedControl.selectedSegmentIndex)
    }
}
