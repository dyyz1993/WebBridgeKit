//
//  WebCameraHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import AVFoundation
import Foundation
import Photos
import UIKit
import WebKit
import Vision

// Framework imports

/// 相机功能处理器
public class WebCameraHandler: BaseWebNativeHandler {

    // 使用静态字典持有所有活跃的 delegate，防止被释放
    private static var delegateRegistry: [String: CameraDelegate] = [:]
    private static var delegateCounter = 0

    /// 处理相机请求
    /// - Parameters:
    ///   - body: 包含 type ("photo" 或 "video")
    ///   - completion: 回调给 JS 的结果
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        // 兼容 body 或 body.params
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? "start" // 针对 videoStream 的 action
        let type = params["type"] as? String ?? "photo" // 针对 camera 的 type

        // 如果是通过 videoStream 调用的，转发给 WebVideoHandler
        if let videoHandler = WebVideoHandler.sharedInstance {
            // 这里我们不需要显式转发，因为 Bridge 已经注册了 videoStream 对应 WebVideoHandler
            // 但如果 JS 混用了 camera action 发送给 videoStream，我们需要在这里处理
        }

        switch type {
        case "photo":
            requestCameraPermission { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    self.openCamera(completion: completion)
                } else {
                    self.rejectPermissionDenied(type: .camera, status: .denied, completion: completion)
                }
            }
        case "video":
            requestCameraPermission { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    self.openCameraForVideo(completion: completion)
                } else {
                    self.rejectPermissionDenied(type: .camera, status: .denied, completion: completion)
                }
            }
        default:
            reject(error: "Unknown camera type: \(type)", completion: completion)
        }
    }

    /// 请求相机权限
    /// - Parameter completion: 权限结果回调
    private func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            runOnMainThread {
                completion(true)
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                self?.runOnMainThread {
                    completion(granted)
                }
            }
        default:
            runOnMainThread {
                completion(false)
            }
        }
    }

    /// 打开相机拍照
    /// - Parameter completion: 结果回调
    private func openCamera(completion: @escaping (Any) -> Void) {
        runOnMainThread {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                self.reject(error: "相机不可用", completion: completion)
                return
            }

            guard let topVC = self.topViewController else {
                self.reject(error: "No view controller available", completion: completion)
                return
            }

            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.view.accessibilityIdentifier = "camera.preview"

            // 创建 delegate 并注册到静态字典
            let delegateId = "WebCameraHandler_\(Self.delegateCounter)"
            Self.delegateCounter += 1

            let delegate = CameraDelegate(completion: completion, resolve: self.resolve, reject: self.reject, isVideo: false)
            WebCameraHandler.delegateRegistry[delegateId] = delegate
            picker.delegate = delegate

            // 当 picker 关闭时清理
            delegate.onDismiss = {
                WebCameraHandler.delegateRegistry.removeValue(forKey: delegateId)
            }

            topVC.present(picker, animated: true)
        }
    }

    /// 打开相机录像
    /// - Parameter completion: 结果回调
    private func openCameraForVideo(completion: @escaping (Any) -> Void) {
        runOnMainThread {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                self.reject(error: "相机不可用", completion: completion)
                return
            }

            guard let topVC = self.topViewController else {
                self.reject(error: "No view controller available", completion: completion)
                return
            }

            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.cameraCaptureMode = .video
            picker.videoQuality = .typeMedium
            picker.view.accessibilityIdentifier = "camera.preview"

            // 创建 delegate 并注册到静态字典
            let delegateId = "WebCameraHandler_\(Self.delegateCounter)"
            Self.delegateCounter += 1

            let delegate = CameraDelegate(completion: completion, resolve: self.resolve, reject: self.reject, isVideo: true)
            WebCameraHandler.delegateRegistry[delegateId] = delegate
            picker.delegate = delegate

            // 当 picker 关闭时清理
            delegate.onDismiss = {
                WebCameraHandler.delegateRegistry.removeValue(forKey: delegateId)
            }

            topVC.present(picker, animated: true)
        }
    }

    // MARK: - Camera Delegate

    /// 相机代理类，处理拍摄结果
    private class CameraDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let completion: (Any) -> Void
        private let resolveFunc: (Any?, @escaping (Any) -> Void) -> Void
        private let rejectFunc: (String, Int?, @escaping (Any) -> Void) -> Void
        private let isVideo: Bool
        var onDismiss: (() -> Void)?

        init(completion: @escaping (Any) -> Void,
             resolve: @escaping (Any?, @escaping (Any) -> Void) -> Void,
             reject: @escaping (String, Int?, @escaping (Any) -> Void) -> Void,
             isVideo: Bool = false) {
            self.completion = completion
            self.resolveFunc = resolve
            self.rejectFunc = reject
            self.isVideo = isVideo
            super.init()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onDismiss?()
            picker.dismiss(animated: true) {
                self.resolveFunc(["cancelled": true], self.completion)
            }
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                self.onDismiss?()

                if self.isVideo, let url = info[.mediaURL] as? URL {
                    // 处理视频
                    do {
                        let videoData = try Data(contentsOf: url)
                        let base64 = videoData.base64EncodedString()

                        self.resolveFunc([
                            "type": "video",
                            "data": base64,
                            "mimeType": "video/mp4",
                            "size": videoData.count
                        ], self.completion)
                    } catch {
                        self.rejectFunc("Failed to process video: \(error.localizedDescription)", nil, self.completion)
                    }
                } else if let image = info[.originalImage] as? UIImage, let jpegData = image.jpegData(compressionQuality: 0.8) {
                    // 处理照片
                    let base64 = jpegData.base64EncodedString()

                    self.resolveFunc([
                        "type": "photo",
                        "data": base64,
                        "mimeType": "image/jpeg",
                        "width": image.size.width,
                        "height": image.size.height,
                        "size": jpegData.count
                    ], self.completion)
                } else {
                    self.rejectFunc("Failed to process image", nil, self.completion)
                }
            }
        }
    }
}
