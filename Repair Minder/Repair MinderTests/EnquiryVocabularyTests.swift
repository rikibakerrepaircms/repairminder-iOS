//
//  EnquiryVocabularyTests.swift
//  Repair MinderTests
//

import Testing
import SwiftUI
@testable import Repair_Minder

struct EnquiryVocabularyTests {

    /// Wording matches the web dashboard's enquiryKindBadge.ts exactly, so
    /// staff read one vocabulary on both.
    @Test func namesTheThreeKindsAsTheWebDoes() {
        #expect(EnquiryKindBadge.for("repair_order")?.label == "Repair order")
        #expect(EnquiryKindBadge.for("sell")?.label == "Sell order")
        #expect(EnquiryKindBadge.for("enquiry")?.label == "Enquiry")
    }

    /// 79 of 100 live tickets predate enquiry_kind. A badge that guessed
    /// would mislabel all of them.
    @Test func rendersNothingForAMissingOrUnknownKind() {
        #expect(EnquiryKindBadge.for(nil) == nil)
        #expect(EnquiryKindBadge.for("nonsense") == nil)
    }

    @Test func givesTheThreeKindsThreeDistinctLabels() {
        let labels = ["repair_order", "sell", "enquiry"].compactMap { EnquiryKindBadge.for($0)?.label }
        #expect(Set(labels).count == 3)
    }

    /// The label names the ROUTE, not the person, so it does not fork by kind.
    @Test func routeLabelsMatchAcrossKinds() {
        for f in ["visit", "collection", "doorstep"] {
            #expect(EnquiryRouteChip.for(kind: "sell", fulfilment: f)?.label
                    == EnquiryRouteChip.for(kind: "repair_order", fulfilment: f)?.label)
        }
    }

    /// Renamed 2026-08-22 to match the web's deviceRoute.ts. "Postal" did not say
    /// who posts it or who makes the label, and "Doorstep" did not say who travels -
    /// staff reading a postal sell order alongside the storefront note's old "Free
    /// collection" line concluded a van was going out. Each label now names the
    /// physical act.
    @Test func namesTheThreeRoutesAsTheWebDoes() {
        #expect(EnquiryRouteChip.for(kind: "sell", fulfilment: "visit")?.label == "Walk-in")
        #expect(EnquiryRouteChip.for(kind: "sell", fulfilment: "collection")?.label == "Post to us")
        #expect(EnquiryRouteChip.for(kind: "sell", fulfilment: "doorstep")?.label == "We collect")
    }

    /// WE DO NOT POST A LABEL OUT. Approval publishes it to the customer's own portal
    /// and emails them a link; they download and print it. The thing we really do post
    /// is packaging, which is a separate request. Pinned on the web by
    /// deviceRoute.test.ts and by the storefront's labelInstructions.test.ts.
    @Test func neverClaimsWePostALabelOut() {
        let hint = EnquiryRouteChip.for(kind: "sell", fulfilment: "collection")?.hint ?? ""
        #expect(hint.lowercased().contains("download"))
        #expect(hint.lowercased().contains("print"))
        #expect(!hint.lowercased().contains("asked us to send"))
    }

    /// The doorstep hint is the only one that may say we travel, and the postal hint
    /// must never use the word - that overlap is the whole bug.
    @Test func onlyTheDoorstepRouteSaysWeCollect() {
        let postal = EnquiryRouteChip.for(kind: "sell", fulfilment: "collection")?.hint ?? ""
        #expect(!postal.lowercased().contains("collect"))
    }

    /// Repair is outlined and sell is filled, so a postal buyback and a postal
    /// repair are distinguishable at a glance rather than identical.
    @Test func repairIsOutlinedAndSellIsFilled() {
        #expect(EnquiryRouteChip.for(kind: "repair_order", fulfilment: "collection")?.isOutlined == true)
        #expect(EnquiryRouteChip.for(kind: "sell", fulfilment: "collection")?.isOutlined == false)
    }

    /// A ticket that never chose a route, and a kind that is not device-inbound.
    @Test func rendersNoRouteChipWithoutAFulfilment() {
        #expect(EnquiryRouteChip.for(kind: "sell", fulfilment: nil) == nil)
        #expect(EnquiryRouteChip.for(kind: "enquiry", fulfilment: "visit") == nil)
    }

    /// The rule already applied to the staff label panel on the web.
    @Test func neverCallsARepairCustomerTheSeller() {
        for f in ["visit", "collection", "doorstep"] {
            let hint = EnquiryRouteChip.for(kind: "repair_order", fulfilment: f)?.hint ?? ""
            #expect(!hint.lowercased().contains("seller"))
        }
    }
}
