//
//  WebBrowserViewController+StatusBar.swift
//  WebBridgeKit
//
//  Status bar control & gesture delegate
//

import UIKit

// MARK: - UIGestureRecognizerDelegate

extension WebBrowserViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return hideNavBar
    }
}

// MARK: - Status Bar Control

extension WebBrowserViewController {
    /// 重写状态栏隐藏属性
    public override var prefersStatusBarHidden: Bool {
        return isStatusBarHidden
    }

    /// 状态栏动画样式
    public override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }

    /// 支持的屏幕方向
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .allButUpsideDown
    }

    /// 是否自动旋转
    public override var shouldAutorotate: Bool {
        return true
    }
}
