//
//  BookingFormData.swift
//  Repair Minder
//

import SwiftUI

/// Represents a device being added to a booking
struct BookingDeviceEntry: Identifiable, Equatable {
    let id: UUID
    var brandId: String?
    var modelId: String?
    var customBrand: String?
    var customModel: String?
    var displayName: String
    var serialNumber: String
    var imei: String
    var colour: String
    var storageCapacity: String
    var passcode: String
    var passcodeType: PasscodeType
    var findMyStatus: FindMyStatus
    var conditionGrade: ConditionGrade
    var customerReportedIssues: String
    var deviceTypeId: String?
    var workflowType: WorkflowType
    var accessories: [BookingAccessoryItem]
    var lineItems: [BookingLineItem]
    var aftermarketConsent: Bool
    /// What the device check found, carried through so it lands on the device
    /// row rather than living only in the lookup history.
    var rmcheckLookupId: String?
    var blacklistStatus: String?

    /// What we agreed to pay for a buyback device, as typed. Kept as a String
    /// because it is bound to a text field; parsed once on submit.
    /// Defaulted so existing call sites keep their shorter memberwise init.
    var agreedPrice: String = ""

    /// Photos captured during booking, before the order exists. Uploaded on
    /// submit once the device has a server id. Already compressed to <= 150KB
    /// by ImageCompressor, so holding them in memory is cheap.
    var pendingPhotos: [PlatformImageData] = []

    /// Whether any line item has an aftermarket quality tier
    var hasAftermarketItems: Bool {
        lineItems.contains { $0.qualityTier.lowercased().contains("aftermarket") }
    }

    /// Sum of all line item prices (inc VAT)
    var lineItemSubtotal: Double {
        lineItems.reduce(0) { $0 + $1.unitPrice * Double($1.quantity) }
    }

    /// Condition grades matching backend values (A/B/C/D/F)
    enum ConditionGrade: String, CaseIterable, Identifiable {
        case a = "A"
        case b = "B"
        case c = "C"
        case d = "D"
        case f = "F"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .a: return "A - Excellent"
            case .b: return "B - Good"
            case .c: return "C - Fair"
            case .d: return "D - Poor"
            case .f: return "F - Faulty"
            }
        }
    }

    /// Passcode type matching backend values
    enum PasscodeType: String, CaseIterable, Identifiable {
        case none = "none"
        case pin = "pin"
        case pattern = "pattern"
        case password = "password"
        case biometric = "biometric"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .none: return "None"
            case .pin: return "PIN"
            case .pattern: return "Pattern"
            case .password: return "Password"
            case .biometric: return "Biometric"
            }
        }
    }

    /// Find My status matching backend values
    enum FindMyStatus: String, CaseIterable, Identifiable {
        case enabled = "enabled"
        case disabled = "disabled"
        case unknown = "unknown"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .enabled: return "Enabled"
            case .disabled: return "Disabled"
            case .unknown: return "Unknown"
            }
        }
    }

    enum WorkflowType: String, CaseIterable, Identifiable {
        case repair = "repair"
        case buyback = "buyback"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .repair: return "Repair"
            case .buyback: return "Buyback"
            }
        }
    }

    static func empty(workflowType: WorkflowType = .repair) -> BookingDeviceEntry {
        BookingDeviceEntry(
            id: UUID(),
            brandId: nil,
            modelId: nil,
            customBrand: nil,
            customModel: nil,
            displayName: "",
            serialNumber: "",
            imei: "",
            colour: "",
            storageCapacity: "",
            passcode: "",
            passcodeType: .none,
            findMyStatus: .unknown,
            // Default to B (Good) — most walk-in devices are in working condition
            // with minor cosmetic wear. Staff can adjust during intake if needed.
            conditionGrade: .b,
            customerReportedIssues: "",
            deviceTypeId: nil,
            workflowType: workflowType,
            accessories: [],
            lineItems: [],
            aftermarketConsent: false,
            agreedPrice: "",
            pendingPhotos: []
        )
    }
}

