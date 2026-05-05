//
//  LoadingView+Rx.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import RxSwift
import RxCocoa

public extension Reactive where Base: LoadingView {

    /// Bindable sink for isAnimating state
    var isAnimating: Binder<Bool> {
        return Binder(self.base) { loadingView, isAnimating in
            if isAnimating {
                loadingView.startLoading()
            } else {
                loadingView.stopLoading()
            }
        }
    }
}
