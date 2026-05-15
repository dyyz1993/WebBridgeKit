//
//  QRScannerViewController.swift
//  WebBridgeKit
//
//  Created on 2026-01-16.
//

import AVFoundation
import RxCocoa
import RxSwift
import SnapKit
import UIKit

extension QRScannerViewController {
    public struct Configuration {
        public var showScanRegionOverlay: Bool
        public var scanRegionSize: CGFloat
        public var scanRegionBorderColor: UIColor
        public var showCloseButton: Bool
        public var tipText: String?
        public var enableBase64Decoding: Bool
        public var autoDismiss: Bool

        public init(
            showScanRegionOverlay: Bool = false,
            scanRegionSize: CGFloat = 250,
            scanRegionBorderColor: UIColor = ThemeTokens.Color.primary,
            showCloseButton: Bool = false,
            tipText: String? = nil,
            enableBase64Decoding: Bool = false,
            autoDismiss: Bool = true
        ) {
            self.showScanRegionOverlay = showScanRegionOverlay
            self.scanRegionSize = scanRegionSize
            self.scanRegionBorderColor = scanRegionBorderColor
            self.showCloseButton = showCloseButton
            self.tipText = tipText
            self.enableBase64Decoding = enableBase64Decoding
            self.autoDismiss = autoDismiss
        }
    }
}

public class QRScannerViewController: UIViewController {

    // MARK: - Properties

    public let scannerDidSuccess = PublishRelay<String>()
    public let configuration: Configuration

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let disposeBag = DisposeBag()

    // MARK: - UI Components

    private let previewView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()

    private lazy var scanRegionView: UIView = {
        let view = UIView()
        view.layer.borderColor = configuration.scanRegionBorderColor.cgColor
        view.layer.borderWidth = 2
        view.backgroundColor = .clear
        return view
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(LucideIcon.xmarkCircle.templateImage(pointSize: 24, weight: .medium), for: .normal)
        button.tintColor = .white
        return button
    }()

    private lazy var tipLabel: UILabel = {
        let label = UILabel()
        label.text = configuration.tipText
        label.textColor = .white
        label.font = ThemeTokens.Typography.footnote
        label.textAlignment = .center
        return label
    }()

    // MARK: - Init

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.configuration = Configuration()
        super.init(coder: coder)
    }

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

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .black
        view.addSubview(previewView)
        previewView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        if configuration.showScanRegionOverlay {
            view.addSubview(scanRegionView)
            scanRegionView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalTo(configuration.scanRegionSize)
            }
        }

        if configuration.showCloseButton {
            view.addSubview(closeButton)
            closeButton.snp.makeConstraints { make in
                make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
                make.left.equalToSuperview().offset(16)
                make.width.height.equalTo(44)
            }
            closeButton.addTarget(self, action: #selector(closeAction), for: .touchUpInside)
        }

        if let tipText = configuration.tipText, !tipText.isEmpty {
            view.addSubview(tipLabel)
            tipLabel.snp.makeConstraints { make in
                if configuration.showScanRegionOverlay {
                    make.top.equalTo(scanRegionView.snp.bottom).offset(24)
                } else {
                    make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-40)
                }
                make.centerX.equalToSuperview()
            }
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
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    private func stopScanning() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    // MARK: - Actions

    @objc private func closeAction() {
        if navigationController != nil {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - Result Processing

    private func processScannedResult(_ rawValue: String) -> String {
        var result = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if configuration.enableBase64Decoding,
           let decodedData = Data(base64Encoded: result),
           let decodedString = String(data: decodedData, encoding: .utf8) {
            result = decodedString
        }

        return result
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        stopScanning()

        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let rawValue = readableObject.stringValue else { return }

        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

        let processedResult = processScannedResult(rawValue)
        scannerDidSuccess.accept(processedResult)
    }
}
