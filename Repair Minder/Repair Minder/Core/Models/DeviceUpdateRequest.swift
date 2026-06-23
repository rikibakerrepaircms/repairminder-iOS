//
//  DeviceUpdateRequest.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Device Update Request

/// Request body for `PATCH /api/orders/:orderId/devices/:deviceId`
/// All fields are optional - only include fields to update
struct DeviceUpdateRequest: Encodable, Sendable {
    var brandId: String?
    var modelId: String?
    var customBrand: String?
    var customModel: String?
    var serialNumber: String?
    var imei: String?
    var colour: String?
    var storageCapacity: String?
    var passcode: String?
    var passcodeType: String?
    var findMyStatus: String?
    var conditionGrade: String?
    var customerReportedIssues: String?
    var technicianFoundIssues: String?
    var additionalIssuesFound: String?
    var conditionNotes: String?
    var diagnosisNotes: String?
    var repairNotes: String?
    var technicianNotes: String?
    var dataBackupOffered: Bool?
    var dataBackupAccepted: Bool?
    var dataBackupCompleted: Bool?
    var factoryResetRequired: Bool?
    var factoryResetCompleted: Bool?
    var isUnderWarranty: Bool?
    var warrantyProvider: String?
    var warrantyExpiryDate: String?
    var insuranceClaim: Bool?
    var insuranceReference: String?
    var priority: String?
    var dueDate: String?
    var assignedEngineerId: String?
    var subLocationId: String?
    var deviceTypeId: String?
    var workflowType: String?
    var visualCheck: String?
    var electricalCheck: String?
    var mechanicalCheck: String?
    var damageMatchesReported: Bool?
    var diagnosisConclusion: String?

    init() {}

    // MARK: - Builder Methods

    /// Create a request to update device priority
    static func priority(_ priority: DevicePriority) -> DeviceUpdateRequest {
        var request = DeviceUpdateRequest()
        request.priority = priority.rawValue
        return request
    }

    /// Create a request to assign an engineer
    static func assignEngineer(_ engineerId: String?) -> DeviceUpdateRequest {
        var request = DeviceUpdateRequest()
        request.assignedEngineerId = engineerId
        return request
    }

    /// Create a request to update sub-location
    static func subLocation(_ subLocationId: String?) -> DeviceUpdateRequest {
        var request = DeviceUpdateRequest()
        request.subLocationId = subLocationId
        return request
    }

    /// Create a request to update device type
    static func deviceType(_ deviceTypeId: String?) -> DeviceUpdateRequest {
        var request = DeviceUpdateRequest()
        request.deviceTypeId = deviceTypeId
        return request
    }

    /// Create a request to update workflow type
    static func workflowType(_ workflowType: DeviceWorkflowType) -> DeviceUpdateRequest {
        var request = DeviceUpdateRequest()
        request.workflowType = workflowType.rawValue
        return request
    }

    /// Create a request to update diagnosis notes
    static func diagnosisNotes(_ notes: String) -> DeviceUpdateRequest {
        var request = DeviceUpdateRequest()
        request.diagnosisNotes = notes
        return request
    }

    /// Create a request to update technician found issues
    static func technicianFoundIssues(_ issues: String) -> DeviceUpdateRequest {
        var request = DeviceUpdateRequest()
        request.technicianFoundIssues = issues
        return request
    }

    /// Create a request to update repair notes
    static func repairNotes(_ notes: String) -> DeviceUpdateRequest {
        var request = DeviceUpdateRequest()
        request.repairNotes = notes
        return request
    }
}

// MARK: - Device Status Update Request

/// Request body for `PATCH /api/orders/:orderId/devices/:deviceId/status`
struct DeviceStatusUpdateRequest: Encodable, Sendable {
    let status: String
    var context: String?
    var notes: String?

    init(status: DeviceStatus, context: StatusUpdateContext? = nil, notes: String? = nil) {
        self.status = status.rawValue
        self.context = context?.rawValue
        self.notes = notes
    }
}

/// Context for status updates (device_page or order_page)
enum StatusUpdateContext: String, Sendable {
    case devicePage = "device_page"
    case orderPage = "order_page"
}

