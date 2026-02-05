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

/// Request body for `POST /api/orders/:orderId/devices/:deviceId/action`
struct DeviceActionRequest: Encodable, Sendable {
    let action: String
    var notes: String?
    var context: String?

    init(action: String, notes: String? = nil, context: StatusUpdateContext? = nil) {
        self.action = action
        self.notes = notes
        self.context = context?.rawValue
    }
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
    let isDevicePageAction: Bool
    let requiresNotes: Bool?
    let confirmationMessage: String?

    var id: String { toStatus }

    /// Parsed target status enum
    var targetStatus: DeviceStatus {
        DeviceStatus(rawValue: toStatus) ?? .deviceReceived
    }
}
