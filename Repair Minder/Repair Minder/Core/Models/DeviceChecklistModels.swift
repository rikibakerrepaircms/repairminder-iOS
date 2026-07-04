//
//  DeviceChecklistModels.swift
//  Repair Minder
//
//  Created on 04/07/2026.
//

import Foundation

// MARK: - Checklist Template

/// A checklist template returned from
/// `GET /api/orders/:orderId/devices/:deviceId/checklists/templates`.
struct ChecklistTemplate: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let checklistType: String
    let deviceCategory: String?
    let items: [ChecklistTemplateItem]
    let isDefault: Bool
}

/// A single checklist item within a template. Backend `items` is a JSON array
/// whose elements may be plain STRINGS or OBJECTS (shape not guaranteed), so
/// this decoder is tolerant of both.
struct ChecklistTemplateItem: Decodable, Identifiable, Hashable, Sendable {
    /// Stable id for `ForEach`; falls back to `name` when no explicit id is present.
    let id: String
    let name: String

    init(from decoder: Decoder) throws {
        if let s = try? decoder.singleValueContainer().decode(String.self) {
            self.name = s
            self.id = s
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let n = (try? c.decode(String.self, forKey: .name))
            ?? (try? c.decode(String.self, forKey: .label))
            ?? (try? c.decode(String.self, forKey: .text))
            ?? ""
        self.name = n
        self.id = (try? c.decode(String.self, forKey: .id)) ?? n
    }

    private enum CodingKeys: String, CodingKey {
        case name, label, text, id
    }
}

// MARK: - Checklist Result Status

/// Status a tech assigns to a single checklist item when completing a checklist.
enum ChecklistResultStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case pass
    case fail
    case notTested = "not_tested"
    case notApplicable = "not_applicable"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pass: return "Pass"
        case .fail: return "Fail"
        case .notTested: return "Not tested"
        case .notApplicable: return "N/A"
        }
    }
}

// MARK: - Checklist Submission

/// A single result row sent in the flat `results` array of
/// `POST /api/orders/:orderId/devices/:deviceId/checklists`.
struct ChecklistResultItem: Encodable, Sendable {
    var name: String
    var status: String
    var notes: String?
}

/// Request body for `POST /api/orders/:orderId/devices/:deviceId/checklists`.
struct CompleteChecklistRequest: Encodable, Sendable {
    var checklistType: String
    var templateId: String?
    var results: [ChecklistResultItem]
}

/// Response `data` payload from a successful checklist submission.
struct CreatedChecklistResponse: Decodable, Sendable {
    let id: String
}
