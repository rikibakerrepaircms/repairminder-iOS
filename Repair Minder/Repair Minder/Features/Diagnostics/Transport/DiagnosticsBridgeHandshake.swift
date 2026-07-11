#if os(iOS)
import Foundation
import Network

extension Notification.Name {
    /// Posted when the device pairs to a shop via the Bridge USB handshake, so an
    /// in-progress run can open its live session immediately.
    static let diagnosticsDidPair = Notification.Name("diagnosticsDidPair")
}

/// Loopback listener the in-shop Bridge connects to over USB (usbmux) to hand this
/// device its shop pairing token. Started while the app is foregrounded; one-time
/// consume. Never touches the result transport — it only pairs, after which the
/// existing run flow opens the live session over the masked proxy.
@MainActor
final class DiagnosticsBridgeHandshake {
    static let shared = DiagnosticsBridgeHandshake()
    static let port: NWEndpoint.Port = 50710

    private var listener: NWListener?
    private var buffers: [ObjectIdentifier: Data] = [:]

    /// Begin listening on 127.0.0.1:50710. No-op if already listening or already
    /// token-paired. A bind failure is swallowed (silent fallback to manual pairing).
    func start() {
        guard listener == nil else { return }
        guard DiagnosticsShopPairing.token == nil else { return }
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: Self.port)
        guard let l = try? NWListener(using: params, on: Self.port) else { return }
        l.newConnectionHandler = { [weak self] conn in
            Task { @MainActor in self?.accept(conn) }
        }
        l.start(queue: .main)
        listener = l
    }

    func stop() {
        listener?.cancel()
        listener = nil
        buffers.removeAll()
    }

    private func accept(_ conn: NWConnection) {
        conn.start(queue: .main)
        receive(conn)
    }

    private func receive(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, _ in
            Task { @MainActor in
                guard let self else { return }
                let key = ObjectIdentifier(conn)
                if let data, !data.isEmpty {
                    var buf = self.buffers[key] ?? Data()
                    buf.append(data)
                    if buf.count > 8192 { // bound — never buffer unboundedly
                        conn.cancel(); self.buffers[key] = nil; return
                    }
                    self.buffers[key] = buf
                    if let payload = DiagnosticsHandshakeFrame.decode(buf) {
                        self.apply(payload)
                        conn.cancel()
                        self.buffers[key] = nil
                        return
                    }
                }
                if isComplete {
                    conn.cancel(); self.buffers[key] = nil
                } else {
                    self.receive(conn)
                }
            }
        }
    }

    private func apply(_ p: DiagnosticsHandshakeFrame.Payload) {
        guard DiagnosticsShopPairing.token == nil else { return }
        DiagnosticsShopPairing.pairWithToken(p.token, name: p.shop_name)
        stop() // one-time consume
        NotificationCenter.default.post(name: .diagnosticsDidPair, object: nil)
    }
}
#endif
