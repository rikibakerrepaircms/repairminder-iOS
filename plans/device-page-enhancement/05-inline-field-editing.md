# Stage 05: Inline Field Editing

## Objective
Enable staff to edit device text fields (diagnosis notes, repair notes, technician issues, etc.) directly from the device detail view.

## Dependencies
`[Requires: Stage 01 complete]` - Needs API endpoints for device updates

## Complexity
**Low** - UI sheets with existing ViewModel update methods

---

## Files to Create

### 1. `Features/Staff/Devices/Editors/TextFieldEditorSheet.swift`
Reusable sheet for editing multiline text fields.

### 2. `Features/Staff/Devices/Editors/SingleLineEditorSheet.swift`
Sheet for editing single-line fields.

---

## Files to Modify

### 1. `Features/Staff/Devices/DeviceDetailView.swift`
Add tap-to-edit functionality to existing sections.

### 2. `Features/Staff/Devices/DeviceDetailViewModel.swift`
Add any missing update methods.

---

## Implementation Details

### TextFieldEditorSheet.swift

```swift
import SwiftUI

// MARK: - Text Field Editor Sheet

/// Reusable sheet for editing multiline text fields
struct TextFieldEditorSheet: View {
    let title: String
    let placeholder: String
    let initialValue: String?
    let onSave: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var isSaving = false
    @State private var error: String?

    @FocusState private var isFocused: Bool

    init(
        title: String,
        placeholder: String = "Enter text...",
        initialValue: String?,
        onSave: @escaping (String) async throws -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.initialValue = initialValue
        self.onSave = onSave
        self._text = State(initialValue: initialValue ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Text editor
                TextEditor(text: $text)
                    .focused($isFocused)
                    .padding()
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGroupedBackground))

                // Character count
                HStack {
                    Spacer()
                    Text("\(text.count) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Error message
                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .disabled(text == (initialValue ?? ""))
                    }
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isFocused = false
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isSaving || text != (initialValue ?? ""))
            .onAppear {
                isFocused = true
            }
        }
    }

    private func save() async {
        isSaving = true
        error = nil

        do {
            try await onSave(text)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - Preview

#Preview {
    TextFieldEditorSheet(
        title: "Diagnosis Notes",
        placeholder: "Enter diagnosis findings...",
        initialValue: "Screen has hairline crack in top right corner."
    ) { text in
        try await Task.sleep(for: .seconds(1))
        print("Saved: \(text)")
    }
}
```

### SingleLineEditorSheet.swift

```swift
import SwiftUI

// MARK: - Single Line Editor Sheet

/// Sheet for editing single-line fields like passcode, serial number, etc.
struct SingleLineEditorSheet: View {
    let title: String
    let placeholder: String
    let initialValue: String?
    let keyboardType: UIKeyboardType
    let autocapitalization: TextInputAutocapitalization
    let onSave: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var isSaving = false
    @State private var error: String?

    @FocusState private var isFocused: Bool

    init(
        title: String,
        placeholder: String = "",
        initialValue: String?,
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .sentences,
        onSave: @escaping (String) async throws -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.initialValue = initialValue
        self.keyboardType = keyboardType
        self.autocapitalization = autocapitalization
        self.onSave = onSave
        self._text = State(initialValue: initialValue ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(placeholder, text: $text)
                        .focused($isFocused)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .disabled(text == (initialValue ?? ""))
                    }
                }
            }
            .interactiveDismissDisabled(isSaving || text != (initialValue ?? ""))
            .onAppear {
                isFocused = true
            }
        }
    }

    private func save() async {
        isSaving = true
        error = nil

        do {
            try await onSave(text)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}
```

### Update DeviceDetailView.swift

Add editing capabilities to sections:

