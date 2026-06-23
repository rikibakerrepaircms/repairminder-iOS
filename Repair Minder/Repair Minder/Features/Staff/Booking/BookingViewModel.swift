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

    /// Steps the wizard actually walks through given the current intake method.
    /// walk_in keeps the full 5-step flow; mail_in / courier drop Devices and
    /// Signature since the order is created in awaiting_device with neither.
    var visibleSteps: [BookingStep] {
        if formData.intakeMethod.collectsDevicesAndSignature {
            return BookingStep.allCases
        }
        return BookingStep.allCases.filter { $0 != .devices && $0 != .signature }
    }

    /// Key of the last data-collection step (i.e. the step whose primary
    /// button submits the booking). For walk_in this is .signature; for
    /// mail_in / courier this collapses to .summary.
    var submitStepKey: BookingStep {
        visibleSteps.dropLast().last ?? .client
    }

    private var currentVisibleIndex: Int {
        visibleSteps.firstIndex(of: currentStep) ?? 0
    }

    var canGoBack: Bool {
        currentVisibleIndex > 0 && currentStep != .confirmation
    }

    var canGoNext: Bool {
        currentVisibleIndex < visibleSteps.count - 1
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
            return true
        case .signature:
            guard formData.hasValidSignature else { return false }
            return formData.allAftermarketConsented
        case .confirmation:
            return true
        }
    }

    func goBack() {
        guard canGoBack else { return }
        currentStep = visibleSteps[currentVisibleIndex - 1]
    }

    func goNext() {
        guard canGoNext && isCurrentStepValid else { return }
        currentStep = visibleSteps[currentVisibleIndex + 1]
    }

    func goToStep(_ step: BookingStep) {
        // Can only go to previous visible steps or current
        guard let targetIndex = visibleSteps.firstIndex(of: step) else { return }
        if targetIndex <= currentVisibleIndex {
            currentStep = step
        }
    }

    /// Called when the staff flips intake method on the Customer step.
    /// If we'd accidentally been on a step that just got filtered out
    /// (shouldn't be possible from the UI, but guard anyway), bounce to client.
    func onIntakeMethodChanged() {
        if !visibleSteps.contains(currentStep) {
            currentStep = .client
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
        formData.email = client.email ?? ""
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

            // 4. Map service type + intake method to backend intake_method.
            // Backend INTAKE_METHODS: walk_in, mail_in, courier, counter_sale,
            // accessories_in_store. Accessories and device-sale always have
            // fixed backend values; repair/buyback honour the staff's pick of
            // walk_in / mail_in / courier on the Customer step.
            let intakeMethod: String
            switch formData.serviceType {
            case .accessories:
                intakeMethod = "accessories_in_store"
            case .deviceSale:
                intakeMethod = "counter_sale"
            case .repair, .buyback:
                intakeMethod = formData.intakeMethod.rawValue
            }

            // Drop-off signature only applies when the customer is physically
            // present. mail_in / courier orders sign on collection later.
            let signaturePayload: CreateOrderRequest.SignatureData? =
                formData.intakeMethod.collectsDevicesAndSignature
                ? CreateOrderRequest.SignatureData(
                    signatureData: formData.signatureType == .drawn ? formData.signatureData : nil,
                    typedName: formData.signatureType == .typed && !formData.typedName.isEmpty ? formData.typedName : nil,
                    signatureMethod: formData.signatureType.rawValue,
                    termsAgreed: formData.termsAgreed,
                    marketingConsent: formData.marketingConsent,
                    userAgent: userAgent,
                    geolocation: nil
                )
                : nil

            // 5. Create order — skip if already created on a previous attempt
            // (prevents duplicate orders when the user taps Submit after a device-POST failure).
            let orderId: String
            let orderNumber: Int

            if let existingId = formData.createdOrderId,
               let existingNumber = formData.createdOrderNumber {
                // Order already exists server-side — reuse its id/number.
                orderId = existingId
                orderNumber = existingNumber
                logger.info("Reusing existing order \(existingNumber) for retry")
            } else {
                // 5a. Build order request
                let orderRequest = CreateOrderRequest(
                    guestCheckout: nil,
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
                    signature: signaturePayload
                )

                // 5b. POST — throws to outer catch on failure (order not yet created)
                let orderResponse: OrderCreateResponse = try await APIClient.shared.request(
                    .createOrder, body: orderRequest
                )

                orderId = orderResponse.id
                orderNumber = orderResponse.orderNumber

                // Persist immediately so a retry never re-posts the order.
                formData.createdOrderId = orderId
                formData.createdOrderNumber = orderNumber
                formData.createdTicketId = orderResponse.ticketId
            }

            // 6. Add each device and capture IDs for line item creation (best-effort —
            // a device POST failure is non-fatal; staff can add devices from Order Detail).
            var deviceIdMap: [(device: BookingDeviceEntry, apiId: String)] = []
            var deviceWarnings: [String] = []

            for device in formData.devices {
                do {
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
                        },
                        aftermarketConsent: device.aftermarketConsent ? 1 : 0
                    )

                    let response: DeviceCreateResponse = try await APIClient.shared.request(
                        .createOrderDevice(orderId: orderId),
                        body: deviceRequest
                    )
                    deviceIdMap.append((device: device, apiId: response.id))
                } catch {
                    // Non-fatal — log and collect. Staff can add the device from Order Detail.
                    let name = [device.customBrand, device.customModel].compactMap { $0 }.joined(separator: " ")
                    logger.error("Failed to add device '\(name)' to order \(orderId): \(error)")
                    deviceWarnings.append("Device '\(name.isEmpty ? "unknown" : name)' could not be added — add it from Order Detail.")
                }
            }

            // 7. Create line items per device (best-effort — order still valid if items fail)
            for (device, apiDeviceId) in deviceIdMap {
                for item in device.lineItems {
                    do {
                        let netPrice = item.unitPrice / (1 + item.vatRate / 100)
                        let itemRequest = OrderItemRequest(
                            itemType: item.itemType,
                            description: item.description,
                            quantity: item.quantity,
                            unitPrice: netPrice,
                            priceIncVat: item.unitPrice,
                            vatRate: item.vatRate,
                            deviceId: apiDeviceId,
                            isWarrantyItem: nil,
                            warrantyNotes: nil,
                            productTypeId: item.productTypeId,
                            qualityTier: item.qualityTier.isEmpty ? nil : item.qualityTier
                        )
                        try await APIClient.shared.requestVoid(
                            .createOrderItem(orderId: orderId),
                            body: itemRequest
                        )
                    } catch {
                        // Non-fatal — log and continue. Staff can add items from Order Detail.
                        logger.error("Failed to create line item '\(item.description)' for device \(apiDeviceId): \(error)")
                    }
                }
            }

            // 8. Surface any device warnings as a non-fatal message, then confirm
            if !deviceWarnings.isEmpty {
                submitError = deviceWarnings.joined(separator: "\n")
            }

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

/// Response from POST /api/orders/:orderId/devices
/// APIClient unwraps the `data` envelope, so we decode the inner object.
struct DeviceCreateResponse: Decodable {
    let id: String
}

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
