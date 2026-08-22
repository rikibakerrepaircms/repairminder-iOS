//
//  SellDeclarationDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

/// `sell_declaration` has to survive the decoder on BOTH models.
///
/// Guards a specific trap: giving the property a default (`= nil`) to keep a
/// memberwise init source-compatible makes Swift omit it from the synthesised
/// `Decodable` conformance entirely, so it silently stays nil no matter what the API
/// sends. The build still succeeds and the card just never appears.
struct SellDeclarationDecodeTests {

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private let declarationJSON = """
    {
      "condition": "Brand new (battery assessed in person, not self-reported)",
      "quoted_price": "£57.00",
      "price_lock_days": 14,
      "ownership_confirmed": true,
      "confirmed": ["Factory sealed or open-box in original packaging", "No iCloud / Google Account lock"],
      "not_confirmed": []
    }
    """

    @Test func decodesEveryFieldOfTheDeclaration() throws {
        let d = try decoder.decode(SellDeclaration.self, from: Data(declarationJSON.utf8))
        #expect(d.condition == "Brand new (battery assessed in person, not self-reported)")
        #expect(d.quotedPrice == "£57.00")
        #expect(d.priceLockDays == 14)
        #expect(d.ownershipConfirmed == true)
        #expect(d.confirmed.count == 2)
        #expect(d.notConfirmed.isEmpty)
    }

    /// Three states. nil is "never asked" and must not read as a refusal.
    @Test func keepsOwnershipNilWhenTheKeyIsAbsent() throws {
        let d = try decoder.decode(SellDeclaration.self, from: Data("{}".utf8))
        #expect(d.ownershipConfirmed == nil)
        #expect(d.confirmed.isEmpty)
    }

    @Test func customerEnquiryCarriesTheDeclaration() throws {
        let json = """
        {
          "id": "t1", "ticket_number": 100002861, "subject": "Sell My Phone",
          "status": "open", "created_at": "2026-08-21 23:21:17",
          "enquiry_kind": "sell", "fulfilment": "collection",
          "messages": [], "company": { "name": "mendmyi" },
          "sell_declaration": \(declarationJSON)
        }
        """
        let enquiry = try decoder.decode(CustomerEnquiryDetail.self, from: Data(json.utf8))
        #expect(enquiry.sellDeclaration?.condition?.hasPrefix("Brand new") == true)
    }

    /// The trap this whole file exists for. `Ticket` is synthesised-Codable, and a
    /// property written `let x: T? = nil` is dropped from the synthesised decoder
    /// outright - it compiles, the memberwise init stays happy, and the field is
    /// silently nil forever no matter what the API sends.
    @Test func staffTicketCarriesTheDeclaration() throws {
        let json = """
        {
          "id": "t1", "ticket_number": 100002861, "subject": "Sell My Phone",
          "status": "open", "ticket_type": "lead",
          "created_at": "2026-08-21 23:21:17", "updated_at": "2026-08-21 23:21:17",
          "enquiry_kind": "sell", "fulfilment": "collection",
          "sell_declaration": \(declarationJSON)
        }
        """
        let ticket = try decoder.decode(Ticket.self, from: Data(json.utf8))
        #expect(ticket.sellDeclaration?.condition?.hasPrefix("Brand new") == true)
        #expect(ticket.sellDeclaration?.confirmed.count == 2)
    }

    @Test func staffTicketWithoutADeclarationStillDecodes() throws {
        let json = """
        {
          "id": "t1", "ticket_number": 100001401, "subject": "Enquiry",
          "status": "open", "ticket_type": "lead",
          "created_at": "2026-04-21 12:23:00", "updated_at": "2026-04-21 12:23:00"
        }
        """
        #expect(try decoder.decode(Ticket.self, from: Data(json.utf8)).sellDeclaration == nil)
    }

    /// Most tickets predate migration 0504 and send nothing. That must decode
    /// cleanly and render nothing, never throw.
    @Test func customerEnquiryWithoutADeclarationStillDecodes() throws {
        let json = """
        {
          "id": "t1", "ticket_number": 100001401, "subject": "Enquiry",
          "status": "open", "created_at": "2026-04-21 12:23:00",
          "messages": [], "company": { "name": "mendmyi" }
        }
        """
        let enquiry = try decoder.decode(CustomerEnquiryDetail.self, from: Data(json.utf8))
        #expect(enquiry.sellDeclaration == nil)
    }
}
