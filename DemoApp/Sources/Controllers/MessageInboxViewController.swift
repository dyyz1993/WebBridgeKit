//
//  MessageInboxViewController.swift
//  DemoApp
//
//  Created on 2026-02-07.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

/// 消息收件箱视图控制器
class MessageInboxViewController: UIViewController {
    
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "消息中心"
        
        let label = UILabel()
        label.text = "Webhook 收件箱 (开发中)"
        label.textColor = .secondaryLabel
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