// MARK: - Device Action Request

/// Request body for `POST /api/devices/:deviceId/action`
///
/// The Worker reads `to_status`, `context`, optionally `notes`, and any
/// `requires_input` field keys (e.g. `tracking_number`) as sibling top-level
/// keys in the JSON body.  `inputs` is therefore spread at the top level by the
/// custom `encode(to:)` implementation — do NOT nest them under an "inputs" key.
struct DeviceActionRequest: Encodable, Sendable {
    let toStatus: String
    var notes: String?
    var context: String?
    /// Collected values for fields listed in `DeviceAction.requiresInput`.
    /// Keys must match the Worker field names exactly (e.g. `"tracking_number"`).
    var inputs: [String: String]

    init(
        toStatus: String,
        notes: String? = nil,
        context: StatusUpdateContext? = nil,
        inputs: [String: String] = [:]
    ) {
        self.toStatus = toStatus
        self.notes = notes
        self.context = context?.rawValue
        self.inputs = inputs
    }

    // MARK: Custom Encodable

    /// Encodes `toStatus`, `notes`, and `context` under their snake_case names,
    /// then spreads each entry in `inputs` as a sibling top-level key.
    /// The JSON encoder's `.convertToSnakeCase` strategy does NOT apply to keys
    /// written directly via `encode(_:forKey:)` with a `StringCodingKey`, so we
    /// write `to_status` / `notes` / `context` explicitly here.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(toStatus, forKey: .init("to_status"))
        if let notes { try container.encode(notes, forKey: .init("notes")) }
        if let context { try container.encode(context, forKey: .init("context")) }
        for (key, value) in inputs {
            try container.encode(value, forKey: .init(key))
        }
    }
}

/// A `CodingKey` backed by an arbitrary string — used to write dynamic keys.
private struct StringCodingKey: CodingKey {
    let stringValue: String
    init(_ string: String) { self.stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { nil }
}

// MARK: - Device Actions Response

/// Response from `GET /api/orders/:orderId/devices/:deviceId/actions`
struct DeviceActionsResponse: Decodable, Sendable {
    let currentStatus: String
    let workflowType: String
    let availableActions: [DeviceAction]

    /// Parsed current status enum
    var deviceStatus: DeviceStatus {
        DeviceStatus(rawValue: currentStatus) ?? .deviceReceived
    }

    /// Parsed workflow type enum
    var workflow: DeviceWorkflowType {
        DeviceWorkflowType(rawValue: workflowType) ?? .repair
    }
}

/// Available action for a device
struct DeviceAction: Decodable, Sendable, Identifiable {
    let toStatus: String
    let label: String
    let displayLabel: String?
    let isDevicePageAction: Bool?
    let requiresConfirmation: Bool?
    /// Field keys that must be supplied in the action request body.
    /// Each string is the exact JSON key the Worker expects (e.g. `"tracking_number"`).
    let requiresInput: [String]?
    /// Whether the user must supply a free-text notes field (not yet emitted by Worker, reserved).
    let requiresNotes: Bool?
    /// Copy shown in the confirmation sheet body (not yet emitted by Worker, reserved).
    let confirmationMessage: String?

    var id: String { toStatus }

    /// Parsed target status enum
    var targetStatus: DeviceStatus {
        DeviceStatus(rawValue: toStatus) ?? .deviceReceived
    }

    /// True when the action requires user interaction before it can execute
    /// (confirmation, notes, or required input fields).
    var needsInputCollection: Bool {
        (requiresConfirmation == true)
        || (requiresNotes == true)
        || !(requiresInput ?? []).isEmpty
        || confirmationMessage != nil
    }

    /// Human-readable label for a Worker-defined input field key.
    static func label(forInputKey key: String) -> String {
        switch key {
        case "tracking_number":       return "Tracking Number"
        case "quote_items_confirmed": return "Quote Items Confirmed"
        case "parts_to_order":        return "Parts to Order"
        case "bank_details":          return "Bank Details"
        case "payment_reference":     return "Payment Reference"
        default:
            // Convert snake_case → Title Case as a fallback
            return key
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }
}
