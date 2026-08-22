//
//  BuybackIdCheckModels.swift
//  Repair Minder
//
//  The seller identity check for a buyback purchase. All fields are snake_case
//  on the wire — encoded/decoded via `.convertToSnakeCase` /
//  `.convertFromSnakeCase`; do not add CodingKeys.
//
//  WHY THIS EXISTS. Adding a device to buyback inventory has always been blocked
//  unless the seller's name and address were populated. That gate never checked,
//  and never recorded, that anybody had looked at a document to see whether they
//  were true — so the system enforced half of what the VAT Margin Scheme asks
//  for. As of migration 0505 the same gate also requires a PASSING check, which
//  means `addDeviceToBuyback` on this app now fails with `id_check_required`
//  unless one has been recorded. This is how it gets recorded from here rather
//  than sending staff to a desktop.
//
//  WHAT IS DELIBERATELY ABSENT: any document number. We cannot validate one,
//  HMRC does not ask for one, and holding one turns a diligence record into a
//  breach target. The API does not accept one either.
//
//  Web twin: src/components/buyback/SellerIdCheckPanel.tsx. The customer-facing
//  half — what we tell the seller and why — is
//  src/components/customer/idRequirement.ts in the web repo.
//

import Foundation

/// Kept in step with `PHOTO_ID_TYPES` in worker/src/buyback_id_check.js.
enum PhotoIdType: String, CaseIterable, Identifiable {
    case drivingLicence = "driving_licence"
    case passport
    case nationalId = "national_id"
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .drivingLicence: return "Photocard driving licence"
        case .passport: return "Passport"
        case .nationalId: return "National identity card"
        case .other: return "Other (add a note)"
        }
    }

    /// A photocard licence carries a current address, so it can satisfy both
    /// requirements on its own. Nothing else on this list does, and the customer
    /// copy promises exactly that.
    var carriesAddress: Bool { self == .drivingLicence }
}

/// Kept in step with `PROOF_OF_ADDRESS_TYPES` in worker/src/buyback_id_check.js.
enum ProofOfAddressType: String, CaseIterable, Identifiable {
    case bankStatement = "bank_statement"
    case utilityBill = "utility_bill"
    case councilTax = "council_tax"
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bankStatement: return "Bank or building society statement"
        case .utilityBill: return "Utility bill"
        case .councilTax: return "Council tax letter"
        case .other: return "Other (add a note)"
        }
    }
}

enum IdCheckMethod: String, CaseIterable, Identifiable {
    /// The normal case, and the one we tell sellers to expect: they show us at the
    /// counter and we keep no copy.
    case inPerson = "in_person"
    case imageSupplied = "image_supplied"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inPerson: return "In person - no copy kept"
        case .imageSupplied: return "Image supplied"
        }
    }
}

struct BuybackIdCheck: Decodable {
    let id: String
    let orderId: String
    let photoIdType: String
    let proofOfAddressType: String?
    let proofOfAddressDated: String?
    let method: String
    /// Whether an image is held, never the attachment id itself.
    let hasStoredImage: Bool
    let nameMatches: Bool
    let addressMatches: Bool
    let addressVerified: String?
    let notes: String?
    let checkedBy: String
    let checkedByName: String?
    let checkedAt: String

    /// A row alone is not enough. A recorded FAILURE is still a recorded check,
    /// and it is exactly the case that must stop a device reaching inventory.
    var passes: Bool { nameMatches && addressMatches }

    var photoIdLabel: String {
        PhotoIdType(rawValue: photoIdType)?.label ?? photoIdType
    }

    var proofOfAddressLabel: String? {
        guard let proofOfAddressType else { return nil }
        return ProofOfAddressType(rawValue: proofOfAddressType)?.label ?? proofOfAddressType
    }

    var methodLabel: String {
        IdCheckMethod(rawValue: method)?.label ?? method
    }
}

/// `GET /api/orders/:orderId/id-check`
struct BuybackIdCheckResponse: Decodable {
    let idCheck: BuybackIdCheck?
    /// The address currently on the client record, offered as the thing being
    /// verified so nobody retypes what is already there. It is also the line the
    /// self-billed purchase invoice will carry.
    let clientAddress: String?
    let clientName: String?
}

/// `PUT /api/orders/:orderId/id-check`
struct RecordBuybackIdCheckRequest: Encodable {
    var photoIdType: String
    var proofOfAddressType: String?
    var proofOfAddressDated: String?
    var method: String
    var idAttachmentId: String?
    var nameMatches: Bool
    var addressMatches: Bool
    var addressVerified: String?
    var notes: String?
}

struct RecordBuybackIdCheckResponse: Decodable {
    let idCheck: BuybackIdCheck
}
