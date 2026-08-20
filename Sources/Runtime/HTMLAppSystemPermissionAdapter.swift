//
//  HTMLAppSystemPermissionAdapter.swift
//  WebBridgeKit
//
//  Maps HTML app capabilities onto iOS system authorization. The WebBridgeKit
//  panel always comes first; system prompts are triggered only after the user
//  accepts it.
//

import AVFoundation
import CoreBluetooth
import CoreLocation
import Foundation
import Photos
import UserNotifications

public final class HTMLAppSystemPermissionAdapter: HTMLAppNativeAuthorizationProviding {

    public static let shared = HTMLAppSystemPermissionAdapter()

    private let lock = NSLock()
    private var cachedBluetoothState: CBManagerState = .unknown
    private var cachedNotificationStatus: HTMLAppCapabilityResult.Status = .notDetermined
    private var locationManager: CLLocationManager?
    private var bluetoothManager: CBCentralManager?

    public init() {
    }

    /// Warms asynchronous system statuses (notification and bluetooth) so
    /// the synchronous status check used before showing the branded panel is
    /// accurate. Hosts should call it once at container startup.
    public func preloadSystemStatuses() {
        preloadNotificationStatus()
        preloadBluetoothState()
    }

    // MARK: - HTMLAppNativeAuthorizationProviding

    public func authorizationStatus(for capability: HTMLAppCapability) -> HTMLAppCapabilityResult.Status {
        switch capability {
        case .camera, .scan:
            return Self.map(AVCaptureDevice.authorizationStatus(for: .video))
        case .microphone:
            return Self.map(AVCaptureDevice.authorizationStatus(for: .audio))
        case .photoLibrary:
            return Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        case .location:
            return Self.map(CLLocationManager().authorizationStatus)
        case .notification:
            lock.lock()
            defer { lock.unlock() }
            return cachedNotificationStatus
        case .bluetooth:
            lock.lock()
            defer { lock.unlock() }
            switch cachedBluetoothState {
            case .poweredOn:
                return .granted
            case .unauthorized:
                return .denied
            case .unsupported:
                return .restricted
            case .poweredOff, .resetting, .unknown:
                return .notDetermined
            @unknown default:
                return .notDetermined
            }
        case .clipboard, .fileExport, .fileImport, .share:
            // No iOS system authorization gate ahead of the branded panel.
            return .granted
        }
    }

