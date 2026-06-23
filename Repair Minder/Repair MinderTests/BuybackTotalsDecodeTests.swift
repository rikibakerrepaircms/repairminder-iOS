import Testing
import Foundation
@testable import Repair_Minder

struct BuybackTotalsDecodeTests {
    @Test func totalsDecodeLabourFields() throws {
        let json = #"""
        {"refurbishment_cost":40,"labour_cost":15,"repair_minutes":30,"labour_rate":30,"total_cost":55,"profit":20,"vat_liability":5}
        """#
        let t = try RMDecode.decode(BuybackTotals.self, json)
        #expect(t.labourCost == 15)
        #expect(t.repairMinutes == 30)
        #expect(t.labourRate == 30)
    }
    @Test func salvageBudgetDecodes() throws {
        let json = #"{"cap":100,"booked":40,"remaining":60}"#
        let b = try RMDecode.decode(SalvageBudget.self, json)
        #expect(b.remaining == 60)
    }
}
