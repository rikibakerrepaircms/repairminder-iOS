//
//  DeviceEntryFormView.swift
//  Repair Minder
//

import SwiftUI

struct DeviceEntryFormView: View {
    @Bindable var viewModel: BookingViewModel
    let editingDevice: BookingDeviceEntry?
    let defaultWorkflowType: BookingDeviceEntry.WorkflowType
    let onSave: (BookingDeviceEntry) -> Void
    let onCancel: () -> Void

    @State private var device: BookingDeviceEntry
    @State private var deviceSearchQuery: String = ""
    @State private var isLookingUp = false
    @State private var lookupError: String?
    @State private var lookupWarning: String?
    /// Checks that did not come back. Distinct from a warning: nothing is known
    /// to be wrong, but nothing was confirmed either, and for a purchase that
    /// difference is the whole point.
    @State private var lookupUnknowns: [String] = []
    /// Set when the lookup CONFIRMED the device is reported lost or stolen.
    /// Separate from lookupWarning because this one blocks: we will not buy a
    /// stolen handset, whereas Find My being on is the customer's to resolve.
    @State private var lookupBlocked = false
    /// The identifier the last completed check ran against. Guards against
    /// re-billing the same device: the blacklist service is $0.10 a call, so it
    /// must never fire twice for one identifier, nor on every keystroke.
    @State private var lastCheckedIdentifier: String?
    @State private var isShowingCamera = false

    init(
        viewModel: BookingViewModel,
        editingDevice: BookingDeviceEntry?,
        defaultWorkflowType: BookingDeviceEntry.WorkflowType,
        onSave: @escaping (BookingDeviceEntry) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.editingDevice = editingDevice
        self.defaultWorkflowType = defaultWorkflowType
        self.onSave = onSave
        self.onCancel = onCancel
        self._device = State(initialValue: editingDevice ?? BookingDeviceEntry.empty(workflowType: defaultWorkflowType))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text(editingDevice != nil ? "Edit Device" : "Add Device")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onCancel)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Buying: the identifier leads. Everything below is filled FROM the
            // lookup, so asking for brand and model first is asking staff to type
            // what we are about to tell them - and it buries the one check that
            // decides whether we may buy the device at all.
            if device.workflowType == .buyback {
                buybackIdentifyFirst
            }

            // Brand & Model Selection (unified search)
            DeviceSearchPicker(
                viewModel: viewModel,
                selectedBrandId: $device.brandId,
                selectedModelId: $device.modelId,
                customBrand: $device.customBrand,
                customModel: $device.customModel,
                displayName: $device.displayName
            )

