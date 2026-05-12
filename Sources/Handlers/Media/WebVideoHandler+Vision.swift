//
//  WebVideoHandler+Vision.swift
//  WebBridgeKit
//
//  Vision face/hand tracking extracted from WebVideoHandler.swift
//

import Foundation
import Vision
import WebKit

extension WebVideoHandler {

    func setupFaceDetection() {
        faceDetectionRequest = VNDetectFaceLandmarksRequest { [weak self] request, _ in
            guard let self = self, let results = request.results as? [VNFaceObservation] else { return }
            self.handleFaceDetectionResults(results)
        }
    }

    func handleFaceDetectionResults(_ results: [VNFaceObservation]) {
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
    func setupHandDetection() {
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

    @available(iOS 14.0, *)
    func handleHandDetectionResults(_ results: [VNHumanHandPoseObservation]) {
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
}
