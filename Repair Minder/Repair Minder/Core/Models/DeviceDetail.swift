//
//  DeviceDetail.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Device Detail

/// Full device detail from `GET /api/orders/:orderId/devices/:deviceId`
struct DeviceDetail: Decodable, Identifiable, Sendable {
    let id: String
    let orderId: String
    let brand: BrandInfo?
    let model: ModelInfo?
    let customBrand: String?
    let customModel: String?
    let displayName: String
    let serialNumber: String?
    let imei: String?
    let colour: String?
    let storageCapacity: String?
    let passcode: String?
    let passcodeType: String?
    let findMyStatus: String?
    let conditionGrade: String?
    let customerReportedIssues: String?
    let technicianFoundIssues: String?
    let additionalIssuesFound: String?
    let conditionNotes: String?
    let dataBackupOffered: Bool
    let dataBackupAccepted: Bool
    let dataBackupCompleted: Bool
    let factoryResetRequired: Bool
    let factoryResetCompleted: Bool
    let isUnderWarranty: Bool
    let warrantyProvider: String?
    let warrantyExpiryDate: String?
    let insuranceClaim: Bool
    let insuranceReference: String?
    let status: String
    let priority: String
    let dueDate: String?
    let assignedEngineer: AssignedEngineerInfo?
    let subLocationId: String?
    let subLocation: SubLocationInfo?
    let deviceType: DeviceTypeInfo?
    let diagnosisNotes: String?
    let repairNotes: String?
    let technicianNotes: String?
    let authorizationNotes: String?
    let authorization: AuthorizationInfo
    let visualCheck: String?
    let electricalCheck: String?
    let mechanicalCheck: String?
    let damageMatchesReported: Bool?
    let diagnosisConclusion: String?
    let timestamps: DeviceTimestamps
    let actionBy: ActionByInfo
    let images: [DeviceImageInfo]
    let accessories: [DeviceAccessory]
    let partsUsed: [DevicePart]
    let lineItems: [DeviceLineItem]
    let deviceNotes: [DeviceNote]
    let workflowType: String
    let authorizedNextStatus: String?
    let checklist: [DeviceChecklistItem]
    let createdAt: String
    let updatedAt: String

    // MARK: - Computed Properties

    /// Parsed device status enum
    var deviceStatus: DeviceStatus {
        DeviceStatus(rawValue: status) ?? .deviceReceived
    }

    /// Parsed workflow type enum
    var workflow: DeviceWorkflowType {
        DeviceWorkflowType(rawValue: workflowType) ?? .repair
    }

    /// Parsed device priority
    var devicePriority: DevicePriority {
        DevicePriority(rawValue: priority) ?? .normal
    }

    /// Whether this device is overdue
    var isOverdue: Bool {
        guard let dueDate = dueDate,
              let date = DateFormatters.parseISO8601(dueDate) else { return false }
        return date < Date() && !deviceStatus.isTerminal
    }

    /// Formatted due date
    var formattedDueDate: String? {
        guard let dueDate = dueDate else { return nil }
        return DateFormatters.formatRelativeDate(dueDate)
    }

    /// Whether device has any issues documented
    var hasIssuesDocumented: Bool {
        customerReportedIssues != nil || technicianFoundIssues != nil || additionalIssuesFound != nil
    }

    /// Whether diagnostic checks have been performed
    var hasDiagnosticChecks: Bool {
        visualCheck != nil || electricalCheck != nil || mechanicalCheck != nil
    }

    /// Total line items amount
    var totalLineItemsAmount: Decimal {
        lineItems.reduce(Decimal(0)) { $0 + $1.lineTotalIncVat }
    }

    /// Checklist completion percentage
    var checklistProgress: Int {
        guard !checklist.isEmpty else { return 100 }
        let completed = checklist.filter { $0.completed }.count
        return Int((Double(completed) / Double(checklist.count)) * 100)
    }

    /// All checklist requirements met
    var allChecklistComplete: Bool {
        checklist.filter { $0.required }.allSatisfy { $0.completed }
    }
}

// MARK: - Brand & Model Info

struct BrandInfo: Decodable, Sendable, Identifiable {
    let id: String
    let name: String
    let category: String?
}

struct ModelInfo: Decodable, Sendable, Identifiable {
    let id: String
    let name: String
}

// MARK: - Authorization Info

struct AuthorizationInfo: Decodable, Sendable {
    let status: String?
    let method: String?
    let authorizedAt: String?
    let authorizedBy: String?
    let authorizedByName: String?
    let signature: SignatureInfo?

    /// Whether authorization has been approved
    var isApproved: Bool {
        status == "approved"
    }

    /// Whether authorization has been rejected
    var isRejected: Bool {
        status == "rejected"
    }
}

struct SignatureInfo: Decodable, Sendable {
    let type: String
    let action: String
    let ipAddress: String?
    let userAgent: String?
    let createdAt: String
}

// MARK: - Timestamps

struct DeviceTimestamps: Decodable, Sendable {
    let receivedAt: String?
    let checkedInAt: String?
    let diagnosisStartedAt: String?
    let diagnosisCompletedAt: String?
    let reportSentAt: String?
    let reportAuthorisedAt: String?
    let reportRejectedAt: String?
    let repairStartedAt: String?
    let repairCompletedAt: String?
    let qualityCheckedAt: String?
    let readyForCollectionAt: String?
    let collectedAt: String?
    let despatchedAt: String?

    /// Formatted received date
    var formattedReceivedAt: String? {
        guard let date = receivedAt else { return nil }
        return DateFormatters.formatRelativeDate(date)
    }

