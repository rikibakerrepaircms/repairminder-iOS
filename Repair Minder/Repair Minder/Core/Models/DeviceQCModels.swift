//
//  DeviceQCModels.swift
//  Repair Minder
//
//  Created on 04/07/2026.
//

import Foundation

// MARK: - QC Requirements

/// Readiness snapshot returned from `GET /api/devices/:id/qc-requirements`.
/// Wire fields are camelCase (pass-through, no snake_case conversion needed).
struct QCRequirements: Decodable, Sendable {
    let hasPostTestChecklist: Bool
    let hasConclusion: Bool
    let hasPostRepairPhotos: Bool
    let requirePostRepairPhotos: Bool
    let requirePostRepairChecklist: Bool
}

// MARK: - QC Action

/// Request body for `POST /api/devices/:id/qc`.
struct QCActionRequest: Encodable, Sendable {
    var action: String                 // "pass" | "fail"
    var reworkNote: String?            // -> wire "rework_note"; required when action == "fail"
    var collectionLocationId: String?  // -> wire "collection_location_id"
}

/// Response `data` payload from a successful QC action.
struct QCActionResponse: Decodable, Sendable {
    let newStatus: String              // <- new_status
    let noteId: String?                // <- note_id
}
