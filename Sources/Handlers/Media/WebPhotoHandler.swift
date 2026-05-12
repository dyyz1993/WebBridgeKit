//
//  WebPhotoHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import Photos
import PhotosUI
import UIKit
import WebKit
import UniformTypeIdentifiers

// Framework imports

/// 相册选择处理器
@available(iOS 14, *)
public class WebPhotoHandler: BaseWebNativeHandler {

    // 使用静态字典持有所有活跃的 delegate，防止被释放
    private static var delegateRegistry: [String: PhotoPickerDelegate] = [:]
    private static var delegateCounter = 0

    /// 处理相册选择请求
    /// - Parameters:
    ///   - body: 包含 multiple (是否多选) 和 limit (选择限制)
    ///   - completion: 结果回调
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let multiple = body["multiple"] as? Bool ?? false
        let limit = body["limit"] as? Int ?? (multiple ? 5 : 1)

        // 检查相册权限
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            presentPicker(multiple: multiple, limit: limit, completion: completion)
        case .denied, .restricted:
            rejectPermissionDenied(type: .photos, status: .denied, completion: completion)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                self?.runOnMainThread {
                    if newStatus == .authorized || newStatus == .limited {
                        self?.presentPicker(multiple: multiple, limit: limit, completion: completion)
                    } else {
                        self?.rejectPermissionDenied(type: .photos, status: .denied, completion: completion)
                    }
                }
            }
        @unknown default:
            reject(error: "Unknown permission status", completion: completion)
        }
    }

    private func presentPicker(multiple: Bool, limit: Int, completion: @escaping (Any) -> Void) {
        runOnMainThread {
            guard let topVC = self.topViewController else {
                self.reject(error: "No view controller available", completion: completion)
                return
            }

            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.selectionLimit = multiple ? limit : 1
            configuration.filter = .images

            let picker = PHPickerViewController(configuration: configuration)

            // 创建 delegate 并注册到静态字典
            let delegateId = "WebPhotoHandler_\(Self.delegateCounter)"
            Self.delegateCounter += 1

            let delegate = PhotoPickerDelegate(completion: completion, resolve: self.resolve, reject: self.reject)
            WebPhotoHandler.delegateRegistry[delegateId] = delegate
            picker.delegate = delegate

            // 当 picker 关闭时清理
            delegate.onDismiss = {
                WebPhotoHandler.delegateRegistry.removeValue(forKey: delegateId)
            }

            topVC.present(picker, animated: true)
        }
    }

    // MARK: - Picker Delegate

    private class PhotoPickerDelegate: NSObject, PHPickerViewControllerDelegate {
        private let completion: (Any) -> Void
        private let resolveFunc: (Any?, @escaping (Any) -> Void) -> Void
        private let rejectFunc: (String, Int?, @escaping (Any) -> Void) -> Void
        var onDismiss: (() -> Void)?

        init(completion: @escaping (Any) -> Void,
             resolve: @escaping (Any?, @escaping (Any) -> Void) -> Void,
             reject: @escaping (String, Int?, @escaping (Any) -> Void) -> Void) {
            self.completion = completion
            self.resolveFunc = resolve
            self.rejectFunc = reject
            super.init()
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                self.onDismiss?()

                if results.isEmpty {
                    self.resolveFunc(["cancelled": true], self.completion)
                    return
                }

                // 处理选中的照片
                self.processResults(results, startIndex: 0, images: [])
            }
        }

        private func processResults(_ results: [PHPickerResult], startIndex: Int, images: [[String: Any]]) {
            guard startIndex < results.count else {
                // 全部处理完成
                self.resolveFunc([
                    "images": images,
                    "count": images.count
                ], self.completion)
                return
            }

            let result = results[startIndex]

            guard result.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
                // 跳过不支持的类型
                self.processResults(results, startIndex: startIndex + 1, images: images)
                return
            }

            result.itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                if let error = error {
                    print("Error loading photo: \(error.localizedDescription)")
                    // 继续处理下一张
                    self.processResults(results, startIndex: startIndex + 1, images: images)
                    return
                }

                var imageData: Data?
                if let data = item as? Data {
                    imageData = data
                } else if let url = item as? URL {
                    // 从文件加载
                    if let data = try? Data(contentsOf: url) {
                        imageData = data
                    }
                } else if let image = item as? UIImage {
                    // 转换 UIImage 为 JPEG
                    imageData = image.jpegData(compressionQuality: 0.8)
                }

                if let imageData = imageData {
                    let base64 = imageData.base64EncodedString()
                    let imageInfo: [String: Any] = [
                        "data": base64,
                        "mimeType": "image/jpeg",
                        "size": imageData.count
                    ]

                    var newImages = images
                    newImages.append(imageInfo)

                    // 处理下一张
                    self.processResults(results, startIndex: startIndex + 1, images: newImages)
                } else {
                    // 无法处理，继续下一张
                    self.processResults(results, startIndex: startIndex + 1, images: images)
                }
            }
        }
    }
}
