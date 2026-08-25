//
//  TicketMessageDeliveryTests.swift
//  Repair MinderTests
//
//  Voodoo SMS delivery receipts arrive as ticket_email_events rows alongside the
//  Postmark email ones. Two gaps showed up on 2026-08-25:
//
//  1. `deliveryStatus` treated only "bounced"/"blocked" as failure, so an SMS
//     the network explicitly refused to deliver reported as .sent.
//  2. EventData never modelled `timestamp`, and `formattedDate` showed
//     `createdAt` -- when WE recorded the receipt. Voodoo's receipts ran up to
//     15 hours behind the handset, so the app dated a text most of a day late.
//

import Testing
import Foundation
import SwiftUI
@testable import Repair_Minder

struct TicketMessageDeliveryTests {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private func event(_ type: String, at createdAt: String = "2026-08-25 09:34:24", data: EventData? = nil) -> MessageEvent {
        MessageEvent(id: "ev-\(type)", eventType: type, eventData: data, createdAt: createdAt)
    }

    private func smsMessage(events: [MessageEvent]) -> TicketMessage {
        TicketMessage(
            id: "tm-1",
            type: .outboundSms,
            fromEmail: nil,
            fromName: "MENDMYI",
            toEmail: "+447984110991",
            subject: "SMS: repair:device_received",
            bodyText: "Your device is with us.",
            bodyHtml: nil,
            deviceId: nil,
            deviceName: nil,
            createdAt: "2026-08-25 08:23:14",
            createdBy: nil,
            source: "sms",
            events: events,
            attachments: nil
        )
    }

    // MARK: - deliveryStatus

    @Test func failedEventOutranksSent() {
        let message = smsMessage(events: [event("sent"), event("failed")])
        #expect(message.deliveryStatus == .failed)
    }

    @Test func bouncedStillCountsAsFailure() {
        let message = smsMessage(events: [event("sent"), event("bounced")])
        #expect(message.deliveryStatus == .failed)
    }

    @Test func deliveredWithoutFailureIsDelivered() {
        let message = smsMessage(events: [event("sent"), event("delivered")])
        #expect(message.deliveryStatus == .delivered)
    }

    @Test func sentOnlyIsSent() {
        #expect(smsMessage(events: [event("sent")]).deliveryStatus == .sent)
    }

    // MARK: - failed event presentation

    @Test func failedEventReadsAsAFailureNotAsAnUnknown() {
        let failed = event("failed")
        #expect(failed.label == "Not delivered")
        #expect(failed.icon == "exclamationmark.triangle")
        #expect(failed.color == .red)
    }

    // MARK: - EventData decoding

    /// Real payload stored by voodoo_webhook_handler.js for a delivery receipt.
    @Test func eventDataDecodesVoodooDeliveryReceipt() throws {
        let json = #"""
        {"timestamp":"2026-08-24T15:41:59Z","voodoo_message_id":"12889016162487469453877068131941524",
         "recipient":"+447984110991","status":"DELIVERED","sender_id":"MENDMYI"}
        """#.data(using: .utf8)!
        let data = try decoder().decode(EventData.self, from: json)
        #expect(data.timestamp == "2026-08-24T15:41:59Z")
        #expect(data.status == "DELIVERED")
    }

    /// Real payload stored for a Postmark email event — same `timestamp` field.
    @Test func eventDataDecodesPostmarkEvent() throws {
        let json = #"""
        {"timestamp":"2026-08-25T18:16:15.189Z","postmark_message_id":"738a9134-2cd8-4a57-b0b9-16bbbccdca93",
         "bounce_type":"HardBounce"}
        """#.data(using: .utf8)!
        let data = try decoder().decode(EventData.self, from: json)
        #expect(data.timestamp == "2026-08-25T18:16:15.189Z")
        #expect(data.postmarkMessageId == "738a9134-2cd8-4a57-b0b9-16bbbccdca93")
        #expect(data.status == nil)
    }

    @Test func eventDataStillDecodesWhenEmpty() throws {
        let data = try decoder().decode(EventData.self, from: #"{}"#.data(using: .utf8)!)
        #expect(data.timestamp == nil)
    }

    // MARK: - displayTimestamp

    @Test func displayTimestampPrefersTheProviderTime() throws {
        let data = try decoder().decode(
            EventData.self,
            from: #"{"timestamp":"2026-08-24T15:41:59Z","status":"DELIVERED"}"#.data(using: .utf8)!
        )
        // Recorded 2026-08-25 09:34:24, but the handset had it the previous afternoon.
        let delivered = event("delivered", at: "2026-08-25 09:34:24", data: data)
        #expect(delivered.displayTimestamp == "2026-08-24T15:41:59Z")
    }

    @Test func displayTimestampFallsBackToRecordTimeWithoutProviderTime() {
        let sent = event("sent", at: "2026-08-25 08:23:14", data: nil)
        #expect(sent.displayTimestamp == "2026-08-25 08:23:14")
    }

    @Test func displayTimestampFallsBackWhenProviderTimeIsUnparseable() throws {
        let data = try decoder().decode(
            EventData.self,
            from: #"{"timestamp":"not-a-date"}"#.data(using: .utf8)!
        )
        let delivered = event("delivered", at: "2026-08-25 09:34:24", data: data)
        #expect(delivered.displayTimestamp == "2026-08-25 09:34:24")
    }
}