```swift
// Add state variables for editing sheets
@State private var editingDiagnosisNotes = false
@State private var editingRepairNotes = false
@State private var editingTechnicianIssues = false
@State private var editingCustomerIssues = false
@State private var editingAdditionalIssues = false
@State private var editingConditionNotes = false

// MARK: - Issues Section (Updated)

private func issuesSection(_ device: DeviceDetail) -> some View {
    Section("Issues") {
        // Customer reported issues - editable
        editableField(
            label: "Customer Reported",
            value: device.customerReportedIssues,
            isEditing: $editingCustomerIssues
        ) {
            TextFieldEditorSheet(
                title: "Customer Reported Issues",
                placeholder: "Describe issues reported by the customer...",
                initialValue: device.customerReportedIssues
            ) { newValue in
                try await viewModel.updateCustomerReportedIssues(newValue)
            }
        }

        // Technician found issues - editable
        editableField(
            label: "Technician Found",
            value: device.technicianFoundIssues,
            isEditing: $editingTechnicianIssues
        ) {
            TextFieldEditorSheet(
                title: "Technician Found Issues",
                placeholder: "Describe issues found during diagnosis...",
                initialValue: device.technicianFoundIssues
            ) { newValue in
                try await viewModel.updateTechnicianFoundIssues(newValue)
            }
        }

        // Additional issues - editable
        editableField(
            label: "Additional Issues",
            value: device.additionalIssuesFound,
            isEditing: $editingAdditionalIssues
        ) {
            TextFieldEditorSheet(
                title: "Additional Issues Found",
                placeholder: "Describe any additional issues...",
                initialValue: device.additionalIssuesFound
            ) { newValue in
                try await viewModel.updateAdditionalIssues(newValue)
            }
        }
    }
}

// MARK: - Diagnosis Section (Updated)

private func diagnosisSection(_ device: DeviceDetail) -> some View {
    Section("Diagnosis") {
        // Existing checks (view-only for now)
        if let visualCheck = device.visualCheck {
            fieldDisplay(label: "Visual Check", value: visualCheck)
        }

        if let electricalCheck = device.electricalCheck {
            fieldDisplay(label: "Electrical Check", value: electricalCheck)
        }

        if let mechanicalCheck = device.mechanicalCheck {
            fieldDisplay(label: "Mechanical Check", value: mechanicalCheck)
        }

        if let damageMatches = device.damageMatchesReported {
            LabeledContent("Damage Matches Reported") {
                Image(systemName: damageMatches ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(damageMatches ? .green : .red)
            }
        }

        if let conclusion = device.diagnosisConclusion {
            fieldDisplay(label: "Conclusion", value: conclusion)
        }

        // Diagnosis notes - editable
        editableField(
            label: "Diagnosis Notes",
            value: device.diagnosisNotes,
            isEditing: $editingDiagnosisNotes
        ) {
            TextFieldEditorSheet(
                title: "Diagnosis Notes",
                placeholder: "Enter diagnosis findings and notes...",
                initialValue: device.diagnosisNotes
            ) { newValue in
                try await viewModel.updateDiagnosisNotes(newValue)
            }
        }
    }
}

// MARK: - Repair Section (Updated)

private func repairSection(_ device: DeviceDetail) -> some View {
    Section("Repair") {
        // Repair notes - editable
        editableField(
            label: "Repair Notes",
            value: device.repairNotes,
            isEditing: $editingRepairNotes
        ) {
            TextFieldEditorSheet(
                title: "Repair Notes",
                placeholder: "Enter repair work performed...",
                initialValue: device.repairNotes
            ) { newValue in
                try await viewModel.updateRepairNotes(newValue)
            }
        }

        // Technician notes (view-only)
        if let techNotes = device.technicianNotes {
            fieldDisplay(label: "Technician Notes", value: techNotes)
        }
    }
}

// MARK: - Helper Views

/// Editable field with tap-to-edit
@ViewBuilder
private func editableField<SheetContent: View>(
    label: String,
    value: String?,
    isEditing: Binding<Bool>,
    @ViewBuilder sheet: @escaping () -> SheetContent
) -> some View {
    Button {
        isEditing.wrappedValue = true
    } label: {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            if let value = value, !value.isEmpty {
                Text(value)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Tap to add...")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .sheet(isPresented: isEditing) {
        sheet()
    }
}

/// Non-editable field display
private func fieldDisplay(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
        Text(value)
            .font(.body)
    }
}
```

### Update DeviceDetailViewModel.swift

Add missing update methods:

