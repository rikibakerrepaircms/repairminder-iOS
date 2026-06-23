//
//  CustomerPortalFixtureTests.swift
//  Repair MinderTests
//
//  Task 6.2 — live customer-portal decode regression test.
//  Fixture captured 2026-06-22 from the demo account
//  (appstore-customer@repairminder.com, code 123456) via
//  GET /api/customer/orders/demo-order-002.
//
//  Source: LIVE data (3 orders on account; first order used).
//

import Testing
import Foundation
@testable import Repair_Minder

struct CustomerPortalFixtureTests {
    @Test func customerOrderDetailDecodes() throws {
        let json = #"""
        {"id": "demo-order-002", "ticket_number": 100000002, "status": "in_progress", "intake_method": "walk_in", "created_at": "2026-02-03 18:57:29", "collected_at": null, "despatched_at": null, "carrier": "Royal Mail", "tracking_number": null, "tracking_url": null, "quote_sent_at": "2026-02-05 18:57:29", "quote_approved_at": null, "quote_approved_method": null, "rejected_at": null, "customer_po_reference": null, "customer_po_value": null, "customer_po_received_at": null, "has_billing_group": false, "has_parent_group": false, "pre_authorization": null, "review_links": null, "devices": [{"id": "demo-device-002", "display_name": "Apple iPad Air (5th Gen)", "status": "awaiting_authorisation", "workflow_type": "repair", "customer_reported_issues": "Battery drains very fast — goes from 100% to 0% in about 3 hours. Sometimes shuts off at 20%.", "diagnosis_notes": "Battery health at 71%. Cycle count 847. Recommend full battery replacement. No other issues found.", "visual_check": null, "electrical_check": null, "mechanical_check": null, "damage_matches_reported": null, "diagnosis_conclusion": null, "serial_number": "DLXQ91234567", "imei": null, "authorization_status": "pending", "authorization_method": null, "authorized_at": null, "authorization_notes": null, "collection_location_id": null, "aftermarket_consent": 0, "auth_ip_address": null, "auth_user_agent": null, "auth_signature_type": null, "auth_signature_data": null, "collection_location": null, "deposit_paid": 0, "images": [], "pre_repair_checklist": null, "payout_amount": null, "payout_method": null, "payout_date": null, "paid_at": null, "authorization_reason": null, "payment": null}], "items": [{"id": "demo-item-002a", "description": "iPad Air Battery Cell (OEM Compatible)", "quantity": 1, "unit_price": 65, "vat_rate": 0, "line_total": 65, "vat_amount": 0, "line_total_inc_vat": 65, "device_id": "demo-device-002", "authorization_status": "pending", "signature_id": null, "authorized_price": null}, {"id": "demo-item-002b", "description": "Battery Replacement Labour", "quantity": 1, "unit_price": 35, "vat_rate": 0, "line_total": 35, "vat_amount": 0, "line_total_inc_vat": 35, "device_id": "demo-device-002", "authorization_status": "pending", "signature_id": null, "authorized_price": null}], "totals": {"subtotal": 100, "vat_total": 0, "grand_total": 100, "deposits_paid": 0, "final_payments_paid": 0, "amount_paid": 0, "balance_due": 100}, "messages": [{"id": "demo-msg-ord-002a", "type": "outbound", "subject": null, "body_text": "Hi Alex, we've completed the diagnostic on your iPad Air. The battery health is at 71% with 847 charge cycles — definitely time for a replacement. We've sent you a quote for your approval.", "source": "email", "created_at": "2026-02-05 18:57:29"}], "company": {"name": "Apple Review Demo Shop", "phone": "+1 (415) 555-0199", "location_name": "Main Store", "address_line_1": "123 Repair Street", "address_line_2": null, "city": "San Francisco", "county": "CA", "postcode": "94102", "logo_url": null, "currency_code": "USD", "terms_conditions": "By signing below, you agree that Apple Review Demo Shop may carry out the repair or service described on this order. All repairs are guaranteed for 90 days from the date of collection. Devices left uncollected for 30 days after notification may be recycled or disposed of. We are not responsible for data loss — please ensure your device is backed up before drop-off. Payment is due upon collection unless otherwise agreed in writing.", "collection_storage_fee_enabled": false, "collection_recycling_enabled": false, "collection_storage_fee_daily": 5, "collection_storage_fee_cap": 150, "mail_in_help_url": null}}
        """#
        let d = try RMDecode.decode(CustomerOrderDetail.self, json)
        #expect(!d.id.isEmpty)
    }
}
