//
//  TokenManageViewController.swift
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

/// 口令管理视图控制器 (占位符 - 将在 Task 3.5 中实现)
class TokenManageViewController: BaseViewController<TokenManageViewModel> {

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "口令管理\n\n待实现 (Task 3.5)"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.numberOfLines = 0
        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
        imageView.image = UIImage(systemName: "text.command", withConfiguration: config)
        imageView.tintColor = .tertiaryLabel
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "口令管理"
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.systemGroupedBackground

        view.addSubview(iconImageView)
        view.addSubview(placeholderLabel)

        iconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-40)
            make.width.height.equalTo(80)
        }

        placeholderLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(24)
            make.left.equalToSuperview().offset(32)
            make.right.equalToSuperview().offset(-32)
        }
    }
}
