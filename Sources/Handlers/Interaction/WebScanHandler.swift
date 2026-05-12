//
//  WebScanHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import AVFoundation
import Foundation
import UIKit
import WebKit
import Vision

// Framework imports

/// 扫码功能处理器
public class WebScanHandler: BaseWebNativeHandler {

    /// 处理扫码请求
    /// - Parameters:
    ///   - body: 请求参数字典
    ///   - completion: 结果回调
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            self?.scanQRCode { result in
                switch result {
                case .success(let code):
                    self?.resolve(["code": code, "type": "qr"], completion: completion)
                case .failure(let error):
                    self?.reject(error: error.localizedDescription, completion: completion)
                }
            }
        }
    }

    private func scanQRCode(completion: @escaping (Result<String, Error>) -> Void) {
        checkCameraPermission { [weak self] granted in
            if granted {
                self?.showScanViewController(completion: completion)
            } else {
                completion(.failure(NSError(domain: "WebScanHandler", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "需要相机权限才能扫码"
                ])))
            }
        }
    }

    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }

    private func showScanViewController(completion: @escaping (Result<String, Error>) -> Void) {
        guard let topVC = self.topViewController else {
            completion(.failure(NSError(domain: "WebScanHandler", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "无法显示扫码界面"
            ])))
            return
        }

        let scanVC = QRScanViewController(completion: completion)
        let navVC = UINavigationController(rootViewController: scanVC)
        navVC.modalPresentationStyle = .fullScreen

        topVC.present(navVC, animated: true)
    }
}

// MARK: - QR Scan View Controller

private class QRScanViewController: UIViewController {
    private let completion: (Result<String, Error>) -> Void

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var scanLine: UIView?

    init(completion: @escaping (Result<String, Error>) -> Void) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        // 设置导航栏
        navigationItem.title = "扫描二维码"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        setupCamera()
        setupScanOverlay()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        captureSession?.startRunning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        captureSession = session

        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            completion(.failure(NSError(domain: "QRScanViewController", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "无法访问相机"
            ])))
            return
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            completion(.failure(error))
            return
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            completion(.failure(NSError(domain: "QRScanViewController", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "无法添加相机输入"
            ])))
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417]
        } else {
            completion(.failure(NSError(domain: "QRScanViewController", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "无法添加元数据输出"
            ])))
            return
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer

        session.sessionPreset = .photo
    }

    private func setupScanOverlay() {
        // 创建扫描框
        let scanFrameSize: CGFloat = 250
        let scanFrame = UIView(frame: CGRect(
            x: (view.bounds.width - scanFrameSize) / 2,
            y: (view.bounds.height - scanFrameSize) / 2,
            width: scanFrameSize,
            height: scanFrameSize
        ))
        scanFrame.layer.borderColor = ThemeTokens.Color.success.cgColor
        scanFrame.layer.borderWidth = 2
        scanFrame.layer.cornerRadius = ThemeTokens.CornerRadius.md
        view.addSubview(scanFrame)

        // 创建扫描线动画
        let scanLine = UIView(frame: CGRect(
            x: 0,
            y: 0,
            width: scanFrameSize,
            height: 2
        ))
        scanLine.backgroundColor = ThemeTokens.Color.success
        scanFrame.addSubview(scanLine)
        self.scanLine = scanLine

        // 添加提示文字
        let label = UILabel()
        label.text = "将二维码放入框内即可自动扫描"
        label.textColor = .white
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        label.frame = CGRect(
            x: 20,
            y: scanFrame.frame.maxY + 20,
            width: view.bounds.width - 40,
            height: 30
        )
        view.addSubview(label)

        // 扫描线动画
        UIView.animate(withDuration: 1.5, delay: 0, options: [.repeat, .autoreverse]) {
            self.scanLine?.frame.origin.y = scanFrameSize - 2
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true) { [weak self] in
            self?.completion(.failure(NSError(domain: "QRScanViewController", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "用户取消"
            ])))
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScanViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }

        // 找到扫描结果的边界
        guard let previewLayer = previewLayer,
              let barCodeObject = previewLayer.transformedMetadataObject(for: metadataObject) as? AVMetadataMachineReadableCodeObject else {
            return
        }

        // 验证二维码在扫描框内
        let scanFrame = view.bounds.insetBy(dx: (view.bounds.width - 250) / 2, dy: (view.bounds.height - 250) / 2)
        let codeBounds = barCodeObject.bounds

        if scanFrame.contains(codeBounds) {
            // 停止扫描并返回结果
            captureSession?.stopRunning()
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

            dismiss(animated: true) { [weak self] in
                self?.completion(.success(stringValue))
            }
        }
    }
}
