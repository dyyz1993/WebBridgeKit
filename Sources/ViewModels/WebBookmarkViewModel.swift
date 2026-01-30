//
//  WebBookmarkViewModel.swift
//  WebBridgeKit
//
//  Created on 2026-01-16.
//

import Foundation
import RxCocoa
import RxSwift

/// 书签 ViewModel
public class WebBookmarkViewModel: ViewModel {

    public let disposeBag = DisposeBag()

    // MARK: - Input & Output

    public struct Input {
        let load: Driver<Void>
        let search: Driver<String?>
        let delete: Driver<String>
    }

    public struct Output {
        let bookmarks: Driver<[WebBookmark]>
        let isEmpty: Driver<Bool>
    }

    // MARK: - Properties

    private let bookmarksRelay = BehaviorRelay<[WebBookmark]>(value: [])

    // MARK: - Transform

    public func transform(input: Input) -> Output {
        input.load
            .drive(onNext: { [weak self] in
                self?.loadBookmarks()
            })
            .disposed(by: disposeBag)

        return Output(
            bookmarks: bookmarksRelay.asDriver(onErrorJustReturn: []),
            isEmpty: bookmarksRelay.map(\.isEmpty).asDriver(onErrorJustReturn: true)
        )
    }

    // MARK: - Private Methods

    private func loadBookmarks() {
        // 实现加载书签逻辑
        bookmarksRelay.accept([])
    }
}

// MARK: - WebBookmark Model

public struct WebBookmark {
    public let id: String
    public let url: String
    public let title: String
}
