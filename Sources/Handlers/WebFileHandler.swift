//
//  WebFileHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import WebKit
import MobileCoreServices

// Framework imports

/// 文件选择处理器
public class WebFileHandler: BaseWebNativeHandler {

    // 使用静态字典持有 delegate，防止被释放
    private static var delegateRegistry: [String: FilePickerDelegate] = [:]
    private static var delegateCounter = 0

    /// 处理文件选择请求
    /// - Parameters:
    ///   - body: 包含 accept (MIME type) 和 multiple (是否多选)
    ///   - completion: 结果回调
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let accept = body["accept"] as? String ?? "*/*"
        let multiple = body["multiple"] as? Bool ?? false

        runOnMainThread {
            self.showFilePicker(accept: accept, multiple: multiple, completion: completion)
        }
    }

    /// 显示文件选择器
    /// - Parameters:
    ///   - accept: 接受的文件类型
    ///   - multiple: 是否支持多选
    ///   - completion: 结果回调
    private func showFilePicker(accept: String, multiple: Bool, completion: @escaping (Any) -> Void) {
        guard let topVC = self.topViewController else {
            reject(error: "No view controller available", completion: completion)
            return
        }

        let documentPicker = UIDocumentPickerViewController(documentTypes: [accept == "*/*" ? "public.item" : accept], in: .import)
        documentPicker.allowsMultipleSelection = multiple
        
        let delegateId = "WebFileHandler_\(Self.delegateCounter)"
        Self.delegateCounter += 1
        
        let delegate = FilePickerDelegate(completion: completion, resolve: self.resolve, reject: self.reject)
        WebFileHandler.delegateRegistry[delegateId] = delegate
        documentPicker.delegate = delegate
        
        delegate.onDismiss = {
            WebFileHandler.delegateRegistry.removeValue(forKey: delegateId)
        }
        
        topVC.present(documentPicker, animated: true)
    }

    // MARK: - File Picker Delegate

    /// 文件选择代理类
    private class FilePickerDelegate: NSObject, UIDocumentPickerDelegate {
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

        func documentPickerWasCancelled(_ picker: UIDocumentPickerViewController) {
            onDismiss?()
            self.resolveFunc(["cancelled": true], self.completion)
        }

        func documentPicker(_ picker: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onDismiss?()
            
            var results: [[String: Any]] = []
            for url in urls {
                do {
                    // 开启安全访问
                    let shouldStopAccessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if shouldStopAccessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    let data = try Data(contentsOf: url)
                    let base64 = data.base64EncodedString()
                    
                    results.append([
                        "name": url.lastPathComponent,
                        "data": base64,
                        "size": data.count,
                        "mimeType": getMimeType(for: url)
                    ])
                } catch {
                    print("❌ [WebFileHandler] Error reading file: \(error.localizedDescription)")
                }
            }
            
            if results.isEmpty {
                self.rejectFunc("Failed to read selected files", nil, self.completion)
            } else {
                self.resolveFunc(["files": results], self.completion)
            }
        }
        
        private func getMimeType(for url: URL) -> String {
            let pathExtension = url.pathExtension
            if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue() {
                if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                    return mimetype as String
                }
            }
            return "application/octet-stream"
        }
    }
}
