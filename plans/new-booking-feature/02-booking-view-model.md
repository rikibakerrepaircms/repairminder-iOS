# Stage 02: Booking View Model

## Objective

Create the central state management (BookingViewModel) and form data model (BookingFormData) for the booking wizard.

## Dependencies

`[Requires: Stage 01 complete]` - Needs Location, DeviceSearchResult, DeviceType models and new APIEndpoint cases.

## Complexity

**Medium** - Complex state but well-defined structure.

---

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Models/BookingFormData.swift` | Data structure for all booking form fields |
| `Features/Staff/Booking/BookingViewModel.swift` | Observable view model managing wizard state |

---

## Implementation Details

### BookingFormData.swift

```swift
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
            accessories: []
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

/// Complete form data for a booking
struct BookingFormData {
    // Service type
    var serviceType: ServiceType = .repair

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

    // Signature (bindings for CustomerSignatureView)
    var signatureType: CustomerSignatureView.SignatureType = .typed
    var typedName: String = ""
    var drawnSignature: UIImage?  // UIImage from canvas drawing
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
    let clientEmail: String?
    let noEmail: Bool?
    let clientFirstName: String
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
    let signature: SignatureData

    // IMPORTANT: addressLine1/addressLine2 need explicit keys because
    // .convertToSnakeCase produces "address_line1" but backend expects "address_line_1"
    private enum CodingKeys: String, CodingKey {
        case addressLine1 = "address_line_1"
        case addressLine2 = "address_line_2"
        case clientEmail, noEmail, clientFirstName, clientLastName
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
```

### BookingViewModel.swift

```swift
//
//  BookingViewModel.swift
//  Repair Minder
//

// Uses CompanyPublicInfo from Core/Models/CompanyPublicInfo.swift (Stage 01)

import SwiftUI
import os.log

enum BookingStep: Int, CaseIterable, Identifiable {
    case client = 0
    case devices = 1
    case summary = 2
    case signature = 3
    case confirmation = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .client: return "Customer"
        case .devices: return "Devices"
        case .summary: return "Summary"
        case .signature: return "Signature"
        case .confirmation: return "Complete"
        }
    }

    var number: Int {
        rawValue + 1
    }
}

@MainActor
@Observable
final class BookingViewModel {
    // MARK: - State

    var currentStep: BookingStep = .client
    var formData = BookingFormData()

    // Loading states
    var isSubmitting = false
    var isLoadingLocations = false
    var isSearchingDevices = false
    var isSearchingClients = false

    // Data
    var locations: [Location] = []
    var deviceTypes: [DeviceType] = []
    var termsContent: String = ""
    var companyName: String = ""

    // Dynamic company defaults (overwritten by API)
    var currencyCode: String = "GBP"
    var defaultCountryCode: String = "GB"
    var defaultCountryName: String = "United Kingdom"
    var buybackEnabled: Bool = true

    // Device search
    var deviceSearchResults: DeviceSearchResponse?

    // Errors
    var errorMessage: String?
    var submitError: String?

