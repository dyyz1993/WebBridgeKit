//
//  WebMediaHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//

import UIKit
import WebKit
import Photos

// Framework imports

/// 媒体与文件操作 Handler
/// 支持：保存图片到相册、保存文件到系统、原生文件上传
public class WebMediaHandler: BaseWebNativeHandler {
    
    // MARK: - Handle
    
    /**
     * 处理 JS 调用
     * @param body 调用参数
     * @param completion 处理完成后的回调
     */
    public override func handle(body: [String : Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? ""
        
        WebBridgeLogger.shared.log(.info, "[WebMediaHandler] Handling action: \(action)")
        
        switch action {
        case "saveImage":
            let data = params["data"] as? String ?? ""
            saveImage(data: data, completion: completion)
            
        case "saveFile":
            let data = params["data"] as? String ?? ""
            let fileName = params["fileName"] as? String ?? "file.txt"
            saveFile(data: data, fileName: fileName, completion: completion)
            
        case "uploadFile":
            let filePath = params["path"] as? String ?? ""
            let serverUrl = params["url"] as? String ?? ""
            uploadFile(filePath: filePath, serverUrl: serverUrl, completion: completion)
            
        default:
            self.reject(error: "Unsupported action: \(action)", code: 404, completion: completion)
        }
    }
    
    // MARK: - Actions
    
    /**
     * 保存图片到相册
     * @param data Base64 字符串或图片 URL
     * @param completion 返回结果
     */
    private func saveImage(data: String, completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            guard let image = self?.decodeImage(from: data) else {
                self?.reject(error: "Invalid image data", completion: completion)
                return
            }
            
            PHPhotoLibrary.requestAuthorization { status in
                self?.runOnMainThread {
                    if status == .authorized {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        self?.resolve(["status": "saved"], completion: completion)
                    } else {
                        self?.reject(error: "Photo library access denied", completion: completion)
                    }
                }
            }
        }
    }
    
    /**
     * 保存文件到系统“文件”App
     * @param data Base64 数据
     * @param fileName 文件名
     * @param completion 返回结果
     */
    private func saveFile(data: String, fileName: String, completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            guard let fileData = Data(base64Encoded: data) else {
                self?.reject(error: "Invalid base64 data", completion: completion)
                return
            }
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try fileData.write(to: tempURL)
                
                // 弹出系统分享/保存对话框
                let picker: UIDocumentPickerViewController
                if #available(iOS 14.0, *) {
                    picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
                } else {
                    picker = UIDocumentPickerViewController(url: tempURL, in: .exportToService)
                }
                
                if let topVC = self?.getTopViewController() {
                    topVC.present(picker, animated: true, completion: nil)
                    self?.resolve(["status": "picker_opened"], completion: completion)
                } else {
                    self?.reject(error: "Top view controller not found", completion: completion)
                }
            } catch {
                self?.reject(error: "Save file failed: \(error.localizedDescription)", completion: completion)
            }
        }
    }
    
    /**
     * 原生代传：上传本地文件到服务器
     * @param filePath 本地文件路径
     * @param serverUrl 服务器上传接口 URL
     * @param completion 返回结果
     */
    private func uploadFile(filePath: String, serverUrl: String, completion: @escaping (Any) -> Void) {
        guard URL(string: serverUrl) != nil else {
            completion(WebBridgeResponse.error(message: "Invalid server URL"))
            return
        }
        
        // 这里只是模拟上传逻辑，实际应根据业务需求实现 URLSession 上传
        WebBridgeLogger.shared.log(.info, "[WebMediaHandler] Uploading file: \(filePath) to \(serverUrl)")
        
        // 模拟异步上传过程
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            let response = ["success": true, "fileUrl": "https://cdn.example.com/uploads/remote_file.m4a"]
            completion(WebBridgeResponse.success(data: response))
        }
    }
    
    // MARK: - Helpers
    
    private func decodeImage(from data: String) -> UIImage? {
        if data.hasPrefix("data:image") {
            let base64 = data.components(separatedBy: ",").last ?? ""
            if let imageData = Data(base64Encoded: base64) {
                return UIImage(data: imageData)
            }
        } else if let url = URL(string: data), let imageData = try? Data(contentsOf: url) {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    private func getTopViewController() -> UIViewController? {
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            var topVC = window.rootViewController
            while let presentedVC = topVC?.presentedViewController {
                topVC = presentedVC
            }
            return topVC
        }
        return nil
    }
}