/// A service line item added to a device during booking
struct BookingLineItem: Identifiable, Equatable {
    let id: UUID
    var productTypeId: String
    var description: String
    var quantity: Int
    var unitPrice: Double       // VAT-inclusive price (matches web pattern)
    var vatRate: Double          // e.g. 20.0 for 20%
    var itemType: String         // "repair", "accessory"
    var qualityTier: String      // "" = no tier, "Aftermarket", "Premium", etc.

    static func empty() -> BookingLineItem {
        BookingLineItem(
            id: UUID(),
            productTypeId: "",
            description: "",
            quantity: 1,
            unitPrice: 0,
            vatRate: 20,
            itemType: "repair",
            qualityTier: ""
        )
    }
}

/// An accessory item attached to a device during booking
struct BookingAccessoryItem: Identifiable, Equatable {
    let id: UUID
    var accessoryType: String    // "charger", "cable", "case", "sim_card", "stylus", "box", "sd_card", "other"
    var description: String

    static func empty() -> BookingAccessoryItem {
        BookingAccessoryItem(id: UUID(), accessoryType: "other", description: "")
    }
}

/// Drop-off vs doorstep collection vs mail-in vs courier, matching the same
/// options as the web booking wizard and the ticket→order conversion modal.
/// Drives whether the wizard collects devices + a drop-off signature or
/// creates the order in awaiting_device with neither.
enum BookingIntakeMethod: String, CaseIterable, Identifiable, Sendable {
    case walkIn = "walk_in"
    case collection = "collection"
    case mailIn = "mail_in"
    case courier = "courier"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .walkIn: return "Walk-in"
        case .collection: return "Collection"
        case .mailIn: return "Mail-in"
        case .courier: return "Courier"
        }
    }

    var description: String {
        switch self {
        case .walkIn: return "Customer is present"
        case .collection: return "We collect from the customer"
        case .mailIn: return "Device will be posted"
        case .courier: return "Courier will collect"
        }
    }

    /// Whether the wizard should collect devices + a drop-off signature.
    /// walk_in and collection do — the customer is standing there either way,
    /// and the backend requires a signature for both. mail_in / courier skip
    /// both; the order is created in awaiting_device status with no devices.
    var collectsDevicesAndSignature: Bool {
        self == .walkIn || self == .collection
    }
}

/// Complete form data for a booking
struct BookingFormData {
    // Service type
    var serviceType: ServiceType = .repair

    // Intake method (drop-off vs mail-in vs courier). Only meaningful for
    // repair/buyback; accessories and device-sale always map to their own
    // backend intake methods regardless of this value.
    var intakeMethod: BookingIntakeMethod = .walkIn

    // Guest checkout (accessories only)
    var guestCheckout: Bool = false

    // Client info
    var email: String = ""
    var noEmail: Bool = false
    var existingClientId: String?
    var existingClient: Client?
    var firstName: String = ""
    var lastName: String = ""
    var phone: String = ""
    var countryCode: String = ""

    // Address
    var addressLine1: String = ""
    var addressLine2: String = ""
    var city: String = ""
    var county: String = ""
    var postcode: String = ""
    var country: String = ""

    // Location
    var locationId: String = ""

    // Ticket linking (optional - link booking to existing enquiry)
    var existingTicketId: String?

    // Devices
    var devices: [BookingDeviceEntry] = []

    // Ready-by
    var readyByDate: Date?
    var readyByTime: Date?

    // Internal note (optional - added to ticket as a 'note' type message)
    var internalNotes: String = ""

    // Pre-authorisation (optional)
    var preAuthEnabled: Bool = false
    var preAuthAmount: String = ""    // String for text field, convert to Double on submit
    var preAuthNotes: String = ""
    var preAuthManuallyEdited: Bool = false  // Stops auto-calc once staff edits the amount

    /// Total of all line items across all devices (inc VAT)
    var lineItemTotal: Double {
        devices.reduce(0) { $0 + $1.lineItemSubtotal }
    }

    // Signature (bindings for CustomerSignatureView)
    var signatureType: CustomerSignatureView.SignatureType = .typed
    var typedName: String = ""
    var drawnSignature: PlatformImage?  // Platform image from canvas drawing
    var termsAgreed: Bool = false
    var marketingConsent: Bool = true

