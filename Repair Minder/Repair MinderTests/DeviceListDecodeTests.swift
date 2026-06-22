//
//  DeviceListDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

struct DeviceListDecodeTests {
    let deviceJSON = #"""
    {"id":"cb799d65a4914c568033461482ac16a4","order_id":"80a51962","ticket_id":"5d1ee412","order_number":100000003,"client_first_name":"Test","client_last_name":"Client","display_name":"Test Brand Test Model","serial_number":"TEST123","imei":null,"colour":null,"status":"collected","workflow_type":"repair","device_type":{"id":"b4062cff","name":"Repair","slug":"repair"},"assigned_engineer":null,"location_id":"8000f807","sub_location_id":null,"sub_location":null,"received_at":"2025-12-17T17:20:12.826Z","due_date":"2025-12-20T15:30","created_at":"2025-12-17T17:20:12.826Z","notes":[],"source":"order"}
    """#
    let filtersJSON = #"""
    {"device_types":[{"id":"b4062cff","name":"Repair","slug":"repair"}],"statuses":["collected"],"engineers":[{"id":"1b8e6181","name":"Riki Baker"}],"category_counts":{"repair":10,"buyback":2,"refurb":0,"unassigned":1}}
    """#

    @Test func deviceListItemDecodesIntOrderNumber() throws {
        let item = try RMDecode.decode(DeviceListItem.self, deviceJSON)
        #expect(item.orderNumber?.value == "100000003")
    }
    @Test func filtersDecodeEngineerIdName() throws {
        let f = try RMDecode.decode(DeviceListFilters.self, filtersJSON)
        #expect(f.engineers?.first?.name == "Riki Baker")
        #expect(f.engineers?.first?.id == "1b8e6181")
    }
}