    // Client search
    var clientSearchResults: [Client] = []
    var clientSearchQuery = ""

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "Booking")

    // MARK: - Initialization

    init(serviceType: ServiceType = .repair) {
        formData.serviceType = serviceType
    }

    // MARK: - Navigation

    var canGoBack: Bool {
        currentStep.rawValue > 0 && currentStep != .confirmation
    }

    var canGoNext: Bool {
        currentStep.rawValue < BookingStep.allCases.count - 1
    }

    var isCurrentStepValid: Bool {
        switch currentStep {
        case .client:
            return formData.hasValidClient &&
                   (locations.count < 2 || !formData.locationId.isEmpty) &&
                   (!formData.requiresAddress || formData.hasValidAddress)
        case .devices:
            return formData.hasDevices
        case .summary:
            return true // Always valid, optional fields
        case .signature:
            return formData.hasValidSignature
        case .confirmation:
            return true
        }
    }

    func goBack() {
        guard canGoBack else { return }
        currentStep = BookingStep(rawValue: currentStep.rawValue - 1) ?? .client
    }

    func goNext() {
        guard canGoNext && isCurrentStepValid else { return }
        currentStep = BookingStep(rawValue: currentStep.rawValue + 1) ?? .confirmation
    }

    func goToStep(_ step: BookingStep) {
        // Can only go to previous steps or current
        if step.rawValue <= currentStep.rawValue {
            currentStep = step
        }
    }

    // MARK: - Data Loading

    func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadLocations() }
            group.addTask { await self.loadDeviceTypes() }
            group.addTask { await self.loadTermsAndConditions() }
        }
    }

    func loadLocations() async {
        isLoadingLocations = true
        defer { isLoadingLocations = false }

        do {
            let result: [Location] = try await APIClient.shared.request(.locations)
            locations = result

            // Auto-select if only one location
            if locations.count == 1 {
                formData.locationId = locations[0].id
            }
        } catch {
            logger.error("Failed to load locations: \(error)")
            errorMessage = "Failed to load locations. Please check your connection and try again."
        }
    }

    func loadDeviceTypes() async {
        do {
            let result: [DeviceType] = try await APIClient.shared.request(.deviceTypes)
            deviceTypes = result
        } catch {
            logger.error("Failed to load device types: \(error)")
        }
    }

    func loadTermsAndConditions() async {
        do {
            let result: CompanyPublicInfo = try await APIClient.shared.request(.companyPublicInfo)
            termsContent = result.termsConditions ?? "Terms and conditions have not been configured."
            companyName = result.name ?? ""

            // Apply dynamic company defaults
            currencyCode = result.currencyCode ?? "GBP"
            defaultCountryCode = result.defaultCountryCode ?? "GB"
            defaultCountryName = Locale(identifier: "en").localizedString(forRegionCode: defaultCountryCode) ?? "United Kingdom"
            buybackEnabled = result.buybackEnabled ?? true

            // Set form defaults from company config (only if not already set by selected client)
            if formData.existingClientId == nil {
                formData.countryCode = defaultCountryCode
                formData.country = defaultCountryName
            }
        } catch {
            logger.error("Failed to load terms: \(error)")
            termsContent = "Failed to load terms and conditions."
        }
    }

    // MARK: - Device Search

    func searchDevices(query: String) async {
        guard query.count >= 2 else {
            deviceSearchResults = nil
            return
        }

        isSearchingDevices = true
        defer { isSearchingDevices = false }

        do {
            let result: DeviceSearchResponse = try await APIClient.shared.request(
                .deviceSearch(query: query)
            )
            deviceSearchResults = result
        } catch {
            logger.error("Failed to search devices: \(error)")
            deviceSearchResults = nil
        }
    }

    // MARK: - Client Search

    func searchClients(query: String) async {
        guard query.count >= 2 else {
            clientSearchResults = []
            return
        }

        isSearchingClients = true
        defer { isSearchingClients = false }

        do {
            // Client search returns { clients: [...], email_blocklist: {...} } wrapper
            let result: ClientSearchResponse = try await APIClient.shared.request(
                .clientSearch(query: query)
            )
            clientSearchResults = result.clients
        } catch {
            logger.error("Failed to search clients: \(error)")
            clientSearchResults = []
        }
    }

    func selectClient(_ client: Client) {
        // 1. Immediately populate with search result data (fast UX)
        formData.existingClientId = client.id
        formData.existingClient = client
        formData.email = client.email
        formData.firstName = client.firstName ?? ""
        formData.lastName = client.lastName ?? ""
        formData.phone = client.phone ?? ""
        formData.countryCode = client.countryCode ?? defaultCountryCode
        clientSearchResults = []
        clientSearchQuery = ""

        // 2. Fetch full client details in background for address fields
        Task {
            do {
                let fullClient: Client = try await APIClient.shared.request(.client(id: client.id))
                formData.existingClient = fullClient
                formData.addressLine1 = fullClient.addressLine1 ?? ""
                formData.addressLine2 = fullClient.addressLine2 ?? ""
                formData.city = fullClient.city ?? ""
                formData.county = fullClient.county ?? ""
                formData.postcode = fullClient.postcode ?? ""
                formData.country = fullClient.country ?? defaultCountryName
                if let cc = fullClient.countryCode, !cc.isEmpty {
                    formData.countryCode = cc
                }
            } catch {
                logger.error("Failed to fetch client details: \(error)")
                // Non-fatal — user can still type address manually
            }
        }
    }

    func clearSelectedClient() {
        formData.existingClientId = nil
        formData.existingClient = nil
        formData.email = ""
        formData.firstName = ""
        formData.lastName = ""
        formData.phone = ""
        formData.addressLine1 = ""
        formData.addressLine2 = ""
        formData.city = ""
        formData.county = ""
        formData.postcode = ""
        formData.country = defaultCountryName
        formData.countryCode = defaultCountryCode
    }

    // MARK: - Device Management

    func addDevice(_ device: BookingDeviceEntry) {
        formData.devices.append(device)
    }

    func updateDevice(_ device: BookingDeviceEntry) {
        if let index = formData.devices.firstIndex(where: { $0.id == device.id }) {
            formData.devices[index] = device
        }
    }

    func removeDevice(at index: Int) {
        formData.devices.remove(at: index)
    }

    func removeDevice(id: UUID) {
        formData.devices.removeAll { $0.id == id }
    }

    // MARK: - Submission

    func submit() async {
        isSubmitting = true
        submitError = nil

        do {
            // 1. Build ready-by datetime
            var readyBy: String?
            if let date = formData.readyByDate {
                let formatter = ISO8601DateFormatter()
                if let time = formData.readyByTime {
                    let calendar = Calendar.current
                    let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                    var combined = DateComponents()
                    combined.year = dateComponents.year
                    combined.month = dateComponents.month
                    combined.day = dateComponents.day
                    combined.hour = timeComponents.hour
                    combined.minute = timeComponents.minute
                    if let combinedDate = calendar.date(from: combined) {
                        readyBy = formatter.string(from: combinedDate)
                    }
                } else {
                    readyBy = formatter.string(from: date)
                }
            }

            // 2. Build User-Agent for signature audit trail
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
            let userAgent = "RepairMinder-iOS/\(appVersion).\(buildNumber) (iPhone; iOS \(osVersion))"

            // 3. Build pre-authorization if enabled
            var preAuth: PreAuthPayload?
            if formData.preAuthEnabled,
               let amount = Double(formData.preAuthAmount), amount > 0 {
                preAuth = PreAuthPayload(
                    amount: amount,
                    notes: formData.preAuthNotes.isEmpty ? nil : formData.preAuthNotes,
                    authorizedAt: ISO8601DateFormatter().string(from: Date())
                )
            }

            // 4. Map service type to backend intake method
            // Backend INTAKE_METHODS: walk_in, mail_in, courier, counter_sale, accessories_in_store
            let intakeMethod: String
            switch formData.serviceType {
            case .accessories:
                intakeMethod = "accessories_in_store"
            case .deviceSale:
                intakeMethod = "counter_sale"
            case .repair, .buyback:
                intakeMethod = "walk_in"
            }

            // 5. Create order request
            let orderRequest = CreateOrderRequest(
                clientEmail: formData.noEmail ? nil : formData.email,
                noEmail: formData.noEmail ? true : nil,
                clientFirstName: formData.firstName,
                clientLastName: formData.lastName.isEmpty ? nil : formData.lastName,
                clientPhone: formData.phone.isEmpty ? nil : formData.phone,
                clientCountryCode: formData.countryCode,
                addressLine1: formData.addressLine1.isEmpty ? nil : formData.addressLine1,
                addressLine2: formData.addressLine2.isEmpty ? nil : formData.addressLine2,
                city: formData.city.isEmpty ? nil : formData.city,
                county: formData.county.isEmpty ? nil : formData.county,
                postcode: formData.postcode.isEmpty ? nil : formData.postcode,
                country: formData.country.isEmpty ? nil : formData.country,
                locationId: formData.locationId.isEmpty ? nil : formData.locationId,
                intakeMethod: intakeMethod,
                readyBy: readyBy,
                existingTicketId: formData.existingTicketId,
                notes: formData.internalNotes.isEmpty ? nil : formData.internalNotes,
                preAuthorization: preAuth,
                signature: CreateOrderRequest.SignatureData(
                    signatureData: formData.signatureType == .drawn ? formData.signatureData : nil,
                    typedName: formData.signatureType == .typed && !formData.typedName.isEmpty ? formData.typedName : nil,
                    signatureMethod: formData.signatureType.rawValue,
                    termsAgreed: formData.termsAgreed,
                    marketingConsent: formData.marketingConsent,
                    userAgent: userAgent,
                    geolocation: nil  // TODO: Add CoreLocation support in future
                )
            )

            // 6. Create order
            let orderResponse: OrderCreateResponse = try await APIClient.shared.request(
                .createOrder, body: orderRequest
            )

            let orderId = orderResponse.id
            let orderNumber = orderResponse.orderNumber

            // 7. Add each device
            for device in formData.devices {
                let deviceRequest = CreateOrderDeviceRequest(
                    brandId: device.brandId,
                    modelId: device.modelId,
                    customBrand: device.customBrand,
                    customModel: device.customModel,
                    serialNumber: device.serialNumber.isEmpty ? nil : device.serialNumber,
                    imei: device.imei.isEmpty ? nil : device.imei,
                    colour: device.colour.isEmpty ? nil : device.colour,
                    storageCapacity: device.storageCapacity.isEmpty ? nil : device.storageCapacity,
                    passcode: device.passcode.isEmpty ? nil : device.passcode,
                    passcodeType: device.passcodeType == .none ? nil : device.passcodeType.rawValue,
                    findMyStatus: device.findMyStatus.rawValue,
                    conditionGrade: device.conditionGrade.rawValue,
                    customerReportedIssues: device.customerReportedIssues.isEmpty ? nil : device.customerReportedIssues,
                    deviceTypeId: device.deviceTypeId,
                    workflowType: device.workflowType.rawValue,
                    accessories: device.accessories.isEmpty ? nil : device.accessories.map {
                        AccessoryPayload(accessoryType: $0.accessoryType, description: $0.description)
                    }
                )

                // Note: Backend returns { data: { id: "<device-id>" } } but we don't
                // need it currently. If device IDs are needed later (e.g. for accessories
                // or image uploads during booking), switch to request<T> instead.
                try await APIClient.shared.requestVoid(
                    .createOrderDevice(orderId: orderId),
                    body: deviceRequest
                )
            }

            // 8. Update form data with results
            formData.createdOrderId = orderId
            formData.createdOrderNumber = orderNumber
            formData.createdTicketId = orderResponse.ticketId

            // 9. Move to confirmation
            currentStep = .confirmation

            logger.info("Booking created successfully: Order #\(orderNumber)")

        } catch {
            logger.error("Failed to create booking: \(error)")
            submitError = error.localizedDescription
        }

        isSubmitting = false
    }

    // MARK: - Reset

    func reset() {
        let currentServiceType = formData.serviceType
        formData = BookingFormData()
        formData.serviceType = currentServiceType
        currentStep = .client
        submitError = nil
        clientSearchResults = []
        clientSearchQuery = ""
        deviceSearchResults = nil

        // Re-apply company defaults (these were set during loadTermsAndConditions
        // on first load but are lost when formData is replaced)
        formData.countryCode = defaultCountryCode
        formData.country = defaultCountryName

        // Re-apply single-location auto-selection (originally set during loadLocations)
        if locations.count == 1 {
            formData.locationId = locations[0].id
        }
    }
}