    /// Formatted diagnosis start date
    var formattedDiagnosisStarted: String? {
        guard let date = diagnosisStartedAt else { return nil }
        return DateFormatters.formatRelativeDate(date)
    }

    /// Formatted repair start date
    var formattedRepairStarted: String? {
        guard let date = repairStartedAt else { return nil }
        return DateFormatters.formatRelativeDate(date)
    }
}

// MARK: - Action By Info

struct ActionByInfo: Decodable, Sendable {
    let diagnosisStartedBy: String?
    let diagnosisCompletedBy: String?
    let repairStartedBy: String?
    let repairCompletedBy: String?
    let quoteSentBy: String?
    let markedReadyBy: String?
}

// MARK: - Device Image

struct DeviceImageInfo: Decodable, Sendable, Identifiable {
    let id: String
    let imageType: String
    let r2Key: String
    let filename: String?
    let caption: String?
    let sortOrder: Int
    let uploadedAt: String

    /// Whether this is a pre-repair image
    var isPreRepair: Bool {
        imageType == "pre_repair"
    }

    /// Whether this is a post-repair image
    var isPostRepair: Bool {
        imageType == "post_repair"
    }

    /// Whether this is a diagnostic image
    var isDiagnostic: Bool {
        imageType == "diagnostic"
    }
}

// MARK: - Device Accessory

struct DeviceAccessory: Decodable, Sendable, Identifiable {
    let id: String
    let accessoryType: String
    let description: String?
    let returnedAt: String?
    let createdAt: String

    /// Whether accessory has been returned
    var isReturned: Bool {
        returnedAt != nil
    }

    /// Display name for accessory type
    var typeDisplayName: String {
        switch accessoryType {
        case "charger": return "Charger"
        case "cable": return "Cable"
        case "case": return "Case"
        case "sim_card": return "SIM Card"
        case "stylus": return "Stylus"
        case "box": return "Box"
        case "sd_card": return "SD Card"
        case "other": return "Other"
        default: return accessoryType.capitalized
        }
    }
}

// MARK: - Device Part

struct DevicePart: Decodable, Sendable, Identifiable {
    let id: String
    let partName: String
    let partSku: String?
    let partCost: Double?
    let supplier: String?
    let isOem: Bool
    let warrantyDays: Int?
    let installedAt: String?
    let installedBy: String?

    /// Whether part has been installed
    var isInstalled: Bool {
        installedAt != nil
    }

    /// Formatted part cost
    var formattedCost: String? {
        guard let cost = partCost else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: NSNumber(value: cost))
    }
}

// MARK: - Device Line Item

struct DeviceLineItem: Decodable, Sendable, Identifiable {
    let id: String
    let description: String
    let quantity: Int
    let unitPrice: Double
    let vatRate: Double
    let lineTotalIncVat: Decimal

    /// Custom decoding to handle numeric values
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        description = try container.decode(String.self, forKey: .description)
        quantity = try container.decode(Int.self, forKey: .quantity)
        unitPrice = try container.decode(Double.self, forKey: .unitPrice)
        vatRate = try container.decode(Double.self, forKey: .vatRate)

        // Handle line total as Double or Int
        if let doubleValue = try? container.decode(Double.self, forKey: .lineTotalIncVat) {
            lineTotalIncVat = Decimal(doubleValue)
        } else if let intValue = try? container.decode(Int.self, forKey: .lineTotalIncVat) {
            lineTotalIncVat = Decimal(intValue)
        } else {
            lineTotalIncVat = 0
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, description, quantity
        case unitPrice = "unit_price"
        case vatRate = "vat_rate"
        case lineTotalIncVat = "line_total_inc_vat"
    }

    /// Formatted unit price
    var formattedUnitPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: NSNumber(value: unitPrice)) ?? "£0.00"
    }

    /// Formatted line total
    var formattedLineTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: lineTotalIncVat as NSDecimalNumber) ?? "£0.00"
    }
}

// MARK: - Device Checklist Item

struct DeviceChecklistItem: Decodable, Sendable, Identifiable {
    let key: String
    let label: String
    let completed: Bool
    let required: Bool

    var id: String { key }
}

// MARK: - Device Priority

enum DevicePriority: String, Decodable, CaseIterable, Sendable {
    case normal
    case urgent
    case express

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .urgent: return "Urgent"
        case .express: return "Express"
        }
    }

    var icon: String {
        switch self {
        case .normal: return "clock"
        case .urgent: return "exclamationmark.triangle"
        case .express: return "bolt.fill"
        }
    }
}

// MARK: - Find My Status

enum FindMyStatus: String, Decodable, CaseIterable, Sendable {
    case disabled
    case enabled
    case unknown

    var displayName: String {
        switch self {
        case .disabled: return "Disabled"
        case .enabled: return "Enabled"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .disabled: return "location.slash"
        case .enabled: return "location.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Passcode Type

enum PasscodeType: String, Decodable, CaseIterable, Sendable {
    case pin
    case pattern
    case password
    case biometric
    case none

    var displayName: String {
        switch self {
        case .pin: return "PIN"
        case .pattern: return "Pattern"
        case .password: return "Password"
        case .biometric: return "Biometric"
        case .none: return "None"
        }
    }
}

// MARK: - Condition Grade

enum ConditionGrade: String, Decodable, CaseIterable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case f = "F"

    var displayName: String {
        switch self {
        case .a: return "Grade A - Excellent"
        case .b: return "Grade B - Good"
        case .c: return "Grade C - Fair"
        case .d: return "Grade D - Poor"
        case .f: return "Grade F - Faulty"
        }
    }
}
