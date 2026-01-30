//
//  ViewModel.swift
//  WebBridgeKit
//
//  Created on 2026-01-16.
//

import Foundation
import RxSwift

/// ViewModel 基类
open class ViewModel: NSObject {
    /// RxSwift DisposeBag for disposing observables
    public let rx = DisposeBag()
}