// MARK: - Response Types

struct OrderCreateResponse: Decodable {
    let id: String
    let orderNumber: Int
    let ticketId: String?
}

// CompanyPublicInfo is defined in Core/Models/CompanyPublicInfo.swift (Stage 01)
// Do NOT duplicate it here — the Stage 01 version has optional fields + Bool-or-Int handling.

/// Response from GET /api/clients/search?email=<query>
/// Backend returns { clients: [...], email_blocklist: {...} } wrapper
struct ClientSearchResponse: Decodable {
    let clients: [Client]
    // email_blocklist is available but not needed for the booking flow
}
```

---

## Database Changes

**None** - All state is in-memory.

---

## Test Cases

### Test 1: Step Validation - Client Step
```swift
// Given: Empty form data
let vm = BookingViewModel()
vm.formData.firstName = ""
// Then: isCurrentStepValid should be false

// Given: Valid client data
vm.formData.firstName = "John"
vm.formData.email = "john@example.com"
// Then: isCurrentStepValid should be true
```

### Test 2: Step Navigation
```swift
let vm = BookingViewModel()
// At client step, canGoBack should be false
XCTAssertFalse(vm.canGoBack)

// After going to devices step
vm.currentStep = .devices
XCTAssertTrue(vm.canGoBack)
```

### Test 3: Device Management
```swift
let vm = BookingViewModel()
let device = BookingDeviceEntry.empty()
vm.addDevice(device)
XCTAssertEqual(vm.formData.devices.count, 1)

