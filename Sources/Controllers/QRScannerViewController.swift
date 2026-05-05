//
//  QRScannerViewController.swift
//  WebBridgeKit
//
//  Created on 2026-01-16.
//

import Foundation
import AVFoundation
import RxCocoa
import RxSwift
import UIKit

/// 二维码扫描视图控制器
public class QRScannerViewController: UIViewController {

    // MARK: - Properties

    public let scannerDidSuccess = PublishRelay<String>()

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let disposeBag = DisposeBag()

    // MARK: - UI Components

    private let previewView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()

    // MARK: - Lifecycle

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startScanning()
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .black
        view.addSubview(previewView)
        previewView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupCamera() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(previewLayer!)
    }

    // MARK: - Scanning

    private func startScanning() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .background).async {
                self.captureSession.startRunning()
            }
        }
    }

    private func stopScanning() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        stopScanning()

        if let metadataObject = metadataObjects.first {
            let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject

            if let stringValue = readableObject?.stringValue {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                scannerDidSuccess.accept(stringValue)

                DispatchQueue.main.async { [weak self] in
                    self?.dismiss(animated: true)
                }
            }
        }
    }
}
