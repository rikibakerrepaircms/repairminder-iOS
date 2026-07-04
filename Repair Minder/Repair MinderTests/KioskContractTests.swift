import XCTest
@testable import Repair_Minder

final class KioskContractTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func testDecodeKioskOrderResponseWithPayment() throws {
        let json = """
        {
          "id": "order-uuid",
          "order_number": 100000001,
          "ticket_id": "ticket-uuid",
          "client": { "id": "c1", "email": "j@x.com", "first_name": "Jane", "last_name": "Doe", "phone": "+44" },
          "items": [{
            "id": "i1", "item_type": "accessory", "description": "Screen",
            "quantity": 1, "unit_price": 89.99, "vat_rate": 20,
            "line_total": 79.99, "vat_amount": 16.0, "line_total_inc_vat": 95.99,
            "discount_percent": null, "discount_amount": 10.0, "discount_reason": "box",
            "product_type_id": "pt1", "product_sku": "SCRN"
          }],
          "totals": {
            "subtotal": 74.99, "vat_total": 15.0, "grand_total": 89.99,
            "discount_total": 15.0, "global_discount": 5.0, "amount_paid": 84.99, "balance_due": 5.0
          },
          "payment": { "id": "p1", "amount": 84.99, "payment_method": "cash", "payment_date": "2026-07-04" },
          "global_discount_percent": null, "global_discount_amount": 5.0, "global_discount_reason": "Loyalty",
          "company": null, "location": null,
          "dates": { "created_at": "2026-07-04T10:15:30.000Z" }
        }
        """.data(using: .utf8)!

        let order = try decoder().decode(KioskOrderResponse.self, from: json)
        XCTAssertEqual(order.id, "order-uuid")
        XCTAssertEqual(order.orderNumber, 100000001)
        XCTAssertEqual(order.totals.grandTotal, 89.99, accuracy: 0.001)
        XCTAssertEqual(order.payment?.paymentMethod, "cash")
        let firstItem = try XCTUnwrap(order.items.first)
        XCTAssertEqual(firstItem.lineTotalIncVat, 95.99, accuracy: 0.001)
    }

    func testDecodeKioskOrderResponseNoPayment() throws {
        let json = """
        { "id": "o", "order_number": 1, "ticket_id": "t",
          "client": { "id": "c", "email": null, "first_name": null, "last_name": null, "phone": null },
          "items": [],
          "totals": { "subtotal": 0, "vat_total": 0, "grand_total": 10.0, "discount_total": 0, "global_discount": 0, "amount_paid": 0, "balance_due": 10.0 },
          "payment": null, "global_discount_percent": null, "global_discount_amount": null, "global_discount_reason": null,
          "company": null, "location": null, "dates": { "created_at": "2026-07-04T10:15:30.000Z" } }
        """.data(using: .utf8)!
        let order = try decoder().decode(KioskOrderResponse.self, from: json)
        XCTAssertNil(order.payment)
        XCTAssertEqual(order.totals.balanceDue, 10.0, accuracy: 0.001)
    }

    func testDecodeAvailableAssets() throws {
        let json = """
        [{ "id": "a1", "name": "Screen", "asset_tag": "AST-1", "cost": 42.5,
           "serial_number": "SN1", "location_name": "Main", "sub_location": "A3" }]
        """.data(using: .utf8)!
        let assets = try decoder().decode([KioskAvailableAsset].self, from: json)
        XCTAssertEqual(assets.first?.id, "a1")
        XCTAssertEqual(assets.first?.assetTag, "AST-1")
    }
}
