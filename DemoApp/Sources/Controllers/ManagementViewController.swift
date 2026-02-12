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
    
    private let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["收藏", "缓存"])
        control.selectedSegmentIndex = 0
        return control
    }()
    
    private let containerView = UIView()
    
    private lazy var favoriteVC = FavoriteViewController(viewModel: FavoriteViewModel())
    private lazy var cacheVC = CacheManagementViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateChildController()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationItem.titleView = segmentedControl
        
        view.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
    }
    
    @objc private func segmentChanged() {
        updateChildController()
    }
    
    private func updateChildController() {
        // 移除现有子控制器
        children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        }
        
        let targetVC = segmentedControl.selectedSegmentIndex == 0 ? favoriteVC : cacheVC
        
        addChild(targetVC)
        containerView.addSubview(targetVC.view)
        targetVC.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        targetVC.didMove(toParent: self)
        
        // 同步导航项按钮
        navigationItem.leftBarButtonItems = targetVC.navigationItem.leftBarButtonItems
        navigationItem.rightBarButtonItems = targetVC.navigationItem.rightBarButtonItems
        
        // 如果只有一个按钮且没设置 items，尝试同步单个按钮
        if navigationItem.leftBarButtonItems == nil {
            navigationItem.leftBarButtonItem = targetVC.navigationItem.leftBarButtonItem
        }
        if navigationItem.rightBarButtonItems == nil {
            navigationItem.rightBarButtonItem = targetVC.navigationItem.rightBarButtonItem
        }
    }
}
