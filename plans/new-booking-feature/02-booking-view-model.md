# Stage 02: Booking View Model

## Objective

Create the central state management (BookingViewModel) and form data model (BookingFormData) for the booking wizard.

## Dependencies

`[Requires: Stage 01 complete]` - Needs Location, Brand, DeviceModel, DeviceType models.

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

import Foundation

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

    enum PasscodeType: String, CaseIterable, Identifiable {
        case none = "none"
        case pin4 = "pin_4"
        case pin6 = "pin_6"
        case pattern = "pattern"
        case password = "password"
        case biometric = "biometric"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .none: return "None"
            case .pin4: return "4-Digit PIN"
            case .pin6: return "6-Digit PIN"
            case .pattern: return "Pattern"
            case .password: return "Password"
            case .biometric: return "Biometric"
            }
        }
    }

    enum FindMyStatus: String, CaseIterable, Identifiable {
        case unknown = "unknown"
        case on = "on"
        case off = "off"
        case removed = "removed"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .unknown: return "Unknown"
            case .on: return "On (Enabled)"
            case .off: return "Off (Disabled)"
            case .removed: return "Removed"
            }
        }
    }

    enum ConditionGrade: String, CaseIterable, Identifiable {
        case excellent = "excellent"
        case good = "good"
        case fair = "fair"
        case poor = "poor"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
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
            conditionGrade: .good,
            customerReportedIssues: "",
            deviceTypeId: nil,
            workflowType: workflowType
        )
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
    var countryCode: String = "GB"

    // Address
    var addressLine1: String = ""
    var addressLine2: String = ""
    var city: String = ""
    var county: String = ""
    var postcode: String = ""
    var country: String = "United Kingdom"

    // Location
    var locationId: String = ""

    // Devices
    var devices: [BookingDeviceEntry] = []

    // Ready-by
    var readyByDate: Date?
    var readyByTime: Date?

    // Signature
    var termsAgreed: Bool = false
    var marketingConsent: Bool = true
    var signatureData: Data?
    var typedName: String = ""

    // Result
    var createdOrderId: String?
    var createdOrderNumber: Int?

    // Computed
    var clientDisplayName: String {
        if !firstName.isEmpty || !lastName.isEmpty {
            return [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        }
        return email
    }

    var hasValidClient: Bool {
        !firstName.isEmpty && (noEmail || isValidEmail(email))
    }

    var hasDevices: Bool {
        !devices.isEmpty
    }

    var hasValidSignature: Bool {
        termsAgreed && (signatureData != nil || !typedName.isEmpty)
    }

    var requiresAddress: Bool {
        devices.contains { $0.workflowType == .buyback }
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
    let serviceType: String
    let readyBy: String?
    let signature: SignatureData?

    struct SignatureData: Encodable {
        let signatureData: String?
        let typedName: String?
        let termsAgreed: Bool
        let marketingConsent: Bool
    }
}

/// Request body for adding a device to an order
struct AddDeviceRequest: Encodable {
    let brandId: String?
    let modelId: String?
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
    let deviceTypeId: String?
    let workflowType: String
}
```

### BookingViewModel.swift

```swift
//
//  BookingViewModel.swift
//  Repair Minder
//

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
    var isLoadingBrands = false
    var isLoadingModels = false
    var isSearchingClients = false

    // Data
    var locations: [Location] = []
    var brands: [Brand] = []
    var deviceTypes: [DeviceType] = []
    var modelsCache: [String: [DeviceModel]] = [:] // brandId -> models

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
            group.addTask { await self.loadBrands() }
            group.addTask { await self.loadDeviceTypes() }
        }
    }

    func loadLocations() async {
        isLoadingLocations = true
        defer { isLoadingLocations = false }

        do {
            // Use APIEndpoint directly - no new definitions needed
            locations = try await APIClient.shared.request(
                APIEndpoint(path: "/api/locations"),
                responseType: [Location].self
            )

            // Auto-select if only one location
            if locations.count == 1 {
                formData.locationId = locations[0].id
            }
        } catch {
            logger.error("Failed to load locations: \(error)")
        }
    }

    func loadBrands() async {
        isLoadingBrands = true
        defer { isLoadingBrands = false }

        do {
            // Use APIEndpoint directly
            brands = try await APIClient.shared.request(
                APIEndpoint(path: "/api/brands"),
                responseType: [Brand].self
            )
        } catch {
            logger.error("Failed to load brands: \(error)")
        }
    }

    func loadDeviceTypes() async {
        do {
            // Use APIEndpoint directly
            deviceTypes = try await APIClient.shared.request(
                APIEndpoint(path: "/api/device-types"),
                responseType: [DeviceType].self
            )
        } catch {
            logger.error("Failed to load device types: \(error)")
        }
    }

    func loadModels(for brandId: String) async -> [DeviceModel] {
        // Return cached if available
        if let cached = modelsCache[brandId] {
            return cached
        }

        isLoadingModels = true
        defer { isLoadingModels = false }

        do {
            // Use APIEndpoint directly with path interpolation
            let models = try await APIClient.shared.request(
                APIEndpoint(path: "/api/brands/\(brandId)/models"),
                responseType: [DeviceModel].self
            )
            modelsCache[brandId] = models
            return models
        } catch {
            logger.error("Failed to load models for brand \(brandId): \(error)")
            return []
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
            // Use existing clients(search:) endpoint - returns ClientsListData
            let response = try await APIClient.shared.request(
                .clients(page: 1, limit: 10, search: query),
                responseType: ClientsListData.self
            )
            clientSearchResults = response.clients
        } catch {
            logger.error("Failed to search clients: \(error)")
            clientSearchResults = []
        }
    }

    func selectClient(_ client: Client) {
        formData.existingClientId = client.id
        formData.existingClient = client
        formData.email = client.email
        formData.firstName = client.firstName ?? ""
        formData.lastName = client.lastName ?? ""
        formData.phone = client.phone ?? ""
        formData.countryCode = client.countryCode ?? "GB"
        clientSearchResults = []
        clientSearchQuery = ""
    }

    func clearSelectedClient() {
        formData.existingClientId = nil
        formData.existingClient = nil
        formData.email = ""
        formData.firstName = ""
        formData.lastName = ""
        formData.phone = ""
        // Keep countryCode based on location
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

            // 2. Build signature data
            let signatureBase64 = formData.signatureData?.base64EncodedString()

            // 3. Create order request
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
                intakeMethod: "walk_in",
                serviceType: formData.serviceType.rawValue,
                readyBy: readyBy,
                signature: CreateOrderRequest.SignatureData(
                    signatureData: signatureBase64,
                    typedName: formData.typedName.isEmpty ? nil : formData.typedName,
                    termsAgreed: formData.termsAgreed,
                    marketingConsent: formData.marketingConsent
                )
            )

            // 4. Create order - use request(_:responseType:) for unwrapped response
            let orderResponse = try await APIClient.shared.request(
                .createOrder(body: orderRequest),
                responseType: OrderCreateResponse.self
            )

            let orderId = orderResponse.id
            let orderNumber = orderResponse.orderNumber

            // 5. Add each device
            for device in formData.devices {
                let deviceRequest = AddDeviceRequest(
                    brandId: device.brandId,
                    modelId: device.modelId,
                    customBrand: device.customBrand,
                    customModel: device.customModel,
                    displayName: device.displayName,
                    serialNumber: device.serialNumber.isEmpty ? nil : device.serialNumber,
                    imei: device.imei.isEmpty ? nil : device.imei,
                    colour: device.colour.isEmpty ? nil : device.colour,
                    storageCapacity: device.storageCapacity.isEmpty ? nil : device.storageCapacity,
                    passcode: device.passcode.isEmpty ? nil : device.passcode,
                    passcodeType: device.passcodeType == .none ? nil : device.passcodeType.rawValue,
                    findMyStatus: device.findMyStatus == .unknown ? nil : device.findMyStatus.rawValue,
                    conditionGrade: device.conditionGrade.rawValue,
                    customerReportedIssues: device.customerReportedIssues.isEmpty ? nil : device.customerReportedIssues,
                    deviceTypeId: device.deviceTypeId,
                    workflowType: device.workflowType.rawValue
                )

                // Use APIEndpoint directly for adding device to order
                try await APIClient.shared.requestVoid(
                    APIEndpoint(path: "/api/orders/\(orderId)/devices", method: .post, body: deviceRequest)
                )
            }

            // 6. Update form data with results
            formData.createdOrderId = orderId
            formData.createdOrderNumber = orderNumber

            // 7. Move to confirmation
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
        formData = BookingFormData()
        formData.serviceType = .repair
        currentStep = .client
        submitError = nil
        clientSearchResults = []
        clientSearchQuery = ""
    }
}