    /// Computed signature data for the backend.
    /// For drawn: returns "data:image/png;base64,..." string.
    /// For typed: returns nil (typed name is sent separately via typedName field).
    var signatureData: String? {
        switch signatureType {
        case .typed:
            return nil  // typed name sent via typedName field, not signatureData
        case .drawn:
            guard let image = drawnSignature, let data = image.pngData() else { return nil }
            return "data:image/png;base64," + data.base64EncodedString()
        }
    }

    // Result
    var createdOrderId: String?
    var createdOrderNumber: Int?
    var createdTicketId: String?

    // Computed
    var clientDisplayName: String {
        if !firstName.isEmpty || !lastName.isEmpty {
            return [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        }
        return email
    }

    var hasValidClient: Bool {
        (!firstName.isEmpty || !lastName.isEmpty) && (noEmail || isValidEmail(email))
    }

    /// Whether all devices with aftermarket items have consent
    var allAftermarketConsented: Bool {
        devices.allSatisfy { !$0.hasAftermarketItems || $0.aftermarketConsent }
    }

    var hasDevices: Bool {
        !devices.isEmpty
    }

    var hasValidSignature: Bool {
        guard termsAgreed else { return false }
        switch signatureType {
        case .typed:
            return !typedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .drawn:
            return drawnSignature != nil
        }
    }

    var requiresAddress: Bool {
        serviceType == .buyback || devices.contains { $0.workflowType == .buyback }
    }

    var hasValidAddress: Bool {
        !addressLine1.isEmpty && !city.isEmpty && !postcode.isEmpty && !country.isEmpty
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    static var empty: BookingFormData {
        BookingFormData()
    }
}

// MARK: - API Request Bodies

/// Request body for creating an order
struct CreateOrderRequest: Encodable {
    let guestCheckout: Bool?
    let clientEmail: String?
    let noEmail: Bool?
    let clientFirstName: String?
    let clientLastName: String?
    let clientPhone: String?
    let clientCountryCode: String?
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let county: String?
    let postcode: String?
    let country: String?
    let locationId: String?
    let intakeMethod: String
    let readyBy: String?
    let existingTicketId: String?
    let notes: String?              // Internal note added to ticket (backend: body.notes)
    let preAuthorization: PreAuthPayload?
    let signature: SignatureData?

    // IMPORTANT: addressLine1/addressLine2 need explicit keys because
    // .convertToSnakeCase produces "address_line1" but backend expects "address_line_1"
    private enum CodingKeys: String, CodingKey {
        case addressLine1 = "address_line_1"
        case addressLine2 = "address_line_2"
        case guestCheckout, clientEmail, noEmail, clientFirstName, clientLastName
        case clientPhone, clientCountryCode, city, county, postcode, country
        case locationId, intakeMethod, readyBy
        case existingTicketId, notes, preAuthorization, signature
    }

    struct SignatureData: Encodable {
        let signatureData: String?
        let typedName: String?
        let signatureMethod: String    // "drawn" or "typed" — NOTE: backend does not read this field, but it's harmless extra data
        let termsAgreed: Bool
        let marketingConsent: Bool
        let userAgent: String
        let geolocation: GeoPayload?
    }
}

struct GeoPayload: Encodable {
    let latitude: Double
    let longitude: Double
}

/// Request body for adding a device to an order
struct CreateOrderDeviceRequest: Encodable {
    let brandId: String?
    let modelId: String?
    let customBrand: String?
    let customModel: String?
    let serialNumber: String?
    let imei: String?
    let colour: String?
    let storageCapacity: String?
    let passcode: String?
    let passcodeType: String?           // "none", "pin", "pattern", "password", "biometric"
    let findMyStatus: String?           // "enabled", "disabled", "unknown"
    let conditionGrade: String?         // "A", "B", "C", "D", "F"
    let customerReportedIssues: String?
    let deviceTypeId: String?
    let workflowType: String
    let accessories: [AccessoryPayload]?
    let aftermarketConsent: Int?
    let rmcheckLookupId: String?
    let blacklistStatus: String?
}

struct AccessoryPayload: Encodable {
    let accessoryType: String
    let description: String
}

/// Pre-authorisation payload for order creation
struct PreAuthPayload: Encodable {
    let amount: Double
    let notes: String?
    let authorizedAt: String
}