    public func requestAuthorization(
        for capability: HTMLAppCapability,
        completion: @escaping (HTMLAppCapabilityResult.Status) -> Void
    ) {
        switch capability {
        case .camera, .scan:
            requestAV(.video, completion: completion)
        case .microphone:
            requestAV(.audio, completion: completion)
        case .photoLibrary:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                self?.completeOnMain(Self.map(status), completion)
            }
        case .location:
            requestLocation(completion)
        case .notification:
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                let status: HTMLAppCapabilityResult.Status = granted ? .granted : .denied
                self?.storeNotificationStatus(status)
                self?.completeOnMain(status, completion)
            }
        case .bluetooth:
            requestBluetooth(completion)
        case .clipboard, .fileExport, .fileImport, .share:
            completion(.granted)
        }
    }

    // MARK: - System bridges

    private func requestAV(_ mediaType: AVMediaType, completion: @escaping (HTMLAppCapabilityResult.Status) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: mediaType)
        switch status {
        case .authorized:
            completion(.granted)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType) { [weak self] granted in
                self?.completeOnMain(granted ? .granted : .denied, completion)
            }
        case .denied, .restricted:
            completion(Self.map(status))
        @unknown default:
            completion(.notDetermined)
        }
    }

    private func requestLocation(_ completion: @escaping (HTMLAppCapabilityResult.Status) -> Void) {
        let manager = CLLocationManager()
        var fired = false
        let onceLock = NSLock()
        let resolve: (CLAuthorizationStatus) -> Void = { [weak self] status in
            onceLock.lock()
            let alreadyFired = fired
            fired = true
            onceLock.unlock()
            guard !alreadyFired else { return }
            self?.completeOnMain(Self.map(status), completion)
        }

        lock.lock()
        locationManager = manager
        lock.unlock()

        // CLLocationManager has no request callback; the delegate fires for the
        // first prompt and for cached decisions alike.
        let delegate = LocationPermissionDelegate { status in
            resolve(status)
        }
        objc_setAssociatedObject(manager, "wbk.location.delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        manager.delegate = delegate
        manager.requestWhenInUseAuthorization()
    }

    private func requestBluetooth(_ completion: @escaping (HTMLAppCapabilityResult.Status) -> Void) {
        lock.lock()
        let existing = bluetoothManager
        lock.unlock()
        if existing != nil {
            completion(authorizationStatus(for: .bluetooth))
            return
        }
        createBluetoothManagerOnMain(completion: completion)
    }

    private func preloadBluetoothState() {
        lock.lock()
        let existing = bluetoothManager
        lock.unlock()
        guard existing == nil else { return }
        createBluetoothManagerOnMain(completion: nil)
    }

    /// CBCentralManager must be created on a thread with a run loop and its
    /// creation is what surfaces the iOS Bluetooth permission prompt.
    private func createBluetoothManagerOnMain(
        completion: ((HTMLAppCapabilityResult.Status) -> Void)?
    ) {
        let work = { [weak self] in
            guard let self else { return }

            self.lock.lock()
            if let manager = self.bluetoothManager {
                self.lock.unlock()
                completion?(self.authorizationStatus(for: .bluetooth))
                return
            }
            self.lock.unlock()

            let delegate = BluetoothStateDelegate { [weak self] state in
                guard let self else { return }
                self.lock.lock()
                self.cachedBluetoothState = state
                self.lock.unlock()
                completion?(self.authorizationStatus(for: .bluetooth))
            }
            let manager = CBCentralManager(delegate: delegate, queue: .main)
            objc_setAssociatedObject(manager, "wbk.bluetooth.delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            self.lock.lock()
            self.bluetoothManager = manager
            self.lock.unlock()
        }

        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func preloadNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            self?.storeNotificationStatus(Self.mapNotification(settings.authorizationStatus))
        }
    }

    private func storeNotificationStatus(_ status: HTMLAppCapabilityResult.Status) {
        lock.lock()
        cachedNotificationStatus = status
        lock.unlock()
    }

    private func completeOnMain(
        _ status: HTMLAppCapabilityResult.Status,
        _ completion: @escaping (HTMLAppCapabilityResult.Status) -> Void
    ) {
        if Thread.isMainThread {
            completion(status)
        } else {
            DispatchQueue.main.async { completion(status) }
        }
    }

    // MARK: - Status mapping

    private static func map(_ status: AVAuthorizationStatus) -> HTMLAppCapabilityResult.Status {
        switch status {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    private static func map(_ status: PHAuthorizationStatus) -> HTMLAppCapabilityResult.Status {
        switch status {
        case .authorized, .limited: return .granted
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    private static func map(_ status: CLAuthorizationStatus) -> HTMLAppCapabilityResult.Status {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways: return .granted
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    private static func mapNotification(_ status: UNAuthorizationStatus) -> HTMLAppCapabilityResult.Status {
        switch status {
        case .authorized, .provisional, .ephemeral: return .granted
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        @unknown default: return .notDetermined
        }
    }
}

private final class LocationPermissionDelegate: NSObject, CLLocationManagerDelegate {
    private let onChange: (CLAuthorizationStatus) -> Void

    init(onChange: @escaping (CLAuthorizationStatus) -> Void) {
        self.onChange = onChange
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onChange(manager.authorizationStatus)
    }
}

private final class BluetoothStateDelegate: NSObject, CBCentralManagerDelegate {
    private let onUpdate: (CBManagerState) -> Void

    init(onUpdate: @escaping (CBManagerState) -> Void) {
        self.onUpdate = onUpdate
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onUpdate(central.state)
    }
}
