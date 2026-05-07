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

    private var faceDetectionRequest: VNDetectFaceLandmarksRequest?
    private var handPoseRequest: Any?
    private var sequenceHandler = VNSequenceRequestHandler()
    private var isFaceTrackingEnabled = false
    private var isHandTrackingEnabled = false
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

    private func setupFaceDetection() {
        faceDetectionRequest = VNDetectFaceLandmarksRequest { [weak self] request, _ in
            guard let self = self, let results = request.results as? [VNFaceObservation] else { return }
            self.handleFaceDetectionResults(results)
        }
    }

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

                if let outerLips = landmarks.outerLips?.normalizedPoints {
                    let top = outerLips[2].y
                    let bottom = outerLips[8].y
                    let mouthOpen = abs(top - bottom) > 0.15
                    faceDict["mouthOpen"] = mouthOpen
                }
            }

            var leftEyeClosed = false
            var rightEyeClosed = false

            if let landmarks = observation.landmarks {
                if let leftEyePoints = landmarks.leftEye?.normalizedPoints, leftEyePoints.count >= 6 {
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
                    leftEyeClosed = ear < 0.2
                }

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

    private func sendNativeLogToJS(_ message: String) {
        runOnMainThread { [weak self] in
            let script = "console.log('🍎 [NativeLog] \(message)');"
            self?.webView?.evaluateJavaScript(script, completionHandler: nil)
        }
    }

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
                    if key.contains("wrist") { shortKey = "wrist" } else if key.contains("thumb") {
                        if key.contains("cmc") { shortKey = "thumbCMC" } else if key.contains("mp") { shortKey = "thumbMP" } else if key.contains("ip") { shortKey = "thumbIP" } else if key.contains("tip") { shortKey = "thumbTip" }
                    } else if key.contains("index") {
                        if key.contains("mcp") { shortKey = "indexMCP" } else if key.contains("pip") { shortKey = "indexPIP" } else if key.contains("dip") { shortKey = "indexDIP" } else if key.contains("tip") { shortKey = "indexTip" }
                    } else if key.contains("middle") {
                        if key.contains("mcp") { shortKey = "middleMCP" } else if key.contains("pip") { shortKey = "middlePIP" } else if key.contains("dip") { shortKey = "middleDIP" } else if key.contains("tip") { shortKey = "middleTip" }
                    } else if key.contains("ring") {
                        if key.contains("mcp") { shortKey = "ringMCP" } else if key.contains("pip") { shortKey = "ringPIP" } else if key.contains("dip") { shortKey = "ringDIP" } else if key.contains("tip") { shortKey = "ringTip" }
                    } else if key.contains("little") {
                        if key.contains("mcp") { shortKey = "littleMCP" } else if key.contains("pip") { shortKey = "littlePIP" } else if key.contains("dip") { shortKey = "littleDIP" } else if key.contains("tip") { shortKey = "littleTip" }
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
