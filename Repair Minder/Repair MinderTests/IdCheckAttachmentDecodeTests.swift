//
//  IdCheckAttachmentDecodeTests.swift
//  Repair MinderTests
//
//  `available_attachments` is what lets the seller ID sheet show a staff member the
//  document it is asking them to judge. Before it, the sheet asked them to type an
//  attachment id into a text field - an id nothing in the product surfaces - and the
//  two toggles that open the payment gate were answered about a document nobody could
//  see.
//
//  These pin the decode, and the ticket-id parse the preview depends on to fetch bytes.
//

import Testing
import Foundation
@testable import Repair_Minder

struct IdCheckAttachmentDecodeTests {

    private let body = """
    {
      "id_check": null,
      "client_address": "2 st botolphs place, Haverhill, Suffolk, CB99LT",
      "client_name": "A Seller",
      "available_attachments": [
        {
          "id": "8fee64b2d6e4485fac605e9a97790ed3",
          "filename": "photo-id.jpeg",
          "content_type": "image/jpeg",
          "created_at": "2026-08-25 12:00:24",
          "from": "Customer (portal upload)",
          "download_url": "/api/tickets/c8064c71/attachments/8fee64b2d6e4485fac605e9a97790ed3/download",
          "is_id_upload": true
        },
        {
          "id": "5b0873acfdb647c8b8d68d45dca995a7",
          "filename": "statement.pdf",
          "content_type": "application/pdf",
          "created_at": "2026-08-25 11:55:04",
          "from": "Customer (portal upload)",
          "download_url": "/api/tickets/c8064c71/attachments/5b0873acfdb647c8b8d68d45dca995a7/download",
          "is_id_upload": false
        }
      ]
    }
    """

    @Test func decodesTheDocumentsTheSellerSent() throws {
        let response = try RMDecode.decode(BuybackIdCheckResponse.self, body)
        let attachments = try #require(response.availableAttachments)
        #expect(attachments.count == 2)
        #expect(attachments[0].filename == "photo-id.jpeg")
        #expect(attachments[0].isIdUpload == true)
    }

    /// The sheet renders a PDF through PDFKit and an image through UIImage/NSImage, so
    /// getting this wrong shows a bank statement as a broken image.
    @Test func tellsPdfsApartFromImages() throws {
        let response = try RMDecode.decode(BuybackIdCheckResponse.self, body)
        let attachments = try #require(response.availableAttachments)
        #expect(attachments[0].isPDF == false)
        #expect(attachments[1].isPDF == true)
    }

    /// The preview needs the ticket id to call the download endpoint, and the API sends
    /// only the assembled path - so this parse is the whole of how the bytes are found.
    @Test func recoversTheTicketIdFromTheDownloadPath() throws {
        let response = try RMDecode.decode(BuybackIdCheckResponse.self, body)
        let attachments = try #require(response.availableAttachments)
        #expect(attachments[0].ticketId == "c8064c71")
    }

    /// An older Worker omits the key entirely. The sheet must still open - it falls
    /// back to an honest "nothing uploaded yet" rather than failing to decode.
    @Test func survivesAResponseWithNoAttachmentsKey() throws {
        let response = try RMDecode.decode(
            BuybackIdCheckResponse.self,
            #"{"id_check": null, "client_address": null, "client_name": null}"#
        )
        #expect(response.availableAttachments == nil)
    }

    /// A malformed or absent download path must not crash the preview; it reports a
    /// failure to load instead.
    @Test func returnsNoTicketIdWhenThePathIsUnusable() throws {
        let response = try RMDecode.decode(
            BuybackIdCheckResponse.self,
            #"""
            {"id_check": null, "client_address": null, "client_name": null,
             "available_attachments": [
               {"id": "a1", "filename": null, "content_type": null,
                "created_at": "2026-08-25 12:00:24", "from": null,
                "download_url": null, "is_id_upload": null}
             ]}
            """#
        )
        let attachments = try #require(response.availableAttachments)
        #expect(attachments[0].ticketId == nil)
    }
}
