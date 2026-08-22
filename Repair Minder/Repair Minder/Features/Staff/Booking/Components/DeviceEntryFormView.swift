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
    /// Identifiers whose check was run and came back as an error rather than a
    /// result. SICKW blocks Cloudflare egress, so the lookup fails for reasons
    /// that have nothing to do with the handset on the counter - and a provider
    /// we cannot reach must not be able to stop the shop booking a purchase in.
    /// The attempt satisfies the gate; the orange notice says nothing was
    /// confirmed.
    @State private var failedCheckIdentifiers: Set<String> = []
    /// Seconds left before the Find My re-check can be pressed again. A lock only
    /// changes when the customer actually signs out, which is not instant, and
    /// every press is a real charge - so the button goes quiet for 30s and counts
    /// down rather than silently swallowing taps.
    @State private var fmiCooldown = 0
    @State private var isRecheckingFmi = false
    @State private var fmiRecheckNote: String?
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
        // actually been RUN against the identifier now in the form. Otherwise
        // the gate is optional, which is the same as not having one. A check
        // that ran and errored counts as run: refusing the purchase because the
        // provider is unreachable just stops the shop trading.
        if device.workflowType == .buyback && !checkRunForCurrentIdentifier {
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
            // The check is deliberately manual. It used to fire itself once a
            // complete identifier was typed, which meant a provider outage
            // produced an error nobody asked for, on a form nobody had finished
            // filling in. Pressing the button is one action, and it is the
            // operator's.

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

            // Find My is the one problem the customer can fix on the spot, so it
            // gets its own retry. Shown only when the lock is actually on or was
            // never established - nothing to re-check on a device already OFF.
            if device.workflowType == .buyback,
               lastCheckedIdentifier == lookupIdentifier,
               device.findMyStatus == .enabled || lookupUnknowns.contains(where: { $0.hasPrefix("Find My") }) {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        Task { await recheckFindMy() }
                    } label: {
                        HStack(spacing: 6) {
                            if isRecheckingFmi {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isRecheckingFmi
                                 ? "Checking Find My..."
                                 : (fmiCooldown > 0
                                    ? "Check Find My again (\(fmiCooldown)s)"
                                    : "Check Find My again"))
                        }
                        .font(.subheadline)
                    }
                    .disabled(isRecheckingFmi || fmiCooldown > 0)

                    if let fmiRecheckNote {
                        Text(fmiRecheckNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .task(id: fmiCooldown) {
                    guard fmiCooldown > 0 else { return }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    fmiCooldown -= 1
                }
            }

            // Orange, not red: a provider we could not reach is the same class
            // of answer as a check that came back blank - unconfirmed, not
            // proven bad. Red is reserved above for "this device is stolen".
            if let visibleLookupError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(visibleLookupError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // A disabled Add button with no explanation reads as a broken app.
            // Say what is missing.
            if device.workflowType == .buyback,
               !checkRunForCurrentIdentifier,
               !isLookingUp,
               visibleLookupError == nil {
                Text(lookupIdentifier.isEmpty
                     ? "Enter the IMEI or serial, then run the check. We check Find My and the lost/stolen register before buying."
                     : (identifierLooksComplete
                        ? "Run the check to look at Find My and the lost/stolen register before adding this one."
                        : "Keep going - run the check once the full IMEI or serial is in."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Only show a failed check while it still describes what is in the form.
    /// Once the operator edits the identifier the old error is about a different
    /// device, and leaving it up would hide the prompt to check this one.
    private var visibleLookupError: String? {
        guard failedCheckIdentifiers.contains(lookupIdentifier) else { return nil }
        return lookupError
    }

    /// Has the check actually been run against what is in the form now - either
    /// coming back with a result, or coming back as a provider we could not
    /// reach? Both count. Only "never asked" leaves the buyback gate shut.
    private var checkRunForCurrentIdentifier: Bool {
        guard !lookupIdentifier.isEmpty else { return false }
        return lastCheckedIdentifier == lookupIdentifier
            || failedCheckIdentifiers.contains(lookupIdentifier)
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

    /// Re-read the activation lock on its own, without re-running identity.
    private func recheckFindMy() async {
        guard !isRecheckingFmi, fmiCooldown == 0, !lookupIdentifier.isEmpty else { return }
        isRecheckingFmi = true
        fmiRecheckNote = nil
        defer {
            isRecheckingFmi = false
            fmiCooldown = 30
        }

        do {
            let result = try await RMCheckService().recheckFindMy(identifier: lookupIdentifier)
            switch result.findMyStatus?.uppercased() {
            case "ON":
                device.findMyStatus = .enabled
                lookupWarning = "Do not pay for this device yet: Find My is still on. Get the customer to resolve it first."
                fmiRecheckNote = "Still on. Ask the customer to sign out of iCloud, then check again."
            case "OFF":
                device.findMyStatus = .disabled
                lookupWarning = nil
                lookupUnknowns.removeAll { $0.hasPrefix("Find My") }
                fmiRecheckNote = "Find My is off. Good to go."
            default:
                // Never write a guess. Unresolved stays unresolved.
                fmiRecheckNote = "Still could not read the lock status. Check the device by hand."
            }
        } catch {
            fmiRecheckNote = "Could not reach the Find My check. Try again shortly."
        }
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
            // Carry the result onto the device so it reaches the order row.
            device.rmcheckLookupId = result.rmcheckLookupId ?? device.rmcheckLookupId
            device.blacklistStatus = found.blacklistStatus ?? device.blacklistStatus

            if forBuyback {
                var unknown = found.unconfirmedChecks
                if result.blacklistError != nil {
                    unknown.removeAll { $0.hasPrefix("blacklist") }
                    unknown.append("blacklist (provider unavailable)")
                }
                lookupUnknowns = unknown
            }
        } catch {
            // The provider is unreachable often enough (SICKW blocks Cloudflare)
            // that treating it as a hard stop would just stop the shop trading.
            // Record the attempt so the gate opens, and say plainly that nothing
            // was confirmed.
            lookupError = forBuyback
                ? "Could not reach the device check. Nothing has been confirmed about this device, so check Find My and the lost or stolen status by hand before paying. You can still book it in."
                : "Could not check that IMEI or serial. Enter the details by hand."
            failedCheckIdentifiers.insert(lookupIdentifier)
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
