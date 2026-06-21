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
    private var btCont: CheckedContinuation<Bool, Never>?
    private var btManager: CBCentralManager?

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
                locationCont = cont
                mgr.requestWhenInUseAuthorization()
            }
        case .bluetooth:
            if CBCentralManager.authorization != .notDetermined {
                return CBCentralManager.authorization == .allowedAlways
            }
            return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                btCont = cont
                btManager = CBCentralManager(delegate: self, queue: .main)
            }
        }
    }
}

extension PermissionCoordinator: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            guard status != .notDetermined, let cont = self.locationCont else { return }
            self.locationCont = nil
            cont.resume(returning: status == .authorizedWhenInUse || status == .authorizedAlways)
        }
    }
}

extension PermissionCoordinator: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            guard CBCentralManager.authorization != .notDetermined, let cont = self.btCont else { return }
            self.btCont = nil
            cont.resume(returning: CBCentralManager.authorization == .allowedAlways)
        }
    }
}
#endif
