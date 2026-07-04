//
//  DeviceDetailView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Device Detail View

/// Full device detail view
struct DeviceDetailView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel: DeviceDetailViewModel
    @State private var showingActionSheet = false
    @State private var selectedAction: DeviceAction?
    @State private var actionNotes = ""
    /// Collected values keyed by the Worker field name (e.g. `"tracking_number"`).
    @State private var collectedInputs: [String: String] = [:]

    // Edit state for notes fields
    @State private var editingDiagnosisNotes = false
    @State private var diagnosisNotesText = ""
    @State private var editingRepairNotes = false
    @State private var repairNotesText = ""

    // Due date editor state
    @State private var showingDueDatePicker = false
    @State private var dueDatePickerValue = Date()

    // Cancel work state
    @State private var showingCancelWorkSheet = false
    @State private var cancelWorkReason = ""

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    /// Formats a `Date` as `yyyy-MM-dd` using the device's LOCAL time zone
    /// (no explicit `timeZone` set → defaults to the system's current time zone).
    private static let localDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    init(orderId: String, deviceId: String) {
        _viewModel = State(initialValue: DeviceDetailViewModel(orderId: orderId, deviceId: deviceId))
    }

    var body: some View {
        Group {
            if let device = viewModel.device {
                deviceContent(device)
            } else if let error = viewModel.error {
                errorView(error)
            } else {
                loadingView
            }
        }
        .navigationTitle(viewModel.device?.displayName ?? "Device")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isUpdating {
                ToolbarItem(placement: .topBarTrailing) {
                    ProgressView()
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            if !viewModel.isLoaded {
                await viewModel.loadDevice()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil && viewModel.isLoaded },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .sheet(isPresented: $showingActionSheet) {
            if let action = selectedAction {
                DeviceActionSheet(
                    action: action,
                    notes: $actionNotes,
                    collectedInputs: $collectedInputs
                ) {
                    // Confirm
                    let capturedNotes = actionNotes.isEmpty ? nil : actionNotes
                    let capturedInputs = collectedInputs
                    showingActionSheet = false
                    selectedAction = nil
                    actionNotes = ""
                    collectedInputs = [:]
                    Task {
                        await viewModel.executeAction(action, notes: capturedNotes, inputs: capturedInputs)
                    }
                } onCancel: {
                    showingActionSheet = false
                    selectedAction = nil
                    actionNotes = ""
                    collectedInputs = [:]
                }
            }
        }
        .sheet(isPresented: $showingDueDatePicker) {
            NavigationStack {
                Form {
                    DatePicker("Due date", selection: $dueDatePickerValue, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
                .navigationTitle("Due Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingDueDatePicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let dateString = Self.localDateFormatter.string(from: dueDatePickerValue)
                            showingDueDatePicker = false
                            Task { await viewModel.updateDevice(.dueDate(dateString)) }
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingCancelWorkSheet) {
            NavigationStack {
                Form {
                    Section("Reason (optional)") {
                        TextEditor(text: $cancelWorkReason)
                            .frame(minHeight: 80)
                    }
                }
                .navigationTitle("Cancel Work")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showingCancelWorkSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Cancel Work", role: .destructive) {
                            let reason = cancelWorkReason.trimmingCharacters(in: .whitespacesAndNewlines)
                            showingCancelWorkSheet = false
                            cancelWorkReason = ""
                            Task { await viewModel.cancelWork(reason: reason.isEmpty ? nil : reason) }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        LottieLoadingView(size: 100, message: "Loading device...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Error Loading Device", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Try Again") {
                Task {
                    await viewModel.loadDevice()
                }
            }
        }
    }

    // MARK: - Device Content

    private func deviceContent(_ device: DeviceDetail) -> some View {
        List {
            // Status and actions
            statusSection(device)

            // Device info
            deviceInfoSection(device)

            // Identifiers
            identifiersSection(device)

            // Issues
            if device.hasIssuesDocumented {
                issuesSection(device)
            }

            // Diagnosis — always shown (notes are editable)
            diagnosisSection(device)

            // Repair — always shown (notes are editable)
            repairSection(device)

            // Line items
            if !device.lineItems.isEmpty {
                lineItemsSection(device)
            }

            // Parts used
            if !device.partsUsed.isEmpty {
                partsSection(device)
            }

            // Accessories
            if !device.accessories.isEmpty {
                accessoriesSection(device)
            }

            // Images
            imagesSection(device)

            // Checklist
            if !device.checklist.isEmpty {
                checklistSection(device)
            }

            // Timestamps
            timestampsSection(device)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(isRegularWidth ? .hidden : .automatic)
        .frame(maxWidth: isRegularWidth ? 700 : .infinity)
        .frame(maxWidth: .infinity)
        .background(isRegularWidth ? Color.platformGroupedBackground : .clear)
    }

    // MARK: - Status Section

    private func statusSection(_ device: DeviceDetail) -> some View {
        Section {
            if isRegularWidth {
                let workflowStatuses = device.workflow == .buyback ? DeviceStatus.buybackStatuses : DeviceStatus.repairStatuses
                Grid(alignment: .topLeading, horizontalSpacing: 32, verticalSpacing: 16) {
                    GridRow {
                        gridField("Status") {
                            Menu {
                                ForEach(workflowStatuses, id: \.self) { s in
                                    Button(s.label) {
                                        Task { await viewModel.updateStatus(to: s) }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    DeviceStatusBadge(status: device.deviceStatus, size: .large)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(viewModel.isUpdating)
                        }
                        gridField("Priority") {
                            Menu {
                                ForEach(DevicePriority.allCases, id: \.self) { p in
                                    Button(p.displayName) {
                                        Task { await viewModel.setPriority(p) }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    PriorityBadge(priority: device.devicePriority)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(viewModel.isUpdating)
                        }
                    }
                    GridRow {
                        gridField("Workflow") {
                            Menu {
                                Button(DeviceWorkflowType.repair.displayName) {
                                    Task { await viewModel.updateDevice(.workflowType(.repair)) }
                                }
                                Button(DeviceWorkflowType.buyback.displayName) {
                                    Task { await viewModel.updateDevice(.workflowType(.buyback)) }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    WorkflowTypeBadge(workflowType: device.workflow)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(viewModel.isUpdating)
                        }
                        if let engineer = device.assignedEngineer {
                            gridField("Assigned To") {
                                Text(engineer.name)
                            }
                        }
                    }
                    GridRow {
                        if let subLocation = device.subLocation {
                            gridField("Location") {
                                VStack(alignment: .leading) {
                                    Text(subLocation.code)
                                    if let description = subLocation.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        gridField("Due") {
                            Button {
                                dueDatePickerValue = device.dueDate.flatMap { DateFormatters.parseISO8601($0) } ?? Date()
                                showingDueDatePicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    if let dueDate = device.formattedDueDate {
                                        Text(dueDate)
                                            .foregroundStyle(device.isOverdue ? .red : .primary)
                                    } else {
                                        Text("Set due date")
                                            .foregroundStyle(.secondary)
                                    }
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isUpdating)
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                // Status — editable via Menu
                let workflowStatuses = device.workflow == .buyback ? DeviceStatus.buybackStatuses : DeviceStatus.repairStatuses
                Menu {
                    ForEach(workflowStatuses, id: \.self) { s in
                        Button(s.label) {
                            Task { await viewModel.updateStatus(to: s) }
                        }
                    }
                } label: {
                    HStack {
                        Text("Status")
                        Spacer()
                        DeviceStatusBadge(status: device.deviceStatus, size: .large)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(viewModel.isUpdating)

                // Priority — editable via Menu
                Menu {
                    ForEach(DevicePriority.allCases, id: \.self) { p in
                        Button(p.displayName) {
                            Task { await viewModel.setPriority(p) }
                        }
                    }
                } label: {
                    HStack {
                        Text("Priority")
                        Spacer()
                        PriorityBadge(priority: device.devicePriority)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(viewModel.isUpdating)

                Menu {
                    Button(DeviceWorkflowType.repair.displayName) {
                        Task { await viewModel.updateDevice(.workflowType(.repair)) }
                    }
                    Button(DeviceWorkflowType.buyback.displayName) {
                        Task { await viewModel.updateDevice(.workflowType(.buyback)) }
                    }
                } label: {
                    HStack {
                        Text("Workflow")
                        Spacer()
                        WorkflowTypeBadge(workflowType: device.workflow)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(viewModel.isUpdating)
                if let engineers = device.availableEngineers, !engineers.isEmpty {
                    Menu {
                        Button("Unassigned") {
                            Task { await viewModel.assignEngineer(nil) }
                        }
                        ForEach(engineers) { e in
                            Button(e.name) {
                                Task { await viewModel.assignEngineer(e.id) }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Assigned To")
                            Spacer()
                            Text(device.assignedEngineer?.name ?? "Unassigned")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(viewModel.isUpdating)
                } else if let engineer = device.assignedEngineer {
                    HStack {
                        Text("Assigned To")
                        Spacer()
                        Text(engineer.name)
                            .foregroundStyle(.secondary)
                    }
                }
                if let subLocations = device.availableSubLocations, !subLocations.isEmpty {
                    Menu {
                        Button("Unassigned") {
                            Task { await viewModel.setSubLocation(nil) }
                        }
                        ForEach(subLocations) { s in
                            Button(s.name) {
                                Task { await viewModel.setSubLocation(s.id) }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Location")
                            Spacer()
                            if let subLocation = device.subLocation {
                                Text(subLocation.code)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Unassigned")
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(viewModel.isUpdating)
                } else if let subLocation = device.subLocation {
                    HStack {
                        Text("Location")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(subLocation.code)
                            if let description = subLocation.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Button {
                    dueDatePickerValue = device.dueDate.flatMap { DateFormatters.parseISO8601($0) } ?? Date()
                    showingDueDatePicker = true
                } label: {
                    HStack {
                        Text("Due")
                        Spacer()
                        if let dueDate = device.formattedDueDate {
                            Text(dueDate)
                                .foregroundStyle(device.isOverdue ? .red : .secondary)
                        } else {
                            Text("Set due date")
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isUpdating)
            }

            // Available actions always full width
            if !viewModel.devicePageActions.isEmpty {
                ForEach(viewModel.devicePageActions) { action in
                    Button {
                        if action.needsInputCollection {
                            // Show sheet to gather confirmation / inputs / notes
                            selectedAction = action
                            actionNotes = ""
                            collectedInputs = [:]
                            showingActionSheet = true
                        } else {
                            // Execute directly — no user input required
                            Task { await viewModel.executeAction(action) }
                        }
                    } label: {
                        HStack {
                            Text(action.label)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Cancel work — only while diagnosis/repair is actively in progress
            if device.deviceStatus == .diagnosing || device.deviceStatus == .repairing {
                Button(role: .destructive) {
                    cancelWorkReason = ""
                    showingCancelWorkSheet = true
                } label: {
                    HStack {
                        Text("Cancel Work")
                        Spacer()
                        Image(systemName: "xmark.circle")
                    }
                }
                .disabled(viewModel.isUpdating)
            }
        } header: {
            Text("Status")
        }
    }

    // MARK: - Device Info Section

    private func deviceInfoSection(_ device: DeviceDetail) -> some View {
        Section("Device") {
            if isRegularWidth {
                let brand = device.brand?.name ?? device.customBrand
                let model = device.model?.name ?? device.customModel
                Grid(alignment: .topLeading, horizontalSpacing: 32, verticalSpacing: 16) {
                    if brand != nil || model != nil {
                        GridRow {
                            if let brand {
                                gridField("Brand") { Text(brand) }
                            }
                            if let model {
                                gridField("Model") { Text(model) }
                            }
                        }
                    }
                    if device.colour != nil || device.storageCapacity != nil {
                        GridRow {
                            if let colour = device.colour {
                                gridField("Colour") { Text(colour) }
                            }
                            if let storage = device.storageCapacity {
                                gridField("Storage") { Text(storage) }
                            }
                        }
                    }
                    if device.conditionGrade != nil || device.findMyStatus != nil {
                        GridRow {
                            if let conditionGrade = device.conditionGrade {
                                gridField("Condition Grade") { Text(conditionGrade) }
                            }
                            if let findMyStatus = device.findMyStatus {
                                gridField("Find My") {
                                    Text(findMyStatus.capitalized)
                                        .foregroundStyle(findMyStatus == "enabled" ? .orange : .green)
                                }
                            }
                        }
                    }
                    if let passcodeType = device.passcodeType {
                        GridRow {
                            gridField("Passcode Type") { Text(passcodeType.capitalized) }
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                if let brand = device.brand {
                    LabeledContent("Brand", value: brand.name)
                } else if let customBrand = device.customBrand {
                    LabeledContent("Brand", value: customBrand)
                }

                if let model = device.model {
                    LabeledContent("Model", value: model.name)
                } else if let customModel = device.customModel {
                    LabeledContent("Model", value: customModel)
                }

                if let colour = device.colour {
                    LabeledContent("Colour", value: colour)
                }

                if let storage = device.storageCapacity {
                    LabeledContent("Storage", value: storage)
                }

                if let conditionGrade = device.conditionGrade {
                    LabeledContent("Condition Grade", value: conditionGrade)
                }

                if let findMyStatus = device.findMyStatus {
                    HStack {
                        Text("Find My")
                        Spacer()
                        Text(findMyStatus.capitalized)
                            .foregroundStyle(findMyStatus == "enabled" ? .orange : .green)
                    }
                }

                if let passcodeType = device.passcodeType {
                    LabeledContent("Passcode Type", value: passcodeType.capitalized)
                }

                if let health = device.batteryHealthPercent {
                    LabeledContent("Battery Health", value: "\(health)%")
                }

                if let cycles = device.batteryCycleCount {
                    LabeledContent("Battery Cycles", value: "\(cycles)")
                }
            }
        }
    }

    // MARK: - Identifiers Section

    private func identifiersSection(_ device: DeviceDetail) -> some View {
        Section("Identifiers") {
            if isRegularWidth {
                Grid(alignment: .topLeading, horizontalSpacing: 32, verticalSpacing: 16) {
                    GridRow {
                        if let serial = device.serialNumber {
                            gridField("Serial Number") {
                                Text(serial)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                        if let imei = device.imei {
                            gridField("IMEI") {
                                Text(imei)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                if let serial = device.serialNumber {
                    LabeledContent("Serial Number") {
                        Text(serial)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                if let imei = device.imei {
                    LabeledContent("IMEI") {
                        Text(imei)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    // MARK: - Issues Section

    private func issuesSection(_ device: DeviceDetail) -> some View {
        Section("Issues") {
            if let customerIssues = device.customerReportedIssues {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Customer Reported")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(customerIssues)
                }
            }

            if let technicianIssues = device.technicianFoundIssues {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Technician Found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(technicianIssues)
                }
            }

            if let additionalIssues = device.additionalIssuesFound, additionalIssues != 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Additional Issues")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Yes")
                }
            }
        }
    }

    // MARK: - Diagnosis Section

    private func diagnosisSection(_ device: DeviceDetail) -> some View {
        Section("Diagnosis") {
            if let visualCheck = device.visualCheck {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Visual Check")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(visualCheck)
                }
            }

            if let electricalCheck = device.electricalCheck {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Electrical Check")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(electricalCheck)
                }
            }

            if let mechanicalCheck = device.mechanicalCheck {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mechanical Check")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(mechanicalCheck)
                }
            }

            if let damageMatches = device.damageMatchesReported {
                LabeledContent("Damage Matches Reported") {
                    Image(systemName: damageMatches ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(damageMatches ? .green : .red)
                }
            }

            if let conclusion = device.diagnosisConclusion {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conclusion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(conclusion)
                }
            }

            // Diagnosis notes — always editable (even when nil, allows adding notes)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !editingDiagnosisNotes {
                        Button("Edit") {
                            diagnosisNotesText = device.diagnosisNotes ?? ""
                            editingDiagnosisNotes = true
                        }
                        .font(.caption)
                    } else {
                        Button("Save") {
                            let text = diagnosisNotesText
                            editingDiagnosisNotes = false
                            Task { await viewModel.updateDiagnosisNotes(text) }
                        }
                        .font(.caption.weight(.semibold))
                        Button("Cancel") {
                            editingDiagnosisNotes = false
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                if editingDiagnosisNotes {
                    TextEditor(text: $diagnosisNotesText)
                        .frame(minHeight: 80)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if let notes = device.diagnosisNotes {
                    Text(notes)
                } else {
                    Text("No notes")
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
        }
    }

    // MARK: - Repair Section

    private func repairSection(_ device: DeviceDetail) -> some View {
        Section("Repair") {
            // Repair notes — always editable (even when nil, allows adding notes)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Repair Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !editingRepairNotes {
                        Button("Edit") {
                            repairNotesText = device.repairNotes ?? ""
                            editingRepairNotes = true
                        }
                        .font(.caption)
                    } else {
                        Button("Save") {
                            let text = repairNotesText
                            editingRepairNotes = false
                            Task { await viewModel.updateRepairNotes(text) }
                        }
                        .font(.caption.weight(.semibold))
                        Button("Cancel") {
                            editingRepairNotes = false
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                if editingRepairNotes {
                    TextEditor(text: $repairNotesText)
                        .frame(minHeight: 80)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if let notes = device.repairNotes {
                    Text(notes)
                } else {
                    Text("No notes")
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }

            if let techNotes = device.technicianNotes {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Technician Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(techNotes)
                }
            }
        }
    }

    // MARK: - Line Items Section

    private func lineItemsSection(_ device: DeviceDetail) -> some View {
        Section("Quote Items") {
            ForEach(device.lineItems) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.description)
                            .font(.subheadline)
                        Text("Qty: \(item.quantity) × \(item.formattedUnitPrice)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(item.formattedLineTotal)
                        .font(.subheadline.weight(.medium))
                }
            }

            HStack {
                Text("Total")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(formatCurrency(device.totalLineItemsAmount))
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    // MARK: - Parts Section

    private func partsSection(_ device: DeviceDetail) -> some View {
        Section("Parts Used") {
            ForEach(device.partsUsed) { part in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(part.partName)
                            .font(.subheadline)
                        if part.isOem {
                            Text("OEM")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    HStack {
                        if let sku = part.partSku {
                            Text(sku)
                        }
                        if let supplier = part.supplier {
                            Text("·")
                            Text(supplier)
                        }
                        if let cost = part.formattedCost {
                            Spacer()
                            Text(cost)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Accessories Section

    private func accessoriesSection(_ device: DeviceDetail) -> some View {
        Section("Accessories") {
            ForEach(device.accessories) { accessory in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(accessory.typeDisplayName)
                            .font(.subheadline)
                        if let description = accessory.description {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if accessory.isReturned {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Mark returned") {
                            Task { await viewModel.markAccessoryReturned(accessoryId: accessory.id) }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(viewModel.isUpdating)
                    }
                }
            }
        }
    }

    // MARK: - Images Section

    private func imagesSection(_ device: DeviceDetail) -> some View {
        Section("Photos") {
            #if os(iOS)
            DeviceImageGalleryView(
                orderId: device.orderId,
                deviceId: device.id,
                deviceStatus: device.status,
                orderNumber: device.orderNumber,
                serialNumber: device.serialNumber,
                imei: device.imei
            )
            #else
            if !device.images.isEmpty {
                Text("\(device.images.count) photo(s)")
                    .foregroundStyle(.secondary)
            }
            #endif
        }
    }

    // MARK: - Checklist Section

    private func checklistSection(_ device: DeviceDetail) -> some View {
        Section {
            ForEach(device.checklist) { item in
                HStack {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.completed ? .green : .secondary)
                    Text(item.label)
                        .font(.subheadline)
                    if item.required && !item.completed {
                        Text("Required")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        } header: {
            HStack {
                Text("Checklist")
                Spacer()
                Text("\(device.checklistProgress)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Timestamps Section

    private func timestampsSection(_ device: DeviceDetail) -> some View {
        Section("Timeline") {
            if isRegularWidth {
                Grid(alignment: .topLeading, horizontalSpacing: 32, verticalSpacing: 16) {
                    GridRow {
                        if let received = device.timestamps.formattedReceivedAt {
                            gridField("Received") { Text(received) }
                        }
                        if let diagnosisStarted = device.timestamps.formattedDiagnosisStarted {
                            gridField("Diagnosis Started") { Text(diagnosisStarted) }
                        }
                    }
                    if let repairStarted = device.timestamps.formattedRepairStarted {
                        GridRow {
                            gridField("Repair Started") { Text(repairStarted) }
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                if let received = device.timestamps.formattedReceivedAt {
                    LabeledContent("Received", value: received)
                }

                if let diagnosisStarted = device.timestamps.formattedDiagnosisStarted {
                    LabeledContent("Diagnosis Started", value: diagnosisStarted)
                }

                if let repairStarted = device.timestamps.formattedRepairStarted {
                    LabeledContent("Repair Started", value: repairStarted)
                }
            }
        }
    }

    // MARK: - Grid Field Helper

    private func gridField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: amount as NSDecimalNumber) ?? "£0.00"
    }
}

// MARK: - Device Action Sheet

/// Modal sheet presented when an action requires confirmation, notes, or input fields.
///
/// For actions where `needsInputCollection` is false this sheet is never shown —
/// those execute directly via `executeAction`.  For actions that DO need input,
/// this sheet gathers the values, then calls `onConfirm` so the ViewModel can
/// build and POST the `DeviceActionRequest` with the correct top-level keys.
private struct DeviceActionSheet: View {
    let action: DeviceAction
    @Binding var notes: String
    @Binding var collectedInputs: [String: String]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    /// True when all `requiresInput` fields have non-empty values
    private var canConfirm: Bool {
        guard let required = action.requiresInput, !required.isEmpty else { return true }
        return required.allSatisfy { key in
            !(collectedInputs[key] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Confirmation message (reserved — not yet emitted by Worker)
                if let message = action.confirmationMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                }

                // Required input fields
                if let inputKeys = action.requiresInput, !inputKeys.isEmpty {
                    Section("Required Information") {
                        ForEach(inputKeys, id: \.self) { key in
                            LabeledContent(DeviceAction.label(forInputKey: key)) {
                                TextField(
                                    DeviceAction.label(forInputKey: key),
                                    text: Binding(
                                        get: { collectedInputs[key] ?? "" },
                                        set: { collectedInputs[key] = $0 }
                                    )
                                )
                                .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }

                // Optional notes (reserved — not yet emitted by Worker)
                if action.requiresNotes == true {
                    Section("Notes") {
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    }
                }

                // Confirm / danger zone
                Section {
                    Button(action.label) {
                        onConfirm()
                    }
                    .disabled(!canConfirm)
                    .foregroundStyle(canConfirm ? Color.accentColor : Color.secondary)
                }
            }
            .navigationTitle(action.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DeviceDetailView(orderId: "order-1", deviceId: "device-1")
    }
}