vm.removeDevice(id: device.id)
XCTAssertEqual(vm.formData.devices.count, 0)
```

---

## Acceptance Checklist

- [ ] `BookingFormData.swift` created with all form fields
- [ ] `BookingDeviceEntry` with all device properties (incl. `passcode`, `passcodeType`, `findMyStatus`)
- [ ] Enums: `ConditionGrade` (A/B/C/D/F), `PasscodeType` (none/pin/pattern/password/biometric), `FindMyStatus`, `WorkflowType`
- [ ] `BookingFormData` has `signatureType`, `typedName`, `drawnSignature: UIImage?` for CustomerSignatureView bindings
- [ ] `signatureData` is a computed `String?` property (base64 data URL or typed name)
- [ ] `CreateOrderRequest` with `existingTicketId`, `notes`, `preAuthorization`, and `userAgent` in signature
- [ ] `BookingFormData` has `internalNotes` field wired to `CreateOrderRequest.notes`
- [ ] `CreateOrderDeviceRequest` includes `passcode`, `passcodeType`, `findMyStatus`
- [ ] `OrderCreateResponse` includes `ticketId`
- [ ] `CompanyPublicInfo` includes all backend fields (`id`, `name`, `logoUrl`, `vatNumber`, `termsConditions`, `privacyPolicy`, `customerPortalUrl`)
- [ ] `ClientSearchResponse` wrapper type for client search (not raw `[Client]`)
- [ ] `PreAuthPayload` struct with `amount`, `notes`, `authorizedAt`
- [ ] `CreateOrderRequest` includes `preAuthorization: PreAuthPayload?`
- [ ] `BookingFormData` has `preAuthEnabled`, `preAuthAmount`, `preAuthNotes`
- [ ] `BookingViewModel.swift` with `@Observable` macro
- [ ] Step navigation (goBack, goNext, goToStep)
- [ ] Step validation (isCurrentStepValid)
- [ ] Data loading methods (locations, device types, T&Cs)
- [ ] Device search method using `.deviceSearch(query:)`
- [ ] Client search using `.clientSearch(query:)` with `ClientSearchResponse` wrapper
- [ ] Device management (add, update, remove)
- [ ] Submit method maps `serviceType` to correct `intakeMethod` (walk_in / accessories_in_store / counter_sale)
- [ ] Submit method with correct API patterns
- [ ] Project compiles without errors

---

## Deployment

```bash
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

---

## Handoff Notes

- BookingViewModel is the central source of truth for the wizard
- Use `@State private var viewModel = BookingViewModel(serviceType:)` in BookingWizardView
- Pass viewModel to child step views via `@Bindable var viewModel: BookingViewModel`
- [See: Stage 04] will use this view model in the wizard container
- [See: Stage 05-08] will use formData bindings for each step

### API Patterns Used
- `APIClient.shared.request<T>(_ endpoint:, body:) async throws -> T` — type inferred from return type
- `APIClient.shared.requestVoid(_ endpoint:, body:)` — for endpoints with no return data
- Use `APIEndpoint` enum cases (`.locations`, `.deviceSearch(query:)`, `.createOrder`, etc.) — NOT `APIEndpoint(path:)`
- Client search uses `.clientSearch(query:)` returning `ClientSearchResponse` (wrapper with `.clients` array)
- Device search uses `.deviceSearch(query:)` returning `DeviceSearchResponse`
- Encoder auto-converts camelCase to snake_case for request bodies
- Decoder auto-converts snake_case to camelCase for responses
