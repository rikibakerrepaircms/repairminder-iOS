import Foundation

/// Consumes a pairing file dropped into the app container by the Bridge at silent-install time
/// (Approach A — container-file drop). On launch, if `pairing.json` is present, pair this device
/// to the shop via DiagnosticsShopPairing, then delete the file (one-time consume).
///
/// Shape: { "token": "<64-hex>", "shop_name": "Acme Repairs", "issued_at": "2026-06-23T..." }
enum DiagnosticsPairingFile {
    /// The file the Bridge writes into the app's Documents container.
    static var url: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("pairing.json")
    }

    private struct Payload: Decodable { let token: String; let shop_name: String? }

    /// Read + apply + delete. Safe to call on every launch; no-op if absent or malformed.
    @discardableResult
    static func consumeIfPresent(_ fileURL: URL? = nil) -> Bool {
        let target = fileURL ?? url
        guard let data = try? Data(contentsOf: target) else { return false }
        defer { try? FileManager.default.removeItem(at: target) }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              !payload.token.isEmpty else { return false }
        DiagnosticsShopPairing.pairWithToken(payload.token, name: payload.shop_name)
        return true
    }
}
