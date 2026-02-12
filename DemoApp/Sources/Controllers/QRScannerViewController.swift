//
//  QRScannerViewController.swift
//  DemoApp
//
//  Created on 2025-02-05.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import AVFoundation
import SnapKit

/// 二维码扫描视图控制器
class QRScannerViewController: UIViewController {

    // MARK: - UI Components

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private let scanRegionView: UIView = {
        let view = UIView()
        view.layer.borderColor = UIColor.systemBlue.cgColor
        view.layer.borderWidth = 2
        view.backgroundColor = .clear
        return view
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        return button
    }()
    
    private let tipLabel: UILabel = {
        let label = UILabel()
        label.text = "将二维码放入框内即可自动扫描"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupScanner()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    // MARK: - Setup

    private func setupScanner() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("❌ [Scanner] Error creating device input: \(error)")
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("❌ [Scanner] Could not add input")
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            print("❌ [Scanner] Could not add output")
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        if let layer = previewLayer {
            view.layer.addSublayer(layer)
        }
    }

    private func setupUI() {
        view.addSubview(scanRegionView)
        view.addSubview(closeButton)
        view.addSubview(tipLabel)
        
        scanRegionView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(250)
        }
        
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.left.equalToSuperview().offset(16)
            make.width.height.equalTo(44)
        }
        
        tipLabel.snp.makeConstraints { make in
            make.top.equalTo(scanRegionView.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
        }
        
        closeButton.addTarget(self, action: #selector(closeAction), for: .touchUpInside)
    }

    @objc private func closeAction() {
        dismiss(animated: true)
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            handleQRCodeResult(stringValue)
        }
    }

    private func handleQRCodeResult(_ result: String) {
        print("✅ [Scanner] Scanned result: \(result)")
        
        var processedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. 尝试 Base64 解码 (处理加密或编码的 URL)
        if let decodedData = Data(base64Encoded: processedResult),
           let decodedString = String(data: decodedData, encoding: .utf8) {
            print("🔓 [Scanner] Base64 decoded: \(decodedString)")
            processedResult = decodedString
        }
        
        // 2. 尝试解析为 URL
        if let url = URL(string: processedResult) {
            dismiss(animated: true) {
                // 发送原始字符串和解析后的 URL，方便后续扩展
                NotificationCenter.default.post(
                    name: .qrScannerDidScanURL,
                    object: url,
                    userInfo: ["rawString": processedResult]
                )
            }
        } else {
            // 如果不是有效 URL，也尝试发送原始字符串，让 MainVC 处理特殊协议
            dismiss(animated: true) {
                NotificationCenter.default.post(
                    name: .qrScannerDidScanURL,
                    object: nil,
                    userInfo: ["rawString": processedResult]
                )
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            self.captureSession.startRunning()
        })
        present(alert, animated: true)
    }
}
