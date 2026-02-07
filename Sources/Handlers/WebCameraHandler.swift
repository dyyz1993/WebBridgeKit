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

    // 视频流 (New)
    public class WebVideoHandler: BaseWebNativeHandler, AVCaptureVideoDataOutputSampleBufferDelegate {
        
        // 添加单例引用，方便调试或特殊转发
        static var sharedInstance: WebVideoHandler?

        private var captureSession: AVCaptureSession?
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var containerView: UIView?

        public override init() {
            super.init()
            WebVideoHandler.sharedInstance = self
        }

    // 人脸识别相关
    private var faceDetectionRequest: VNDetectFaceLandmarksRequest?
    private var handPoseRequest: Any? // VNHumanHandPoseRequest on iOS 14+
    private var sequenceHandler = VNSequenceRequestHandler()
    private var isFaceTrackingEnabled = false
    private var isHandTrackingEnabled = false
    private var isFrameTransferEnabled = false
    private var transferMode: String = "base64" // "base64" 或 "binary"
    private var currentCameraPosition: AVCaptureDevice.Position = .front
    
    // FPS 统计
    private var frameCount = 0
    private var lastFPSReportTime = Date()

    /// 处理视频控制请求
    /// - Parameters:
    ///   - body: 包含 action ("start", "stop", "switch", "config", "checkPermission", "updateOverlay")
    ///   - completion: 结果回调
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        // 兼容 body 或 body.params
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? "start"

        switch action {
        case "start", "startOverlay":
            startVideo(body: params, completion: completion)
        case "stop", "stopOverlay":
            stopVideo(completion: completion)
        case "switch", "switchCamera":
            switchCamera(completion: completion)
        case "config":
            updateConfig(body: params, completion: completion)
        case "toggleFrameTransfer":
            toggleFrameTransfer(params: params, completion: completion)
        case "toggleFaceTracking":
            toggleFaceTracking(params: params, completion: completion)
        case "toggleHandTracking":
            toggleHandTracking(params: params, completion: completion)
        case "checkPermission":
            checkPermission(completion: completion)
        case "updateOverlay":
            updateOverlay(params: params, completion: completion)
        default:
            reject(error: "Unknown video action: \(action)", completion: completion)
        }
    }

    /// 切换人脸追踪状态
    private func toggleFaceTracking(params: [String: Any], completion: @escaping (Any) -> Void) {
        if let enabled = params["enabled"] as? Bool {
            isFaceTrackingEnabled = enabled
        } else {
            isFaceTrackingEnabled = !isFaceTrackingEnabled
        }
        
        if isFaceTrackingEnabled && faceDetectionRequest == nil {
            setupFaceDetection()
        }
        
        resolve(["enabled": isFaceTrackingEnabled], completion: completion)
    }

    /// 切换手势追踪状态
    private func toggleHandTracking(params: [String: Any], completion: @escaping (Any) -> Void) {
        if let enabled = params["enabled"] as? Bool {
            isHandTrackingEnabled = enabled
        } else {
            isHandTrackingEnabled = !isHandTrackingEnabled
        }
        
        if isHandTrackingEnabled && handPoseRequest == nil {
            if #available(iOS 14.0, *) {
                setupHandDetection()
            }
        }
        
        resolve(["enabled": isHandTrackingEnabled], completion: completion)
    }

    /// 切换帧传输状态
    private func toggleFrameTransfer(params: [String: Any], completion: @escaping (Any) -> Void) {
        if let enabled = params["enabled"] as? Bool {
            isFrameTransferEnabled = enabled
        } else {
            isFrameTransferEnabled = !isFrameTransferEnabled
        }
        resolve(["enabled": isFrameTransferEnabled], completion: completion)
    }

    /// 开启视频预览
    private func startVideo(body: [String: Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? body
        startOverlay(params: params, completion: completion)
    }

    /// 停止视频预览
    private func stopVideo(completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            self?.stopOverlayInternal()
            self?.resolve(["message": "Video stopped"], completion: completion)
        }
    }

    /// 更新视频配置 (如开启/关闭追踪)
    private func updateConfig(body: [String: Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? body
        
        if let faceTracking = params["faceTracking"] as? Bool {
            isFaceTrackingEnabled = faceTracking
            if faceTracking && faceDetectionRequest == nil {
                setupFaceDetection()
            }
        }
        
        if let handTracking = params["handTracking"] as? Bool {
            isHandTrackingEnabled = handTracking
        }
        
        if let frameTransfer = params["frameTransfer"] as? Bool {
            isFrameTransferEnabled = frameTransfer
        }
        
        if let mode = params["transferMode"] as? String {
            transferMode = mode
        }
        
        resolve(["success": true], completion: completion)
    }

    /// 检查相机权限
    private func checkPermission(completion: @escaping (Any) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            self.resolve(["authorized": true, "status": "authorized"], completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                self?.runOnMainThread {
                    self?.resolve(["authorized": granted, "status": granted ? "authorized" : "denied"], completion: completion)
                }
            }
        default:
            self.resolve(["authorized": false, "status": "denied"], completion: completion)
        }
    }

    /// 开启原生视频覆盖层
    private func startOverlay(params: [String: Any], completion: @escaping (Any) -> Void) {
        print("🎬 [NativeVideo] startOverlay called with params: \(params)")
        runOnMainThread { [weak self] in
            guard let self = self, let webView = self.webView else {
                print("🎬 [NativeVideo] Error: WebView not available")
                self?.reject(error: "WebView not available", completion: completion)
                return
            }

            // 如果已经存在，先停止
            self.stopOverlayInternal()

            // 获取位置参数 (由 JS 传入)
            let x = params["x"] as? CGFloat ?? 0
            let y = params["y"] as? CGFloat ?? 0
            let width = params["width"] as? CGFloat ?? 200
            let height = params["height"] as? CGFloat ?? 150
            let cornerRadius = params["cornerRadius"] as? CGFloat ?? 10
            let facingMode = params["facingMode"] as? String ?? "user"
            let isHidden = params["hidden"] as? Bool ?? false
            
            print("🎬 [NativeVideo] Config: pos=(\(x),\(y)), size=\(width)x\(height), isHidden=\(isHidden)")
            self.currentCameraPosition = (facingMode == "environment") ? .back : .front

            // 1. 创建 Session
            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .medium
            
            // 2. 设置输入
            guard let device = self.getDevice(for: self.currentCameraPosition),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                session.commitConfiguration()
                self.reject(error: "Camera not available", completion: completion)
                return
            }
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            // 3. 设置数据输出
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            
            session.commitConfiguration()
            
            // 4. 创建 Preview Layer
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspect
            previewLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
            previewLayer.cornerRadius = cornerRadius
            previewLayer.masksToBounds = true
            previewLayer.isHidden = isHidden
            
            // 5. 设置方向
            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if let outputConnection = videoOutput.connection(with: .video), outputConnection.isVideoOrientationSupported {
                outputConnection.videoOrientation = .portrait
                if self.currentCameraPosition == .front && outputConnection.isVideoMirroringSupported {
                    outputConnection.isVideoMirrored = true
                }
            }

            // 6. 创建并添加容器视图
            let container = OverlayContainerView(layer: previewLayer)
            container.isHidden = isHidden
            container.isUserInteractionEnabled = false
            container.accessibilityIdentifier = "camera.videoOverlay"
            
            let scrollX = webView.scrollView.contentOffset.x
            let scrollY = webView.scrollView.contentOffset.y
            container.frame = CGRect(x: x + scrollX, y: y + scrollY, width: width, height: height)
            
            webView.scrollView.addSubview(container)
            webView.scrollView.bringSubviewToFront(container)

            // 7. 启动
             print("🎬 [NativeVideo] Starting AVCaptureSession...")
             DispatchQueue.global(qos: .userInitiated).async {
                 session.startRunning()
                 self.runOnMainThread {
                     print("🎬 [NativeVideo] AVCaptureSession is running")
                     self.captureSession = session
                    self.previewLayer = previewLayer
                    self.containerView = container
                    self.resolve(["facingMode": facingMode], completion: completion)
                }
            }
        }
    }

    /// 获取相机设备
    private func getDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices.first { $0.position == position }
    }

    /// 切换前后摄像头
    private func switchCamera(completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            guard let self = self, let session = self.captureSession else {
                self?.reject(error: "Session not running", completion: completion)
                return
            }

            session.beginConfiguration()
            
            // 移除当前输入
            if let currentInput = session.inputs.first {
                session.removeInput(currentInput)
            }

            // 切换位置
            self.currentCameraPosition = (self.currentCameraPosition == .front) ? .back : .front
            
            guard let newDevice = self.getDevice(for: self.currentCameraPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                session.commitConfiguration()
                self.reject(error: "Failed to switch camera", completion: completion)
                return
            }

            if session.canAddInput(newInput) {
                session.addInput(newInput)
            }
            
            session.commitConfiguration()
            self.resolve(["facingMode": self.currentCameraPosition == .front ? "user" : "environment"], completion: completion)
        }
    }

    /// 设置人脸检测
    private func setupFaceDetection() {
        faceDetectionRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self, let results = request.results as? [VNFaceObservation] else { return }
            self.handleFaceDetectionResults(results)
        }
    }

    /// 处理人脸检测结果
    private func handleFaceDetectionResults(_ results: [VNFaceObservation]) {
        guard isFaceTrackingEnabled, let webView = self.webView else { return }
        
        let faceData = results.map { observation -> [String: Any] in
            let box = observation.boundingBox
            let convertedBox: [String: CGFloat] = [
                "x": box.origin.x,
                "y": 1.0 - box.origin.y - box.size.height,
                "width": box.size.width,
                "height": box.size.height
            ]
            
            var faceDict: [String: Any] = [
                "boundingBox": convertedBox,
                "roll": observation.roll?.doubleValue ?? 0,
                "yaw": observation.yaw?.doubleValue ?? 0
            ]
            
            // 采集/估算 Pitch (抬头/低头)
            if #available(iOS 15.0, *) {
                faceDict["pitch"] = observation.pitch?.doubleValue ?? 0
            } else {
                if let landmarks = observation.landmarks {
                    let nosePoints = landmarks.nose?.normalizedPoints
                    let leftEyePoints = landmarks.leftEye?.normalizedPoints
                    let rightEyePoints = landmarks.rightEye?.normalizedPoints
                    
                    if let nose = nosePoints?.first, let leftEye = leftEyePoints?.first, let rightEye = rightEyePoints?.first {
                        let eyeCenterY = (leftEye.y + rightEye.y) / 2.0
                        let offset = nose.y - eyeCenterY
                        faceDict["pitch"] = (offset - 0.05) * -3.0
                    }
                }
            }
            
            if let landmarks = observation.landmarks {
                var landmarkData: [String: [[String: CGFloat]]] = [:]
                
                func convertPoints(_ points: [CGPoint]?) -> [[String: CGFloat]]? {
                    return points?.map { pt in
                        let imageX = box.origin.x + (pt.x * box.size.width)
                        let imageY = box.origin.y + (pt.y * box.size.height)
                        return ["x": imageX, "y": 1.0 - imageY]
                    }
                }
                
                landmarkData["faceContour"] = convertPoints(landmarks.faceContour?.normalizedPoints)
                landmarkData["leftEye"] = convertPoints(landmarks.leftEye?.normalizedPoints)
                landmarkData["rightEye"] = convertPoints(landmarks.rightEye?.normalizedPoints)
                landmarkData["nose"] = convertPoints(landmarks.nose?.normalizedPoints)
                landmarkData["noseCrest"] = convertPoints(landmarks.noseCrest?.normalizedPoints)
                landmarkData["medianLine"] = convertPoints(landmarks.medianLine?.normalizedPoints)
                landmarkData["outerLips"] = convertPoints(landmarks.outerLips?.normalizedPoints)
                landmarkData["innerLips"] = convertPoints(landmarks.innerLips?.normalizedPoints)
                landmarkData["leftEyebrow"] = convertPoints(landmarks.leftEyebrow?.normalizedPoints)
                landmarkData["rightEyebrow"] = convertPoints(landmarks.rightEyebrow?.normalizedPoints)
                
                faceDict["landmarks"] = landmarkData
                
                // 表情识别逻辑
                if let outerLips = landmarks.outerLips?.normalizedPoints {
                    let top = outerLips[2].y
                    let bottom = outerLips[8].y
                    let mouthOpen = abs(top - bottom) > 0.15
                    faceDict["mouthOpen"] = mouthOpen
                }
            }

            // 🔥 眨眼检测（通过分析眼睛区域特征点计算）
            var leftEyeClosed = false
            var rightEyeClosed = false

            if let landmarks = observation.landmarks {
                // 使用眼睛特征点计算眨眼（Eye Aspect Ratio）
                // 左眼：使用 6 个特征点计算纵横比
                if let leftEyePoints = landmarks.leftEye?.normalizedPoints, leftEyePoints.count >= 6 {
                    // 计算眼睛的纵横比（EAR）
                    // EAR = (|p2-p6| + |p3-p5|) / (2 * |p1-p4|)
                    let p1 = leftEyePoints[0]
                    let p2 = leftEyePoints[1]
                    let p3 = leftEyePoints[2]
                    let p4 = leftEyePoints[3]
                    let p5 = leftEyePoints[4]
                    let p6 = leftEyePoints[5]

                    let vertical1 = sqrt(pow(p2.x - p6.x, 2) + pow(p2.y - p6.y, 2))
                    let vertical2 = sqrt(pow(p3.x - p5.x, 2) + pow(p3.y - p5.y, 2))
                    let horizontal = sqrt(pow(p1.x - p4.x, 2) + pow(p1.y - p4.y, 2))

                    let ear = (vertical1 + vertical2) / (2.0 * horizontal)

                    // EAR 阈值：通常眨眼时 EAR < 0.2
                    leftEyeClosed = ear < 0.2
                }

                // 右眼
                if let rightEyePoints = landmarks.rightEye?.normalizedPoints, rightEyePoints.count >= 6 {
                    let p1 = rightEyePoints[0]
                    let p2 = rightEyePoints[1]
                    let p3 = rightEyePoints[2]
                    let p4 = rightEyePoints[3]
                    let p5 = rightEyePoints[4]
                    let p6 = rightEyePoints[5]

                    let vertical1 = sqrt(pow(p2.x - p6.x, 2) + pow(p2.y - p6.y, 2))
                    let vertical2 = sqrt(pow(p3.x - p5.x, 2) + pow(p3.y - p5.y, 2))
                    let horizontal = sqrt(pow(p1.x - p4.x, 2) + pow(p1.y - p4.y, 2))

                    let ear = (vertical1 + vertical2) / (2.0 * horizontal)

                    rightEyeClosed = ear < 0.2
                }
            }

            faceDict["leftEyeClosed"] = leftEyeClosed
            faceDict["rightEyeClosed"] = rightEyeClosed

            return faceDict
        }
        
        runOnMainThread { [weak self] in
            guard let self = self, let webView = self.webView else { return }
            let json = try? JSONSerialization.data(withJSONObject: faceData, options: [])
            if let jsonString = json.flatMap({ String(data: $0, encoding: .utf8) }) {
                let script = "if(window.onFaceTracked) { window.onFaceTracked(\(jsonString)); }"
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
        }
    }

    /// 设置手势检测
    @available(iOS 14.0, *)
    private func setupHandDetection() {
        print("✋ [NativeHand] Setting up VNDetectHumanHandPoseRequest...")
        let request = VNDetectHumanHandPoseRequest { [weak self] request, error in
            if let error = error {
                print("✋ [NativeHand] Error: \(error.localizedDescription)")
                self?.sendNativeLogToJS("Hand Tracking Error: \(error.localizedDescription)")
                return
            }
            guard let self = self, let results = request.results as? [VNHumanHandPoseObservation] else { return }
            self.handleHandDetectionResults(results)
        }
        request.maximumHandCount = 2
        if #available(iOS 15.0, *) {
            request.revision = VNDetectHumanHandPoseRequestRevision1
        }
        handPoseRequest = request
    }

    /// 向 JS 发送日志
    private func sendNativeLogToJS(_ message: String) {
        runOnMainThread { [weak self] in
            let script = "console.log('🍎 [NativeLog] \(message)');"
            self?.webView?.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    /// 处理手势检测结果
    @available(iOS 14.0, *)
    private func handleHandDetectionResults(_ results: [VNHumanHandPoseObservation]) {
        guard isHandTrackingEnabled, let webView = self.webView else { return }
        
        let handData = results.map { observation -> [String: Any] in
            var joints: [String: [String: CGFloat]] = [:]
            
            let allJoints: [VNHumanHandPoseObservation.JointName] = [
                .wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
                .indexMCP, .indexPIP, .indexDIP, .indexTip,
                .middleMCP, .middlePIP, .middleDIP, .middleTip,
                .ringMCP, .ringPIP, .ringDIP, .ringTip,
                .littleMCP, .littlePIP, .littleDIP, .littleTip
            ]
            
            for joint in allJoints {
                if let point = try? observation.recognizedPoint(joint), point.confidence > 0.1 {
                    let fullKey = joint.rawValue.rawValue
                    var shortKey = ""
                    let key = fullKey.lowercased()
                    if key.contains("wrist") { shortKey = "wrist" }
                    else if key.contains("thumb") {
                        if key.contains("cmc") { shortKey = "thumbCMC" }
                        else if key.contains("mp") { shortKey = "thumbMP" }
                        else if key.contains("ip") { shortKey = "thumbIP" }
                        else if key.contains("tip") { shortKey = "thumbTip" }
                    }
                    else if key.contains("index") {
                        if key.contains("mcp") { shortKey = "indexMCP" }
                        else if key.contains("pip") { shortKey = "indexPIP" }
                        else if key.contains("dip") { shortKey = "indexDIP" }
                        else if key.contains("tip") { shortKey = "indexTip" }
                    }
                    else if key.contains("middle") {
                        if key.contains("mcp") { shortKey = "middleMCP" }
                        else if key.contains("pip") { shortKey = "middlePIP" }
                        else if key.contains("dip") { shortKey = "middleDIP" }
                        else if key.contains("tip") { shortKey = "middleTip" }
                    }
                    else if key.contains("ring") {
                        if key.contains("mcp") { shortKey = "ringMCP" }
                        else if key.contains("pip") { shortKey = "ringPIP" }
                        else if key.contains("dip") { shortKey = "ringDIP" }
                        else if key.contains("tip") { shortKey = "ringTip" }
                    }
                    else if key.contains("little") {
                        if key.contains("mcp") { shortKey = "littleMCP" }
                        else if key.contains("pip") { shortKey = "littlePIP" }
                        else if key.contains("dip") { shortKey = "littleDIP" }
                        else if key.contains("tip") { shortKey = "littleTip" }
                    }
                    
                    if !shortKey.isEmpty {
                        joints[shortKey] = [
                            "x": point.location.x,
                            "y": 1.0 - point.location.y
                        ]
                    }
                }
            }
            
            var dict: [String: Any] = [
                "confidence": observation.confidence,
                "joints": joints
            ]
            
            if #available(iOS 15.0, *) {
                dict["chirality"] = observation.chirality == .left ? "left" : "right"
            } else {
                dict["chirality"] = "unknown"
            }
            
            return dict
        }
        
        runOnMainThread { [weak self] in
            guard let self = self, let webView = self.webView else { return }
            let json = try? JSONSerialization.data(withJSONObject: handData, options: [])
            if let jsonString = json.flatMap({ String(data: $0, encoding: .utf8) }) {
                let script = "if(window.onHandTracked) { window.onHandTracked(\(jsonString)); }"
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    /// 处理相机视频流输出
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 1. 计算原生端 FPS
        frameCount += 1
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastFPSReportTime)
        if timeInterval >= 1.0 {
            let fps = Double(frameCount) / timeInterval
            frameCount = 0
            lastFPSReportTime = now
            runOnMainThread { [weak self] in
                self?.webView?.evaluateJavaScript("if(window.onNativeFPS) { window.onNativeFPS(\(Int(fps))); }", completionHandler: nil)
            }
        }

        // 2. 人脸/手势识别处理
        if isFaceTrackingEnabled || isHandTrackingEnabled {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let orientation: CGImagePropertyOrientation = (self.currentCameraPosition == .front) ? .leftMirrored : .right
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            
            var requests: [VNRequest] = []
            if isFaceTrackingEnabled, let request = faceDetectionRequest {
                requests.append(request)
            }
            if #available(iOS 14.0, *) {
                if isHandTrackingEnabled, let request = handPoseRequest as? VNDetectHumanHandPoseRequest {
                    requests.append(request)
                }
            }
            
            if !requests.isEmpty {
                do {
                    try imageRequestHandler.perform(requests)
                } catch {
                    print("❌ [NativeVision] Perform Error: \(error.localizedDescription)")
                    self.sendNativeLogToJS("Vision Perform Error: \(error.localizedDescription)")
                }
            }
        }

        // 3. 原始帧传输
        if isFrameTransferEnabled {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let orientation: CGImagePropertyOrientation = (self.currentCameraPosition == .front) ? .leftMirrored : .right
            ciImage = ciImage.oriented(orientation)
            
            let context = CIContext()
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                if let data = uiImage.jpegData(compressionQuality: 0.4) {
                    let width = cgImage.width
                    let height = cgImage.height
                    
                    runOnMainThread { [weak self] in
                        guard let self = self, let webView = self.webView else { return }
                        
                        let base64 = data.base64EncodedString()
                        let frameInfo: [String: Any] = [
                            "width": width,
                            "height": height,
                            "isMirrored": self.currentCameraPosition == .front
                        ]
                        
                        let infoJson = try? JSONSerialization.data(withJSONObject: frameInfo, options: [])
                        let infoString = infoJson.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                        
                        if self.transferMode == "binary" {
                            let updateScript = "window._lastFrameData = '\(base64)'; window._lastFrameInfo = \(infoString);"
                            let triggerScript = "if(window.onVideoFrameBinary) { window.onVideoFrameBinary(); }"
                            webView.evaluateJavaScript(updateScript + triggerScript, completionHandler: nil)
                        } else {
                            let script = "if(window.onVideoFrame) { window.onVideoFrame('data:image/jpeg;base64,\(base64)', \(infoString)); }"
                            webView.evaluateJavaScript(script, completionHandler: nil)
                        }
                    }
                }
            }
        }
    }

    /// 更新覆盖层布局
    private func updateOverlay(params: [String: Any], completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            guard let self = self, let container = self.containerView, let previewLayer = self.previewLayer else {
                self?.reject(error: "Overlay not active", completion: completion)
                return
            }

            let x = params["x"] as? CGFloat ?? container.frame.origin.x
            let y = params["y"] as? CGFloat ?? container.frame.origin.y
            let width = params["width"] as? CGFloat ?? container.frame.size.width
            let height = params["height"] as? CGFloat ?? container.frame.size.height
            let cornerRadius = params["cornerRadius"] as? CGFloat ?? previewLayer.cornerRadius

            let newFrame = CGRect(x: x, y: y, width: width, height: height)
            container.frame = newFrame
            previewLayer.frame = container.bounds
            previewLayer.cornerRadius = cornerRadius
            
            self.resolve(["success": true], completion: completion)
        }
    }

    /// 停止覆盖层
    private func stopOverlayInternal() {
        captureSession?.stopRunning()
        captureSession = nil
        
        containerView?.removeFromSuperview()
        containerView = nil
        previewLayer = nil
        
        isFrameTransferEnabled = false
        isFaceTrackingEnabled = false
    }
}

/// 简单的容器视图，用于持有 PreviewLayer
private class OverlayContainerView: UIView {
    init(layer: CALayer) {
        super.init(frame: layer.frame)
        self.layer.addSublayer(layer)
        layer.frame = self.bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
