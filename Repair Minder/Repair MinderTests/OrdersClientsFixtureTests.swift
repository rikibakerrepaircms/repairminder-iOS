import Testing
import Foundation
@testable import Repair_Minder

struct OrdersClientsFixtureTests {
    @Test func orderItemDecodes() throws {
        let json = #"""
        {"id":"35ef7bbe","item_type":"repair","description":"Screen replacement","quantity":1,"unit_price":149.99,"vat_rate":20,"line_total":149.99,"vat_amount":30,"line_total_inc_vat":179.99,"device_id":"df5f7829","created_at":"2026-02-02 18:35:43","authorization_status":"pending","authorization_round":1}
        """#
        let item = try RMDecode.decode(OrderItem.self, json)
        #expect(item.lineTotalIncVat == 179.99)
        #expect(item.vatRate == 20)
    }
    @Test func clientListRowDecodes() throws {
        let json = #"""
        {"id":"53f696e9","email":"test@example.com","first_name":"Test","last_name":"Client","ticket_count":2,"order_count":1,"total_spend":0}
        """#
        let c = try RMDecode.decode(Client.self, json)
        #expect(c.email == "test@example.com")
        #expect(c.orderCount == 1)
    }
}
