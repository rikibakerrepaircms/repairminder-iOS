//
//  CustomerDevice.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import SwiftUI

// MARK: - Customer Device

/// Full device details for customer portal
struct CustomerDevice: Codable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let status: String
    let workflowType: DeviceWorkflowType
    let customerReportedIssues: String?
    let serialNumber: String?
    let imei: String?

    // Diagnostic assessment
    let visualCheck: String?
    let electricalCheck: String?
    let mechanicalCheck: String?
    let damageMatchesReported: String?
    let diagnosisConclusion: String?

    // Authorization
    let authorizationStatus: String?
    let authorizationMethod: String?
    let authorizedAt: Date?
    let authIpAddress: String?
    let authUserAgent: String?
    let authSignatureType: String?
    let authSignatureData: String?
    let authorizationReason: String?

    // Collection location
    let collectionLocation: CollectionLocation?

    // Payment info
    let depositPaid: Decimal?
    let payoutAmount: Decimal?
    let payoutMethod: String?
    let payoutDate: String?
    let paidAt: Date?
    let payment: DevicePayment?

    // Images and checklist
    let images: [DeviceImage]?
    let preRepairChecklist: PreRepairChecklist?

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case id, displayName, status, workflowType, customerReportedIssues
        case serialNumber, imei, visualCheck, electricalCheck, mechanicalCheck
        case damageMatchesReported, diagnosisConclusion, authorizationStatus
        case authorizationMethod, authorizedAt, authIpAddress, authUserAgent
        case authSignatureType, authSignatureData, authorizationReason
        case collectionLocation, depositPaid, payoutAmount, payoutMethod
        case payoutDate, paidAt, payment, images, preRepairChecklist
    }

    /// Custom decoding to handle flexible field types
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        status = try container.decode(String.self, forKey: .status)
        workflowType = try container.decodeIfPresent(DeviceWorkflowType.self, forKey: .workflowType) ?? .repair
        customerReportedIssues = try container.decodeIfPresent(String.self, forKey: .customerReportedIssues)
        serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber)
        imei = try container.decodeIfPresent(String.self, forKey: .imei)

        visualCheck = try container.decodeIfPresent(String.self, forKey: .visualCheck)
        electricalCheck = try container.decodeIfPresent(String.self, forKey: .electricalCheck)
        mechanicalCheck = try container.decodeIfPresent(String.self, forKey: .mechanicalCheck)
        damageMatchesReported = try container.decodeIfPresent(String.self, forKey: .damageMatchesReported)
        diagnosisConclusion = try container.decodeIfPresent(String.self, forKey: .diagnosisConclusion)

        authorizationStatus = try container.decodeIfPresent(String.self, forKey: .authorizationStatus)
        authorizationMethod = try container.decodeIfPresent(String.self, forKey: .authorizationMethod)
        authorizedAt = Self.decodeDate(from: container, forKey: .authorizedAt)
        authIpAddress = try container.decodeIfPresent(String.self, forKey: .authIpAddress)
        authUserAgent = try container.decodeIfPresent(String.self, forKey: .authUserAgent)
        authSignatureType = try container.decodeIfPresent(String.self, forKey: .authSignatureType)
        authSignatureData = try container.decodeIfPresent(String.self, forKey: .authSignatureData)
        authorizationReason = try container.decodeIfPresent(String.self, forKey: .authorizationReason)

        collectionLocation = try container.decodeIfPresent(CollectionLocation.self, forKey: .collectionLocation)

        // Handle decimal fields
        depositPaid = Self.decodeDecimal(from: container, forKey: .depositPaid)
        payoutAmount = Self.decodeDecimal(from: container, forKey: .payoutAmount)
        payoutMethod = try container.decodeIfPresent(String.self, forKey: .payoutMethod)
        payoutDate = try container.decodeIfPresent(String.self, forKey: .payoutDate)
        paidAt = Self.decodeDate(from: container, forKey: .paidAt)
        payment = try container.decodeIfPresent(DevicePayment.self, forKey: .payment)

        images = try container.decodeIfPresent([DeviceImage].self, forKey: .images)
        preRepairChecklist = try container.decodeIfPresent(PreRepairChecklist.self, forKey: .preRepairChecklist)
    }

    private static func decodeDecimal(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Decimal? {
        if let doubleValue = try? container.decode(Double.self, forKey: key) {
            return Decimal(doubleValue)
        }
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return Decimal(intValue)
        }
        return nil
    }

    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        guard let dateString = try? container.decode(String.self, forKey: key) else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: dateString) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: dateString) { return d }
        let mysql = DateFormatter()
        mysql.dateFormat = "yyyy-MM-dd HH:mm:ss"
        mysql.timeZone = TimeZone(identifier: "UTC")
        return mysql.date(from: dateString)
    }

    // MARK: - Computed Properties

    /// Parsed device status enum
    var deviceStatus: DeviceStatus? {
        DeviceStatus(rawValue: status)
    }

    /// Whether this device is awaiting authorization
    var isAwaitingAuthorization: Bool {
        status == "awaiting_authorisation"
    }

    /// Whether authorization has been approved
    var isApproved: Bool {
        authorizationStatus == "approved"
    }

    /// Whether authorization has been rejected
    var isRejectedByCustomer: Bool {
        authorizationStatus == "rejected" || status == "rejected"
    }

    /// Whether device is ready for collection
    var isReadyForCollection: Bool {
        deviceStatus?.isReadyForCollection ?? false
    }

    /// Whether the device has diagnostic information
    var hasDiagnosticInfo: Bool {
        visualCheck != nil || electricalCheck != nil || mechanicalCheck != nil ||
        damageMatchesReported != nil || diagnosisConclusion != nil
    }

    /// Whether the device has pre-repair images
    var hasImages: Bool {
        guard let images = images else { return false }
        return !images.isEmpty
    }

    /// Whether the device has a pre-repair checklist
    var hasChecklist: Bool {
        preRepairChecklist != nil
    }

    /// Whether this is a buyback workflow
    var isBuyback: Bool {
        workflowType == .buyback
    }

    /// Whether this is a repair workflow
    var isRepair: Bool {
        workflowType == .repair
    }

    /// Label for the quote/offer (different for buyback vs repair)
    var quoteLabel: String {
        isBuyback ? "Offer" : "Quote"
    }
}

