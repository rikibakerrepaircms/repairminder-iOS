//
//  StaffAuthorizeModels.swift
//  Repair Minder
//
//  Created on 04/07/2026.
//

import Foundation

// MARK: - Staff Authorize

/// Request body for `POST /api/devices/:id/staff-authorize`.
/// Gate: device status must be `awaiting_authorisation` (buyback workflow
/// also allows `ready_to_quote`).
///
/// v1 scope note: `bank_details` is intentionally omitted — the buyback
/// bank-details flow is out of scope here. A plain approve/reject with
/// `method` + optional `authorization_reason` covers the repair case. If the
/// backend requires bank details for a buyback approve, the request will
/// surface a 400 via `APIError`, which is acceptable for this v1.
struct StaffAuthorizeRequest: Encodable, Sendable {
    var action: String                 // "approve" | "reject" | "proceed_original"
    var method: String                 // "in_store" | "phone" | "staff_override"
    var notes: String?
    var authorizationReason: String?   // -> wire "authorization_reason"
}

/// Response `data` payload from a successful staff-authorize action.
struct StaffAuthorizeResponse: Decodable, Sendable {
    let action: String
    let deviceId: String                // <- device_id
    let newStatus: String                // <- new_status
    let method: String
    let message: String?
}