            // Device Type
            // Device types: only show custom (non-system) types.
            // System types like "Repair" and "Buyback" are workflow markers,
            // not user-selectable categories.
            let selectableTypes = viewModel.deviceTypes.filter { $0.isSystem != true }
            if !selectableTypes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Device Type")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectableTypes) { type in
                                Button {
                                    device.deviceTypeId = type.id
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: type.systemImage)
                                        Text(type.name)
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(device.deviceTypeId == type.id ? Color.accentColor : Color.platformGray6)
                                    .foregroundStyle(device.deviceTypeId == type.id ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // Identification
            VStack(alignment: .leading, spacing: 12) {
                Text("Identification")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                // For a buyback these live at the top of the form instead - see
                // buybackIdentifyFirst. Rendering them twice would put two
                // editors on one binding on the same screen.
                if device.workflowType != .buyback {
                    HStack(spacing: 12) {
                        FormTextField(
                            label: "Serial Number",
                            text: $device.serialNumber,
                            placeholder: "ABC123XYZ"
                        )

                        FormTextField(
                            label: "IMEI",
                            text: $device.imei,
                            placeholder: "123456789012345",
                            keyboardType: .numberPad
                        )
                    }

                    // One lookup fills the model, colour and storage, and tells
                    // us whether the device is locked or reported stolen before
                    // any money changes hands.
                    deviceCheckRow
                }

                HStack(spacing: 12) {
                    FormTextField(
                        label: "Colour",
                        text: $device.colour,
                        placeholder: "Black"
                    )

                    FormTextField(
                        label: "Storage",
                        text: $device.storageCapacity,
                        placeholder: "256GB"
                    )
                }

                if device.workflowType == .buyback {
                    FormTextField(
                        label: "Agreed price",
                        text: $device.agreedPrice,
                        placeholder: "297.00",
                        keyboardType: .decimalPad
                    )
                }

                devicePhotosSection
            }

            // Security
            VStack(alignment: .leading, spacing: 12) {
                Text("Security")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Passcode Type")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Picker("Passcode Type", selection: $device.passcodeType) {
                            ForEach(BookingDeviceEntry.PasscodeType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(12)
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if device.passcodeType != .none && device.passcodeType != .biometric {
                        FormTextField(
                            label: device.passcodeType == .pin ? "PIN Code" : "Passcode",
                            text: $device.passcode,
                            placeholder: device.passcodeType == .pin ? "1234" : "****"
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Find My Status")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Find My", selection: $device.findMyStatus) {
                        ForEach(BookingDeviceEntry.FindMyStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // Condition & Issues
            VStack(alignment: .leading, spacing: 12) {
                Text("Condition")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Condition Grade")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Condition", selection: $device.conditionGrade) {
                        ForEach(BookingDeviceEntry.ConditionGrade.allCases) { grade in
                            Text(grade.displayName).tag(grade)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(12)
                    .background(Color.platformGray6)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Customer Reported Issues")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextEditor(text: $device.customerReportedIssues)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Accessories
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Accessories Included")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        device.accessories.append(BookingAccessoryItem.empty())
                    } label: {
                        Label("Add", systemImage: "plus.circle")
                            .font(.caption)
                    }
                }

                if !device.accessories.isEmpty {
                    ForEach($device.accessories) { $accessory in
                        HStack(spacing: 8) {
                            Picker("Type", selection: $accessory.accessoryType) {
                                Text("Charger").tag("charger")
                                Text("Cable").tag("cable")
                                Text("Case").tag("case")
                                Text("SIM Card").tag("sim_card")
                                Text("Box").tag("box")
                                Text("Other").tag("other")
                            }
                            .pickerStyle(.menu)

                            TextField("Description (optional)", text: $accessory.description)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                device.accessories.removeAll { $0.id == accessory.id }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }

            // Save Button
            Button {
                onSave(device)
            } label: {
                Text(editingDevice != nil ? "Update Device" : "Add Device")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValid ? Color.accentColor : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isValid)
        }
        .padding()
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    private var isValid: Bool {
        let hasDisplayName = !device.displayName.trimmingCharacters(in: .whitespaces).isEmpty
        let hasBrandOrCustomBrand = device.brandId != nil || !(device.customBrand ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        // A device confirmed as reported lost or stolen cannot be added to a
        // buyback at all. Warning and carrying on is not a gate.
        if lookupBlocked { return false }
        // And a buyback device may not be added without the check having
        // actually run against the identifier now in the form. Otherwise the
        // gate is optional, which is the same as not having one.
        if device.workflowType == .buyback && lastCheckedIdentifier != lookupIdentifier {
            return false
        }
        return hasDisplayName && hasBrandOrCustomBrand
    }

    // MARK: - Identify First (buyback)

    /// The identifier and its check, given top billing on a purchase.
    ///
    /// One lookup fills the model, colour, storage and serial, and answers the
    /// two questions that decide whether we may buy at all: is Find My still on,
    /// and is it reported lost or stolen. Everything else on this form follows
    /// from it, so it goes first and looks like the primary action.
    @ViewBuilder
    private var buybackIdentifyFirst: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Start here", systemImage: "barcode.viewfinder")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("Enter the IMEI or serial and check it. That fills the rest of this form and tells us whether we can buy the device.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                FormTextField(
                    label: "IMEI",
                    text: $device.imei,
                    placeholder: "123456789012345",
                    keyboardType: .numberPad
                )

                FormTextField(
                    label: "Serial Number",
                    text: $device.serialNumber,
                    placeholder: "ABC123XYZ"
                )
            }

            deviceCheckRow
        }
        .padding(14)
        .background(Color.platformGray6)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Device Check

    @ViewBuilder
    private var deviceCheckRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await runLookup() }
            } label: {
                HStack(spacing: 6) {
                    if isLookingUp {
                        ProgressView()
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text(isLookingUp ? "Checking..." : "Check device")
                }
                .font(.subheadline)
                .fontWeight(device.workflowType == .buyback ? .semibold : .regular)
                // On a purchase this is the primary action of the whole form, so
                // it is filled rather than a plain row of text.
                .frame(maxWidth: device.workflowType == .buyback ? .infinity : nil)
                .padding(.vertical, device.workflowType == .buyback ? 10 : 0)
                .background(
                    device.workflowType == .buyback
                        ? AnyShapeStyle(lookupIdentifier.isEmpty ? AnyShapeStyle(Color.platformGray6) : AnyShapeStyle(Color.accentColor))
                        : AnyShapeStyle(Color.clear)
                )
                .foregroundStyle(
                    device.workflowType == .buyback && !lookupIdentifier.isEmpty ? Color.white : Color.accentColor
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(isLookingUp || lookupIdentifier.isEmpty)
            // Buying: run the check as soon as a complete IMEI or serial is in,
            // rather than waiting for someone to remember the button. Debounced
            // and keyed on the identifier so a $0.10 blacklist call cannot fire
            // per keystroke or twice for the same device.
            .task(id: autoCheckKey) {
                guard device.workflowType == .buyback else { return }
                guard identifierLooksComplete else { return }
                guard lookupIdentifier != lastCheckedIdentifier else { return }
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard !Task.isCancelled else { return }
                await runLookup()
            }

            // Red, not orange: this is a confirmed reason to stop, and it now
            // sits beside an orange "could not confirm" box. Two orange boxes
            // would flatten the difference between "this device is stolen" and
            // "we did not manage to ask".
            if let lookupWarning {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lookupWarning)
                            .font(.caption)
                            .foregroundStyle(.red)
                        if lookupBlocked {
                            Text("This device cannot be added to a buyback.")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Absence is not innocence. When SICKW withdrew the Apple service the
            // lock field simply stopped arriving and every iPhone showed a clean
            // check for nine days. Saying nothing here would repeat that.
            if !lookupUnknowns.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Not confirmed: \(lookupUnknowns.joined(separator: ", ")). This is not a clean result, it is a missing one, so check the device by hand before paying.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let lookupError {
                Text(lookupError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // A disabled Add button with no explanation reads as a broken app.
            // Say what is missing.
            if device.workflowType == .buyback,
               lastCheckedIdentifier != lookupIdentifier,
               !isLookingUp {
                Text(lookupIdentifier.isEmpty
                     ? "Enter the IMEI or serial. We check Find My and the lost/stolen register before buying."
                     : (identifierLooksComplete
                        ? "Checking Find My and the lost/stolen register..."
                        : "Keep going - we check Find My and the lost/stolen register once the full IMEI or serial is in."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Changes only when the thing we would look up changes, so the debounce
    /// task restarts on a real edit and not on unrelated form state.
    private var autoCheckKey: String {
        "\(device.workflowType == .buyback)|\(lookupIdentifier)"
    }

    /// Is this worth spending a lookup on yet? A part-typed IMEI is not.
    /// IMEIs are 15 digits; Apple serials are 10 to 12 alphanumerics.
    private var identifierLooksComplete: Bool {
        let id = lookupIdentifier
        if id.allSatisfy(\.isNumber) { return id.count == 15 }
        return id.count >= 10
    }

    private var lookupIdentifier: String {
        let imei = device.imei.trimmingCharacters(in: .whitespaces)
        return imei.isEmpty ? device.serialNumber.trimmingCharacters(in: .whitespaces) : imei
    }

    /// Fill what we can from the lookup without clobbering anything already
    /// typed - staff correcting a wrong auto-fill must not be overwritten.
    private func runLookup() async {
        isLookingUp = true
        lookupError = nil
        lookupWarning = nil
        lookupUnknowns = []
        lookupBlocked = false
        defer { isLookingUp = false }

        // Buying, not repairing: also pay for the blacklist check. This is the
        // only point at which we can find out that the device we are about to
        // hand cash over for is reported lost or stolen.
        let forBuyback = device.workflowType == .buyback

        do {
            let result = try await RMCheckService().lookup(
                identifier: lookupIdentifier,
                forBuyback: forBuyback
            )
            let found = result.device

            if (device.customModel ?? "").isEmpty, let model = found.model, !model.isEmpty {
                device.customModel = model
            }
            if (device.customBrand ?? "").isEmpty, let brand = found.brand, !brand.isEmpty {
                device.customBrand = brand
            }
            if device.displayName.trimmingCharacters(in: .whitespaces).isEmpty {
                let composed = [found.brand, found.model].compactMap { $0 }.joined(separator: " ")
                if !composed.isEmpty { device.displayName = composed }
            }
            if device.colour.isEmpty, let colour = found.colour { device.colour = colour }
            if device.storageCapacity.isEmpty, let storage = found.storageCapacity { device.storageCapacity = storage }
            if device.serialNumber.isEmpty, let serial = found.serialNumber { device.serialNumber = serial }
            if device.imei.isEmpty, let imei = found.imei { device.imei = imei }

            // Find My drives whether the device is worth buying at all, so let
            // the lookup set it even if the form already guessed.
            if let fmi = found.findMyStatus?.trimmingCharacters(in: .whitespaces).uppercased() {
                if fmi == "ON" { device.findMyStatus = .enabled }
                else if fmi == "OFF" { device.findMyStatus = .disabled }
            }

            lookupWarning = found.warningSummary.map {
                "Do not pay for this device yet: \($0). Get the customer to resolve it first."
            }
            // Only meaningful when we were actually buying - a repair intake
            // never paid for the blacklist call, so listing it is noise.
            // A confirmed blacklist hit stops the purchase outright. Find My
            // stays a warning: the customer can clear it and come back.
            lookupBlocked = forBuyback && found.isBlacklisted
            lastCheckedIdentifier = lookupIdentifier

            if forBuyback {
                var unknown = found.unconfirmedChecks
                if result.blacklistError != nil {
                    unknown.removeAll { $0.hasPrefix("blacklist") }
                    unknown.append("blacklist (provider unavailable)")
                }
                lookupUnknowns = unknown
            }
        } catch {
            lookupError = "Could not check that IMEI or serial. Enter the details by hand."
        }
    }

    // MARK: - Photos

    @ViewBuilder
    private var devicePhotosSection: some View {
        #if os(iOS)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Photos", systemImage: "camera")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Take photo", systemImage: "plus.circle")
                        .font(.subheadline)
                }
            }

            if device.pendingPhotos.isEmpty {
                Text("Photograph the device now, before the customer signs. These go on their receipt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(device.pendingPhotos.count) photo\(device.pendingPhotos.count == 1 ? "" : "s") ready to upload")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { image in
                if let encoded = PickedImageEncoder.encode(image) {
                    device.pendingPhotos.append(encoded)
                }
            }
        }
        #endif
    }
}

#Preview {
    ScrollView {
        DeviceEntryFormView(
            viewModel: BookingViewModel(),
            editingDevice: nil,
            defaultWorkflowType: .repair,
            onSave: { _ in },
            onCancel: {}
        )
        .padding()
    }
}
