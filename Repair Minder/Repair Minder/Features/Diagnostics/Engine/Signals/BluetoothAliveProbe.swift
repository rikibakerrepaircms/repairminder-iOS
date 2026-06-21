// Features/Diagnostics/Engine/Signals/BluetoothAliveProbe.swift
#if os(iOS)
import Foundation
import CoreBluetooth

/// Brief "is the Bluetooth radio powered on" check for pre-flight. Resolves `true` on `.poweredOn`,
/// `false` on a clearly-unusable state (off / unauthorized / unsupported) or after the timeout.
/// Permission is requested up front by PermissionCoordinator, so creating the manager here won't
/// re-prompt.
@MainActor
final class BluetoothAliveProbe: NSObject, CBCentralManagerDelegate {
    private var manager: CBCentralManager?
    private var cont: CheckedContinuation<Bool, Never>?
    private var settled = false

    func poweredOn(timeoutMs: Int) async -> Bool {
        await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            cont = c
            manager = CBCentralManager(delegate: self, queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(timeoutMs) / 1000.0) { [weak self] in
                self?.settle(false)
            }
        }
    }

    private func settle(_ value: Bool) {
        guard !settled else { return }
        settled = true
        manager = nil
        let c = cont; cont = nil
        c?.resume(returning: value)
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn: self.settle(true)
            case .poweredOff, .unauthorized, .unsupported: self.settle(false)
            default: break   // .unknown / .resetting — wait for the next update or the timeout
            }
        }
    }
}
#endif