```swift
// MARK: - Field Updates

/// Update customer reported issues
func updateCustomerReportedIssues(_ issues: String) async throws {
    try await updateField(\.customerReportedIssues, value: issues, fieldName: "customer_reported_issues")
}

/// Update additional issues found
func updateAdditionalIssues(_ issues: String) async throws {
    try await updateField(\.additionalIssuesFound, value: issues, fieldName: "additional_issues_found")
}

/// Update condition notes
func updateConditionNotes(_ notes: String) async throws {
    try await updateField(\.conditionNotes, value: notes, fieldName: "condition_notes")
}

/// Generic field update helper
private func updateField<T>(_ keyPath: WritableKeyPath<DeviceDetail, T>, value: T, fieldName: String) async throws where T: Encodable {
    isUpdating = true
    error = nil

    do {
        // Create dynamic request body
        struct FieldUpdate: Encodable {
            let fieldName: String
            let value: Any

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: DynamicCodingKey.self)
                // Encode the field with its name
                if let stringValue = value as? String {
                    try container.encode(stringValue, forKey: DynamicCodingKey(stringValue: fieldName)!)
                }
            }

            struct DynamicCodingKey: CodingKey {
                var stringValue: String
                var intValue: Int?

                init?(stringValue: String) {
                    self.stringValue = stringValue
                    self.intValue = nil
                }

                init?(intValue: Int) {
                    return nil
                }
            }
        }

        // Use the existing updateDevice method with the appropriate request
        if let stringValue = value as? String {
            switch fieldName {
            case "diagnosis_notes":
                await updateDevice(.diagnosisNotes(stringValue))
            case "technician_found_issues":
                await updateDevice(.technicianFoundIssues(stringValue))
            case "repair_notes":
                await updateDevice(.repairNotes(stringValue))
            case "customer_reported_issues":
                await updateDevice(.customerReportedIssues(stringValue))
            case "additional_issues_found":
                await updateDevice(.additionalIssues(stringValue))
            case "condition_notes":
                await updateDevice(.conditionNotes(stringValue))
            default:
                throw APIError.invalidRequest("Unknown field: \(fieldName)")
            }
        }
    } catch {
        self.error = error.localizedDescription
        throw error
    }

    isUpdating = false
}
```

### Update DeviceUpdateRequest

Add missing request types:

```swift
// In DeviceUpdateRequest.swift or DeviceDetail.swift

extension DeviceUpdateRequest {
    static func customerReportedIssues(_ issues: String) -> DeviceUpdateRequest {
        DeviceUpdateRequest(customerReportedIssues: issues)
    }

    static func additionalIssues(_ issues: String) -> DeviceUpdateRequest {
        DeviceUpdateRequest(additionalIssuesFound: issues)
    }

    static func conditionNotes(_ notes: String) -> DeviceUpdateRequest {
        DeviceUpdateRequest(conditionNotes: notes)
    }
}

struct DeviceUpdateRequest: Encodable {
    var diagnosisNotes: String?
    var repairNotes: String?
    var technicianFoundIssues: String?
    var customerReportedIssues: String?
    var additionalIssuesFound: String?
    var conditionNotes: String?
    var assignedEngineerId: String?
    var priority: String?
    var subLocationId: String?
    // ... other fields as needed
}
```

---

## Database Changes
None

---

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Tap empty field | Tap "Diagnosis Notes" (empty) | Editor opens with placeholder |
| Tap filled field | Tap filled field | Editor shows current value |
| Edit and save | Change text, tap Save | Field updates, sheet closes |
| Edit and cancel | Change text, tap Cancel | Original value preserved |
| Character count | Type text | Count updates live |
| Save disabled | No changes made | Save button disabled |
| Loading state | Tap Save | Progress indicator shows |
| Error handling | Save fails | Error message displayed |

---

## Acceptance Checklist

- [ ] TextFieldEditorSheet created and works
- [ ] SingleLineEditorSheet created and works
- [ ] Diagnosis notes editable with tap
- [ ] Repair notes editable with tap
- [ ] Technician issues editable with tap
- [ ] Customer issues editable with tap
- [ ] Additional issues editable with tap
- [ ] Save updates device and refreshes view
- [ ] Cancel preserves original value
- [ ] Loading state during save
- [ ] Error handling works
- [ ] Build passes with no errors

---

## Deployment
```bash
xcodebuild -scheme "Repair Minder" -destination "generic/platform=iOS Simulator" build
```

---

## Handoff Notes
- The `editableField` helper is reusable for other sections
- `TextFieldEditorSheet` auto-focuses the text field on appear
- Unsaved changes trigger interactive dismiss protection
- Stage 06-08 can proceed independently
