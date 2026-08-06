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

    @Test func namesTheThreeRoutesAsTheWebDoes() {
        #expect(EnquiryRouteChip.for(kind: "sell", fulfilment: "visit")?.label == "Walk-in")
        #expect(EnquiryRouteChip.for(kind: "sell", fulfilment: "collection")?.label == "Postal")
        #expect(EnquiryRouteChip.for(kind: "sell", fulfilment: "doorstep")?.label == "Doorstep")
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
