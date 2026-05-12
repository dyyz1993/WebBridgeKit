//
//  WebVideoHandler.swift
//  WebBridgeKit
//
//  Extracted from WebCameraHandler.swift
//

import AVFoundation
import Foundation
import UIKit
import Vision
import WebKit

// 视频流 (New)
public class WebVideoHandler: BaseWebNativeHandler, AVCaptureVideoDataOutputSampleBufferDelegate {

    static var sharedInstance: WebVideoHandler?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var containerView: UIView?

    public override init() {
        super.init()
        WebVideoHandler.sharedInstance = self
    }

    var faceDetectionRequest: VNDetectFaceLandmarksRequest?
    var handPoseRequest: Any?
    private var sequenceHandler = VNSequenceRequestHandler()
    var isFaceTrackingEnabled = false
    var isHandTrackingEnabled = false
    private var isFrameTransferEnabled = false
    private var transferMode: String = "base64"
    private var currentCameraPosition: AVCaptureDevice.Position = .front

    private var frameCount = 0
    private var lastFPSReportTime = Date()

    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
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

    private func toggleFrameTransfer(params: [String: Any], completion: @escaping (Any) -> Void) {
        if let enabled = params["enabled"] as? Bool {
            isFrameTransferEnabled = enabled
        } else {
            isFrameTransferEnabled = !isFrameTransferEnabled
        }
        resolve(["enabled": isFrameTransferEnabled], completion: completion)
    }

    private func startVideo(body: [String: Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? body
        startOverlay(params: params, completion: completion)
    }

    private func stopVideo(completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            self?.stopOverlayInternal()
            self?.resolve(["message": "Video stopped"], completion: completion)
        }
    }

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

    private func startOverlay(params: [String: Any], completion: @escaping (Any) -> Void) {
        print("🎬 [NativeVideo] startOverlay called with params: \(params)")
        runOnMainThread { [weak self] in
            guard let self = self, let webView = self.webView else {
                print("🎬 [NativeVideo] Error: WebView not available")
                self?.reject(error: "WebView not available", completion: completion)
                return
            }

            self.stopOverlayInternal()

            let x = params["x"] as? CGFloat ?? 0
            let y = params["y"] as? CGFloat ?? 0
            let width = params["width"] as? CGFloat ?? 200
            let height = params["height"] as? CGFloat ?? 150
            let cornerRadius = params["cornerRadius"] as? CGFloat ?? 10
            let facingMode = params["facingMode"] as? String ?? "user"
            let isHidden = params["hidden"] as? Bool ?? false

            print("🎬 [NativeVideo] Config: pos=(\(x),\(y)), size=\(width)x\(height), isHidden=\(isHidden)")
            self.currentCameraPosition = (facingMode == "environment") ? .back : .front

            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .medium

            guard let device = self.getDevice(for: self.currentCameraPosition),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                session.commitConfiguration()
                self.reject(error: "Camera not available", completion: completion)
                return
            }
            if session.canAddInput(input) {
                session.addInput(input)
            }

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

            session.commitConfiguration()

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspect
            previewLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
            previewLayer.cornerRadius = cornerRadius
            previewLayer.masksToBounds = true
            previewLayer.isHidden = isHidden

            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if let outputConnection = videoOutput.connection(with: .video), outputConnection.isVideoOrientationSupported {
                outputConnection.videoOrientation = .portrait
                if self.currentCameraPosition == .front && outputConnection.isVideoMirroringSupported {
                    outputConnection.isVideoMirrored = true
                }
            }

            let container = OverlayContainerView(layer: previewLayer)
            container.isHidden = isHidden
            container.isUserInteractionEnabled = false
            container.accessibilityIdentifier = "camera.videoOverlay"

            let scrollX = webView.scrollView.contentOffset.x
            let scrollY = webView.scrollView.contentOffset.y
            container.frame = CGRect(x: x + scrollX, y: y + scrollY, width: width, height: height)

            webView.scrollView.addSubview(container)
            webView.scrollView.bringSubviewToFront(container)

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

    private func getDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices.first { $0.position == position }
    }

    private func switchCamera(completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            guard let self = self, let session = self.captureSession else {
                self?.reject(error: "Session not running", completion: completion)
                return
            }

            session.beginConfiguration()

            if let currentInput = session.inputs.first {
                session.removeInput(currentInput)
            }

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

    func sendNativeLogToJS(_ message: String) {
        runOnMainThread { [weak self] in
            let script = "console.log('🍎 [NativeLog] \(message)');"
            self?.webView?.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
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

class OverlayContainerView: UIView {
    init(layer: CALayer) {
        super.init(frame: layer.frame)
        self.layer.addSublayer(layer)
        layer.frame = self.bounds
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