// MARK: - Response Types

struct OrderCreateResponse: Codable {
    let id: String
    let orderNumber: Int
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
- [ ] `BookingDeviceEntry` with all device properties
- [ ] Enums for PasscodeType, FindMyStatus, ConditionGrade, WorkflowType
- [ ] `CreateOrderRequest` and `AddDeviceRequest` for API
- [ ] `BookingViewModel.swift` with Observable macro
- [ ] Step navigation (goBack, goNext, goToStep)
- [ ] Step validation (isCurrentStepValid)
- [ ] Data loading methods (locations, brands, device types)
- [ ] Client search functionality
- [ ] Device management (add, update, remove)
- [ ] Submit method that creates order and devices
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
- Pass viewModel to child step views via environment or as binding
- [See: Stage 04] will use this view model in the wizard container
- [See: Stage 05-08] will use formData bindings for each step

### API Patterns Used
- `APIClient.shared.request(_:responseType:)` - Returns unwrapped T (handles APIResponse internally)
- `APIClient.shared.requestVoid(_:)` - For endpoints with no return data
- Use `APIEndpoint(path:)` directly - no new endpoint definitions needed
- Client search uses existing `clients(search:)` definition with `ClientsListData` response
- Encoder auto-converts camelCase to snake_case for request bodies
- Decoder auto-converts snake_case to camelCase for responses