// MARK: - Collection Location

/// Store/location where device can be collected
struct CollectionLocation: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let address: String
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let county: String?
    let postcode: String?
    let phone: String?
    let email: String?
    let googleMapsUrl: String?
    let appleMapsUrl: String?
    let openingHours: OpeningHours?

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case id, name, address, addressLine1, addressLine2, city, county
        case postcode, phone, email, googleMapsUrl, appleMapsUrl, openingHours
    }

    /// Formatted multi-line address
    var formattedAddress: String {
        var parts: [String] = []
        if let line1 = addressLine1 { parts.append(line1) }
        if let line2 = addressLine2 { parts.append(line2) }
        if let city = city { parts.append(city) }
        if let postcode = postcode { parts.append(postcode) }
        return parts.joined(separator: "\n")
    }

    /// Whether maps navigation is available
    var hasMapsUrl: Bool {
        googleMapsUrl != nil || appleMapsUrl != nil
    }
}

// MARK: - Opening Hours

/// Weekly opening hours for a location
struct OpeningHours: Codable, Sendable {
    let monday: DayHours?
    let tuesday: DayHours?
    let wednesday: DayHours?
    let thursday: DayHours?
    let friday: DayHours?
    let saturday: DayHours?
    let sunday: DayHours?

    /// Get hours for a specific day
    func hours(for day: Int) -> DayHours? {
        switch day {
        case 1: return sunday
        case 2: return monday
        case 3: return tuesday
        case 4: return wednesday
        case 5: return thursday
        case 6: return friday
        case 7: return saturday
        default: return nil
        }
    }

    /// Get today's hours
    var todayHours: DayHours? {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return hours(for: weekday)
    }

    /// Whether the location is open today
    var isOpenToday: Bool {
        todayHours != nil
    }

    /// All days with their hours for display
    var allDays: [(name: String, hours: DayHours?)] {
        [
            ("Monday", monday),
            ("Tuesday", tuesday),
            ("Wednesday", wednesday),
            ("Thursday", thursday),
            ("Friday", friday),
            ("Saturday", saturday),
            ("Sunday", sunday)
        ]
    }
}

/// Opening hours for a single day
struct DayHours: Codable, Sendable {
    let open: String
    let close: String

    /// Formatted display string
    var displayString: String {
        "\(open) - \(close)"
    }
}

// MARK: - Device Image

/// Image associated with a device (pre-repair photos)
struct DeviceImage: Codable, Identifiable, Sendable {
    let id: String
    let imageType: String
    let url: String
    let filename: String
    let caption: String?
    let uploadedAt: Date

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case id, imageType, url, filename, caption, uploadedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        imageType = try container.decode(String.self, forKey: .imageType)
        url = try container.decode(String.self, forKey: .url)
        filename = try container.decode(String.self, forKey: .filename)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        if let str = try? container.decode(String.self, forKey: .uploadedAt) {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            uploadedAt = iso.date(from: str) ?? Date()
        } else { uploadedAt = Date() }
    }

    /// Whether this is a pre-repair image
    var isPreRepair: Bool {
        imageType == "pre_repair"
    }

    /// Whether this is a diagnostic image
    var isDiagnostic: Bool {
        imageType == "diagnostic"
    }
}

// MARK: - Device Payment (Buyback)

