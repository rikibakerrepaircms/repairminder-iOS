import XCTest
@testable import Repair_Minder

final class DiagnosticsHandshakeFrameTests: XCTestCase {
    private func frame(_ json: String, magic: [UInt8] = Array("RMBR".utf8), version: UInt8 = 1) -> Data {
        let body = Array(json.utf8)
        var d = Data(magic)
        d.append(version)
        d.append(UInt8((body.count >> 8) & 0xff))
        d.append(UInt8(body.count & 0xff))
        d.append(contentsOf: body)
        return d
    }

    func testDecodesValidFrame() {
        let p = DiagnosticsHandshakeFrame.decode(frame(#"{"token":"abc","shop_name":"Acme"}"#))
        XCTAssertEqual(p?.token, "abc")
        XCTAssertEqual(p?.shop_name, "Acme")
    }

    func testDecodesWithoutShopName() {
        let p = DiagnosticsHandshakeFrame.decode(frame(#"{"token":"abc"}"#))
        XCTAssertEqual(p?.token, "abc")
        XCTAssertNil(p?.shop_name)
    }

    func testRejectsBadMagic() {
        XCTAssertNil(DiagnosticsHandshakeFrame.decode(frame(#"{"token":"x"}"#, magic: Array("XXXX".utf8))))
    }

    func testRejectsBadVersion() {
        XCTAssertNil(DiagnosticsHandshakeFrame.decode(frame(#"{"token":"x"}"#, version: 2)))
    }

    func testRejectsIncomplete() {
        let full = frame(#"{"token":"abc"}"#)
        XCTAssertNil(DiagnosticsHandshakeFrame.decode(full.prefix(5)))
    }

    func testRejectsOversizedLength() {
        var d = Data(Array("RMBR".utf8))
        d.append(1)
        d.append(0xff); d.append(0xff) // declared length 65535 > maxBody
        d.append(contentsOf: Array(#"{"token":"a"}"#.utf8))
        XCTAssertNil(DiagnosticsHandshakeFrame.decode(d))
    }
}
