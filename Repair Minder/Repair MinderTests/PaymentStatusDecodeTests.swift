import Testing
import Foundation
@testable import Repair_Minder

struct PaymentStatusDecodeTests {
    private func decoder() -> JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }
    @Test func unknownPaymentStatusFallsBack() throws {
        let v = try decoder().decode(PaymentStatus.self, from: #""void""#.data(using: .utf8)!)
        #expect(v == PaymentStatus.unknownFallback)
    }
}