/// Payment information for buyback devices
struct DevicePayment: Codable, Sendable {
    let method: String
    let notes: String?
    let date: String
    let amount: Decimal

    /// Custom decoding to handle numeric values
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        method = try container.decode(String.self, forKey: .method)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        date = try container.decode(String.self, forKey: .date)

        if let doubleValue = try? container.decode(Double.self, forKey: .amount) {
            amount = Decimal(doubleValue)
        } else if let intValue = try? container.decode(Int.self, forKey: .amount) {
            amount = Decimal(intValue)
        } else {
            amount = 0
        }
    }

    private enum CodingKeys: String, CodingKey {
        case method
        case notes
        case date
        case amount
    }

    /// Absolute amount (payouts are stored as negative)
    var absoluteAmount: Decimal {
        abs(amount)
    }

    /// Formatted payment method display
    var methodDisplay: String {
        switch method.lowercased() {
        case "bank_transfer", "bank transfer": return "Bank Transfer"
        case "cash": return "Cash"
        case "paypal": return "PayPal"
        default: return method.capitalized
        }
    }
}

// MARK: - Pre-Repair Checklist

/// Pre-repair checklist results
struct PreRepairChecklist: Codable, Sendable {
    let id: String
    let templateName: String
    let results: ChecklistResults
    let completedAt: Date
    let completedByName: String?

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case id, templateName, results, completedAt, completedByName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        templateName = try container.decode(String.self, forKey: .templateName)
        results = try container.decode(ChecklistResults.self, forKey: .results)
        completedByName = try container.decodeIfPresent(String.self, forKey: .completedByName)
        if let str = try? container.decode(String.self, forKey: .completedAt) {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            completedAt = iso.date(from: str) ?? Date()
        } else { completedAt = Date() }
    }
}

// MARK: - Checklist Results

/// Checklist results can be grouped by category or flat list
enum ChecklistResults: Codable, Sendable {
    case grouped(groups: [String: [String: ChecklistItem]])
    case flat([FlatChecklistItem])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try grouped format first (object with "groups" key or direct groups)
        if let grouped = try? container.decode(GroupedChecklistResults.self) {
            self = .grouped(groups: grouped.groups)
        } else if let groups = try? container.decode([String: [String: ChecklistItem]].self) {
            self = .grouped(groups: groups)
        } else if let flat = try? container.decode([FlatChecklistItem].self) {
            self = .flat(flat)
        } else {
            // Default to empty flat list
            self = .flat([])
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .grouped(let groups):
            try container.encode(GroupedChecklistResults(groups: groups))
        case .flat(let items):
            try container.encode(items)
        }
    }

    /// All items as flat list for display
    var allItems: [FlatChecklistItem] {
        switch self {
        case .grouped(let groups):
            var items: [FlatChecklistItem] = []
            for (groupName, groupItems) in groups.sorted(by: { $0.key < $1.key }) {
                for (itemName, item) in groupItems.sorted(by: { $0.key < $1.key }) {
                    items.append(FlatChecklistItem(
                        group: groupName,
                        name: itemName,
                        status: item.status,
                        notes: item.notes
                    ))
                }
            }
            return items
        case .flat(let items):
            return items
        }
    }
}

/// Grouped checklist results wrapper
struct GroupedChecklistResults: Codable, Sendable {
    let groups: [String: [String: ChecklistItem]]
}

/// Individual checklist item result
struct ChecklistItem: Codable, Sendable {
    let status: String  // "pass", "fail", "omit", "not_tested", "not_applicable"
    let notes: String?

    /// Status as enum
    var checklistStatus: ChecklistItemStatus {
        ChecklistItemStatus(rawValue: status) ?? .notTested
    }
}

/// Flat checklist item with group name
struct FlatChecklistItem: Codable, Sendable {
    let group: String?
    let name: String
    let status: String
    let notes: String?

    /// Status as enum
    var checklistStatus: ChecklistItemStatus {
        ChecklistItemStatus(rawValue: status) ?? .notTested
    }
}

/// Checklist item status
enum ChecklistItemStatus: String, Codable, Sendable {
    case pass
    case fail
    case omit
    case notTested = "not_tested"
    case notApplicable = "not_applicable"

    var label: String {
        switch self {
        case .pass: return "Pass"
        case .fail: return "Fail"
        case .omit: return "Omitted"
        case .notTested: return "Not Tested"
        case .notApplicable: return "N/A"
        }
    }

    var color: Color {
        switch self {
        case .pass: return .green
        case .fail: return .red
        case .omit: return .orange
        case .notTested: return .gray
        case .notApplicable: return .gray
        }
    }

    var icon: String {
        switch self {
        case .pass: return "checkmark.circle.fill"
        case .fail: return "xmark.circle.fill"
        case .omit: return "minus.circle.fill"
        case .notTested: return "questionmark.circle"
        case .notApplicable: return "slash.circle"
        }
    }
}
