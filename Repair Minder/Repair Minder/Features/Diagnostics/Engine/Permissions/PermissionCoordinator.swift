// Features/Diagnostics/Engine/Permissions/PermissionCoordinator.swift
#if os(iOS)
import Foundation
import AVFoundation
import CoreLocation
import CoreBluetooth

/// Requests the union of permissions for the selected tests up front, sequentially, so the tech
/// isn't interrupted by system prompts mid-flow. Results land in `granted` for the denied-warning UI;
/// tests still handle their own denied state at run time.
@MainActor
final class PermissionCoordinator: NSObject, ObservableObject {
    @Published private(set) var granted: [DiagnosticPermission: Bool] = [:]
    @Published private(set) var inFlight: DiagnosticPermission?
    @Published private(set) var finished = false

    private var locationCont: CheckedContinuation<Bool, Never>?
    private var locationManager: CLLocationManager?
    private var locationSettled = false
    private var btCont: CheckedContinuation<Bool, Never>?
    private var btManager: CBCentralManager?
    private var btSettled = false

    /// How long to wait for a delegate callback before assuming the system silently denied/failed.
    private let permissionTimeoutMs = 8000

    private func settleLocation(_ value: Bool) {
        guard !locationSettled else { return }
        locationSettled = true
        locationManager = nil
        let c = locationCont; locationCont = nil
        c?.resume(returning: value)
    }
    private func settleBluetooth(_ value: Bool) {
        guard !btSettled else { return }
        btSettled = true
        btManager = nil
        let c = btCont; btCont = nil
        c?.resume(returning: value)
    }

    /// Request the given permissions in a stable order: camera → microphone → location → bluetooth.
    func request(_ perms: Set<DiagnosticPermission>) async {
        for p in [DiagnosticPermission.camera, .microphone, .location, .bluetooth] where perms.contains(p) {
            inFlight = p
            granted[p] = await request(p)
        }
        inFlight = nil
        finished = true
    }

    private func request(_ p: DiagnosticPermission) async -> Bool {
        switch p {
        case .camera:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .microphone:
            return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioApplication.requestRecordPermission { ok in cont.resume(returning: ok) }
            }
        case .location:
            let mgr = CLLocationManager()
            locationManager = mgr
            mgr.delegate = self
            let status = mgr.authorizationStatus
            if status != .notDetermined {
                return status == .authorizedWhenInUse || status == .authorizedAlways
            }
            return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                locationSettled = false
                locationCont = cont
                mgr.requestWhenInUseAuthorization()
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(permissionTimeoutMs) / 1000.0) { [weak self] in
                    self?.settleLocation(false)
                }
            }
        case .bluetooth:
            if CBCentralManager.authorization != .notDetermined {
                return CBCentralManager.authorization == .allowedAlways
            }
            return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                btSettled = false
                btCont = cont
                btManager = CBCentralManager(delegate: self, queue: .main)
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(permissionTimeoutMs) / 1000.0) { [weak self] in
                    self?.settleBluetooth(false)
                }
            }
        }
    }
}

extension PermissionCoordinator: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            guard status != .notDetermined else { return }
            self.settleLocation(status == .authorizedWhenInUse || status == .authorizedAlways)
        }
    }
}

extension PermissionCoordinator: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            guard CBCentralManager.authorization != .notDetermined else { return }
            self.settleBluetooth(CBCentralManager.authorization == .allowedAlways)
        }
    }
}
#endif
