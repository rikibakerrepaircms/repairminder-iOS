import Testing
import Foundation
@testable import Repair_Minder

struct OrderItemNullTotalsTests {
    private func decoder() -> JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }
    @Test func itemWithNullTotalsDecodes() throws {
        let json = #"{"id":"item-1","description":"Screen Replacement","quantity":1,"unit_price":99.99,"vat_rate":20.0,"line_total":null,"vat_amount":null,"line_total_inc_vat":null}"#.data(using: .utf8)!
        _ = try decoder().decode(OrderItem.self, from: json)
    }
}
