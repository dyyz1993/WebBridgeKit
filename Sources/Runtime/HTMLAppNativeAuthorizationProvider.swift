//
//  HTMLAppNativeAuthorizationProvider.swift
//  WebBridgeKit
//

import AVFoundation
import Contacts
import CoreBluetooth
import CoreLocation
import Foundation
import Photos

/// Reads the current iOS authorization layer. It never displays a system
/// prompt; the protected handler remains responsible for requesting iOS access
/// after the PWA-specific grant has been approved.
public final class HTMLAppSystemAuthorizationProvider: HTMLAppNativeAuthorizationProviding {
    public init() {}

    public func authorizationStatus(for capability: HTMLAppCapability) -> HTMLAppCapabilityResult.Status {
        switch capability {
        case .biometrics, .deviceControl, .displayStatus, .motion:
            // These handlers provide their own availability or system prompt.
            return .granted
        case .camera, .scan:
            return status(AVCaptureDevice.authorizationStatus(for: .video))
        case .microphone:
            return status(AVCaptureDevice.authorizationStatus(for: .audio))
        case .location:
            return status(CLLocationManager().authorizationStatus)
        case .contacts:
            return status(CNContactStore.authorizationStatus(for: .contacts))
        case .photoLibrary:
            return status(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        case .bluetooth:
            if #available(iOS 13.1, *) {
                switch CBManager.authorization {
                case .allowedAlways: return .granted
                case .denied: return .denied
                case .restricted: return .restricted
                case .notDetermined: return .notDetermined
                @unknown default: return .unavailable
                }
            }
            return .notDetermined
        case .clipboard, .fileExport, .fileImport, .notification, .share:
            // Notification status is asynchronous. The native handler performs
            // the final system-layer check just before the operation.
            return .granted
        }
    }

    private func status(_ value: AVAuthorizationStatus) -> HTMLAppCapabilityResult.Status {
        switch value {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .unavailable
        }
    }

    private func status(_ value: CLAuthorizationStatus) -> HTMLAppCapabilityResult.Status {
        switch value {
        case .authorizedAlways, .authorizedWhenInUse: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .unavailable
        }
    }

    private func status(_ value: CNAuthorizationStatus) -> HTMLAppCapabilityResult.Status {
        switch value {
        case .authorized, .limited: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .unavailable
        }
    }

    private func status(_ value: PHAuthorizationStatus) -> HTMLAppCapabilityResult.Status {
        switch value {
        case .authorized, .limited: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .unavailable
        }
    }
}
