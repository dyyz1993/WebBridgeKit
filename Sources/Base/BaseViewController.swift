//
//  BaseViewController.swift
//  WebBridgeKit
//
//  Created on 2026-01-16.
//

import UIKit
import RxSwift

/// 泛型视图控制器基类
open class BaseViewController<T>: UIViewController where T: ViewModel {

    public let viewModel: T
    public let rx = DisposeBag()

    public init(viewModel: T) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var isViewModelBinded = false

    open override func viewDidLoad() {
        super.viewDidLoad()
        makeUI()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !isViewModelBinded {
            isViewModelBinded = true
            bindViewModel()
        }
    }

    /// 子类重写此方法设置 UI
    open func makeUI() {}

    /// 子类重写此方法绑定 ViewModel
    open func bindViewModel() {}
}
