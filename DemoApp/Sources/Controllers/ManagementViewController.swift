//
//  ManagementViewController.swift
//  DemoApp
//
//  Created on 2026-02-07.
//

import UIKit
import SnapKit

/// 管理中心视图控制器（合并收藏与缓存管理）
class ManagementViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "管理"
        
        let label = UILabel()
        label.text = "资源管理中心 (开发中)"
        label.textColor = .secondaryLabel
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
