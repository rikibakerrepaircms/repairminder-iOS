import Testing
import Foundation
@testable import Repair_Minder

struct CustomerOrderListCurrencyTests {
    private func decoder() -> JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }
    @Test func currencyCodeDecodes() throws {
        let json = #"{"success":true,"currency_code":"EUR","data":[]}"#.data(using: .utf8)!
        let r = try decoder().decode(CustomerOrdersAPIResponse.self, from: json)
        #expect(r.currencyCode == "EUR")
    }
}
