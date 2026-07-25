import Foundation

/// Wire frame the Bridge sends over USB to hand this device its shop pairing token:
/// `magic(4)="RMBR"` + `version(1)=1` + `length(2, big-endian)` + JSON body.
/// Pure decode, no I/O. Bootstrap pairing only — never carries results.
enum DiagnosticsHandshakeFrame {
    static let magic: [UInt8] = Array("RMBR".utf8)
    static let version: UInt8 = 1
    static let maxBody = 2048

    struct Payload: Decodable {
        let token: String
        let shop_name: String?
    }

    /// Parse a complete frame buffer. Returns nil if incomplete, malformed, or oversized.
    static func decode(_ data: Data) -> Payload? {
        let b = [UInt8](data)
        guard b.count >= 7 else { return nil }
        guard Array(b[0..<4]) == magic, b[4] == version else { return nil }
        let len = (Int(b[5]) << 8) | Int(b[6])
        guard len > 0, len <= maxBody, b.count >= 7 + len else { return nil }
        let body = Data(b[7..<(7 + len)])
        return try? JSONDecoder().decode(Payload.self, from: body)
    }
}
