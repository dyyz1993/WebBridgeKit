//
//  ManagementViewController.swift
//  SuperApp
//
//  Created on 2026-02-07.
//

import UIKit
import SnapKit
import WebBridgeKit

/// 管理中心视图控制器（合并收藏与缓存管理）
class ManagementViewController: UIViewController {

    private let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [L10n.tr("management.tab_favorites"), L10n.tr("management.tab_cache")])
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
        view.backgroundColor = ThemeColors.current.background
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

        navigationItem.leftBarButtonItems = targetVC.navigationItem.leftBarButtonItems
        navigationItem.rightBarButtonItems = targetVC.navigationItem.rightBarButtonItems

        if navigationItem.leftBarButtonItems == nil || navigationItem.leftBarButtonItems?.isEmpty == true {
            navigationItem.leftBarButtonItem = targetVC.navigationItem.leftBarButtonItem
            navigationItem.leftBarButtonItems = nil
        }
        if navigationItem.rightBarButtonItems == nil || navigationItem.rightBarButtonItems?.isEmpty == true {
            navigationItem.rightBarButtonItem = targetVC.navigationItem.rightBarButtonItem
            navigationItem.rightBarButtonItems = nil
        }
    }
}
