#if os(iOS)
import Foundation
import Darwin

/// Loopback (127.0.0.1) TCP listener the in-shop Bridge connects to over USB
/// (usbmux) to hand this device its shop pairing token.
///
/// Loopback binding is deliberate: usbmux delivers its `Connect` to `127.0.0.1`
/// on the device, and a loopback peer is exempt from iOS Local Network privacy —
/// so this needs no `NSLocalNetworkUsageDescription`, no entitlement, and shows no
/// permission prompt. Started while the app is foregrounded.
///
/// Latest-handshake-wins (B1): the listener stays open for as long as the app is
/// foregrounded and RE-PAIRS whenever a DIFFERENT token arrives — the bench's
/// current per-device token always wins over a stale/inherited one (e.g. a device
/// that inherited another device's token via a backup/restore). It no-ops when the
/// incoming token is identical to the one already stored. Manual shop-code pairing
/// (`DiagnosticsShopPairing.pair`) is untouched by this file. Carries ONLY the
/// pairing token — results continue on the existing masked-proxy path once the app
/// has paired and a run opens its live session.
@MainActor
final class DiagnosticsBridgeHandshake {
    static let shared = DiagnosticsBridgeHandshake()
    static let port: UInt16 = 50710

    private var listenFD: Int32 = -1

    /// Bind 127.0.0.1:50710 and accept on a background thread. No-op if already
    /// listening. Listens regardless of current pairing state — an already-paired
    /// device still needs to hear the next handshake in case a DIFFERENT bench's
    /// token should take over (B1). A bind/listen failure is swallowed (silent
    /// fallback to manual pairing).
    func start() {
        guard listenFD < 0 else { return }

        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Self.port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1") // loopback only
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0, listen(fd, 1) == 0 else { close(fd); return }
        listenFD = fd

        Thread.detachNewThread {
            DiagnosticsBridgeHandshake.acceptLoop(fd)
        }
    }

    /// Stop listening. Closing the socket unblocks a pending accept().
    func stop() {
        if listenFD >= 0 {
            close(listenFD)
            listenFD = -1
        }
    }

    // Off-main (nonisolated so the blocking accept()/recv() never runs on the main
    // actor). Accepts connections for as long as the listen fd stays open — every
    // decoded handshake is applied (re-pair on a different token, no-op on an
    // identical one), so a new bench can always re-pair this device. Exits only
    // when the listen fd is closed by stop().
    nonisolated private static func acceptLoop(_ fd: Int32) {
        while true {
            let client = accept(fd, nil, nil)
            if client < 0 { return } // listen fd closed by stop()
            var buf = [UInt8]()
            var chunk = [UInt8](repeating: 0, count: 1024)
            while buf.count < 8192 {
                let n = recv(client, &chunk, chunk.count, 0)
                if n <= 0 { break } // EOF or error
                buf.append(contentsOf: chunk[0..<n])
                if let payload = DiagnosticsHandshakeFrame.decode(Data(buf)) {
                    let token = payload.token
                    let name = payload.shop_name
                    Task { @MainActor in
                        DiagnosticsBridgeHandshake.shared.apply(token: token, name: name)
                    }
                    break
                }
            }
            close(client)
            // Keep listening for the NEXT handshake (do not return) — this is what
            // makes latest-handshake-wins possible.
        }
    }

    /// Apply an incoming handshake. Re-pairs when `token` differs from the one
    /// already stored (the bench's current per-device token wins over a
    /// stale/inherited one); no-ops when identical. Internal (not `private`) so
    /// `DiagnosticsBridgeHandshakeTests` can drive it directly without sockets.
    func apply(token: String, name: String?) {
        guard token != DiagnosticsShopPairing.token else { return }
        DiagnosticsShopPairing.pairWithToken(token, name: name)
        // Confirm recognition to the operator with a transient banner, on EVERY
        // change of pairing (first pair AND re-pair onto a different shop).
        let display = (name?.isEmpty == false) ? name : DiagnosticsShopPairing.companyName
        ShopPairingBanner.shared.show(shopName: display)
    }
}
#endif
