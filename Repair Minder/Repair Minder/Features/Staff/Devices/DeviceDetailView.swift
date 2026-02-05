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
    @State private var viewModel: DeviceDetailViewModel
    @State private var showingActionSheet = false
    @State private var selectedAction: DeviceAction?
    @State private var actionNotes = ""

    init(orderId: String, deviceId: String) {
        _viewModel = State(initialValue: DeviceDetailViewModel(orderId: orderId, deviceId: deviceId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && !viewModel.isLoaded {
                loadingView
            } else if let error = viewModel.error, !viewModel.isLoaded {
                errorView(error)
            } else if let device = viewModel.device {
                deviceContent(device)
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
        .confirmationDialog(
            selectedAction?.label ?? "Action",
            isPresented: $showingActionSheet,
            titleVisibility: .visible
        ) {
            if let action = selectedAction {
                Button(action.label) {
                    Task {
                        await viewModel.executeAction(action, notes: actionNotes.isEmpty ? nil : actionNotes)
                        actionNotes = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    selectedAction = nil
                    actionNotes = ""
                }
            }
        } message: {
            if let action = selectedAction, let message = action.confirmationMessage {
                Text(message)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading device...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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

            // Diagnosis
            if device.hasDiagnosticChecks || device.diagnosisNotes != nil {
                diagnosisSection(device)
            }

            // Repair notes
            if device.repairNotes != nil || device.status == "repairing" {
                repairSection(device)
            }

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
            if !device.images.isEmpty {
                imagesSection(device)
            }

            // Checklist
            if !device.checklist.isEmpty {
                checklistSection(device)
            }

            // Timestamps
            timestampsSection(device)
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Status Section

    private func statusSection(_ device: DeviceDetail) -> some View {
        Section {
            // Current status
            HStack {
                Text("Status")
                Spacer()
                DeviceStatusBadge(status: device.deviceStatus, size: .large)
            }

            // Priority
            HStack {
                Text("Priority")
                Spacer()
                PriorityBadge(priority: device.devicePriority)
            }

            // Workflow type
            HStack {
                Text("Workflow")
                Spacer()
                WorkflowTypeBadge(workflowType: device.workflow)
            }

            // Assigned engineer
            if let engineer = device.assignedEngineer {
                HStack {
                    Text("Assigned To")
                    Spacer()
                    Text(engineer.name)
                        .foregroundStyle(.secondary)
                }
            }

            // Sub-location
            if let subLocation = device.subLocation {
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

            // Due date
            if let dueDate = device.formattedDueDate {
                HStack {
                    Text("Due")
                    Spacer()
                    Text(dueDate)
                        .foregroundStyle(device.isOverdue ? .red : .secondary)
                }
            }

            // Available actions
            if !viewModel.devicePageActions.isEmpty {
                ForEach(viewModel.devicePageActions) { action in
                    Button {
                        selectedAction = action
                        showingActionSheet = true
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
        } header: {
            Text("Status")
        }
    }

    // MARK: - Device Info Section

    private func deviceInfoSection(_ device: DeviceDetail) -> some View {
        Section("Device") {
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
        }
    }

    // MARK: - Identifiers Section

    private func identifiersSection(_ device: DeviceDetail) -> some View {
        Section("Identifiers") {
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

            if let additionalIssues = device.additionalIssuesFound {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Additional Issues")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(additionalIssues)
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

            if let notes = device.diagnosisNotes {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(notes)
                }
            }
        }
    }

    // MARK: - Repair Section

    private func repairSection(_ device: DeviceDetail) -> some View {
        Section("Repair") {
            if let notes = device.repairNotes {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Repair Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(notes)
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
                    }
                }
            }
        }
    }

    // MARK: - Images Section

    private func imagesSection(_ device: DeviceDetail) -> some View {
        Section("Photos") {
            Text("\(device.images.count) photo(s)")
                .foregroundStyle(.secondary)
            // Note: Full image gallery would go here
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
            if let received = device.timestamps.formattedReceivedAt {
                LabeledContent("Received", value: received)
            }

            if let diagnosisStarted = device.timestamps.formattedDiagnosisStarted {
                HStack {
                    LabeledContent("Diagnosis Started", value: diagnosisStarted)
                }
            }

            if let repairStarted = device.timestamps.formattedRepairStarted {
                LabeledContent("Repair Started", value: repairStarted)
            }
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: amount as NSDecimalNumber) ?? "£0.00"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DeviceDetailView(orderId: "order-1", deviceId: "device-1")
    }
}
