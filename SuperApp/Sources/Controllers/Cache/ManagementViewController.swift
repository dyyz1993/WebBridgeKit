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

    #if !DREL_RELEASE_MINIMAL_SETTINGS && !DREL_CONTAINER_ONLY
    private let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [L10n.tr("management.tab_favorites"), L10n.tr("management.tab_cache")])
        // Entry point is "存储管理": land on the cache segment. The favorites
        // segment default made the first screen an empty favorites list (N2a).
        control.selectedSegmentIndex = 1
        return control
    }()
    #endif

    private let containerView = UIView()

    private lazy var cacheVC = CacheManagementViewController()
    #if !DREL_RELEASE_MINIMAL_SETTINGS && !DREL_CONTAINER_ONLY
    private lazy var favoriteVC = FavoriteViewController(viewModel: FavoriteViewModel())
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateChildController()
    }

    private func setupUI() {
        view.backgroundColor = ThemeTokens.Color.background
        #if !DREL_RELEASE_MINIMAL_SETTINGS && !DREL_CONTAINER_ONLY
        navigationItem.titleView = segmentedControl
        #else
        title = "存储管理"
        #endif

        view.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        #if !DREL_RELEASE_MINIMAL_SETTINGS && !DREL_CONTAINER_ONLY
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        #endif
    }

    #if !DREL_RELEASE_MINIMAL_SETTINGS && !DREL_CONTAINER_ONLY
    @objc private func segmentChanged() {
        if segmentedControl.selectedSegmentIndex == 1 {
            #if !DREL_CONTAINER_ONLY
            TestDataSeeder.seedManifestCaches()
            #endif
        }
        updateChildController()
    }
    #endif

    private func updateChildController() {
        // 移除现有子控制器
        children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        }

        #if !DREL_RELEASE_MINIMAL_SETTINGS && !DREL_CONTAINER_ONLY
        let targetVC = segmentedControl.selectedSegmentIndex == 0 ? favoriteVC : cacheVC
        #else
        let targetVC = cacheVC
        #endif

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
