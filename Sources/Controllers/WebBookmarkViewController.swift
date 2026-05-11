//
//  WebBookmarkViewController.swift
//  WebBridgeKit
//
//  Created on 2026-01-16.
//

import Foundation
import RxCocoa
import RxSwift
import UIKit

/// 书签视图控制器
public class WebBookmarkViewController: UIViewController {

    public let viewModel: WebBookmarkViewModel
    public let rx = DisposeBag()

    public init(viewModel: WebBookmarkViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeTokens.Color.background
        title = "Bookmarks"

        let output = viewModel.transform(input: WebBookmarkViewModel.Input(
            load: .just(()),
            search: .empty(),
            delete: .empty()
        ))

        output.isEmpty
            .drive(onNext: { [weak self] isEmpty in
                if isEmpty {
                    self?.showEmptyState()
                }
            })
            .disposed(by: rx)
    }

    private func showEmptyState() {
        let label = UILabel()
        label.text = "No bookmarks yet"
        label.textAlignment = .center
        label.textColor = ThemeTokens.Color.textSecondary
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
