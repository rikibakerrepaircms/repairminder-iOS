//
//  CustomerEnquiryDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

/// Locks the shape of GET /api/customer/enquiries and
/// GET /api/customer/enquiries/:ticketId. These models are shared, so a decode
/// failure here is a decode failure on iPhone, iPad and Mac at once.
struct CustomerEnquiryDecodeTests {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    // MARK: - Detail

    /// Real payload for a sell enquiry created by the storefront, including the
    /// fields added by migration 0383. created_at comes from D1 as
    /// "yyyy-MM-dd HH:mm:ss", NOT ISO8601.
    @Test func sellEnquiryDetailDecodes() throws {
        let json = #"""
        {"ticket_number":100000042,"subject":"Sell My Phone: iPhone 13 - £250.00","status":"open",
         "created_at":"2026-07-25 09:15:00","ticket_type":"lead","enquiry_kind":"sell",
         "fulfilment":"collection",
         "messages":[{"id":"m1","type":"outbound","from_name":"mendmyi","subject":"Your sale",
                      "body_text":"Thanks","body_html":"<p>Thanks</p>","source":"staff",
                      "created_at":"2026-07-25 09:15:01"}],
         "company":{"name":"mendmyi","logo_url":null,"favicon_url":null}}
        """#.data(using: .utf8)!

        let d = try decoder().decode(CustomerEnquiryDetail.self, from: json)
        #expect(d.ticketNumber == 100000042)
        #expect(d.enquiryKind == "sell")
        #expect(d.isSell)
        #expect(d.fulfilment == "collection")
        // ticket_type stays the staff workflow lane. A sell order is still a lead.
        #expect(d.ticketType == "lead")
        #expect(d.createdAt != nil)
        #expect(d.messages.count == 1)
        #expect(d.company?.name == "mendmyi")
    }

    /// Every ticket created before migration 0383 reads null for both new fields,
    /// and must render exactly as an ordinary enquiry.
    @Test func legacyEnquiryDetailDecodesWithNullKindAndFulfilment() throws {
        let json = #"""
        {"ticket_number":100000001,"subject":"Enquiry: iPad — Battery","status":"pending",
         "created_at":"2026-01-02 11:00:00","ticket_type":"lead","enquiry_kind":null,
         "fulfilment":null,"messages":[],"company":{"name":"mendmyi"}}
        """#.data(using: .utf8)!

        let d = try decoder().decode(CustomerEnquiryDetail.self, from: json)
        #expect(d.enquiryKind == nil)
        #expect(d.fulfilment == nil)
        #expect(!d.isSell)
        #expect(d.messages.isEmpty)
    }

    /// A response predating these fields entirely must still decode.
    @Test func enquiryDetailDecodesWithFieldsAbsent() throws {
        let json = #"{"ticket_number":7,"subject":"Hello","status":"open","messages":[]}"#.data(using: .utf8)!
        let d = try decoder().decode(CustomerEnquiryDetail.self, from: json)
        #expect(d.ticketNumber == 7)
        #expect(d.enquiryKind == nil)
        #expect(!d.isSell)
    }

    @Test func enquiryDetailFallsBackToNumberWhenSubjectIsBlank() throws {
        let json = #"{"ticket_number":42,"subject":"   ","status":"open","messages":[]}"#.data(using: .utf8)!
        let d = try decoder().decode(CustomerEnquiryDetail.self, from: json)
        #expect(d.displaySubject == "Enquiry #42")
    }

    // MARK: - Summary

    @Test func enquiryListDecodes() throws {
        let json = #"""
        [{"id":"t1","ticket_number":100000042,"subject":"Sell My Phone: iPhone 13 - £250.00",
          "status":"open","created_at":"2026-07-25 09:15:00","updated_at":"2026-07-25 09:15:00",
          "ticket_type":"lead","enquiry_kind":"sell","fulfilment":"visit"},
         {"id":"t2","ticket_number":100000043,"subject":"Enquiry: Pixel 8","status":"closed",
          "created_at":"2026-07-24 08:00:00","updated_at":null,"ticket_type":"lead",
          "enquiry_kind":null,"fulfilment":null}]
        """#.data(using: .utf8)!

        let rows = try decoder().decode([CustomerEnquirySummary].self, from: json)
        #expect(rows.count == 2)
        #expect(rows[0].id == "t1")
        #expect(rows[0].isSell)
        #expect(rows[0].fulfilment == "visit")
        #expect(rows[0].createdAt != nil)
        #expect(!rows[1].isSell)
        #expect(rows[1].status == "closed")
    }

    // MARK: - Status labels

    /// The app must say the same words as the web portal's statusLabels map.
    @Test func statusLabelsMatchThePortal() {
        #expect(CustomerEnquiryStatus.label(for: "open") == "Open")
        #expect(CustomerEnquiryStatus.label(for: "pending") == "Pending")
        #expect(CustomerEnquiryStatus.label(for: "resolved") == "Resolved")
        #expect(CustomerEnquiryStatus.label(for: "closed") == "Closed")
        #expect(CustomerEnquiryStatus.label(for: "something_new") == "Open")
        #expect(CustomerEnquiryStatus.isClosed("closed"))
        #expect(CustomerEnquiryStatus.isClosed("resolved"))
        #expect(!CustomerEnquiryStatus.isClosed("open"))
    }
}
