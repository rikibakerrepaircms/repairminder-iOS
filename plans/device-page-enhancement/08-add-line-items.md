# Stage 08: Add Line Items

## Objective
Enable staff to add quote line items (labor, parts, etc.) to the device/order with automatic VAT calculation.

## Dependencies
`[Requires: Stage 01 complete]` - Needs API endpoints for order items

## Complexity
**Medium** - Form with pricing calculations and VAT

---

## Files to Create

### 1. `Features/Staff/Devices/Editors/AddLineItemSheet.swift`
Form for adding a new quote line item.

---

## Files to Modify

### 1. `Features/Staff/Devices/DeviceDetailView.swift`
Add "Add Item" button to line items section.

### 2. `Features/Staff/Devices/DeviceDetailViewModel.swift`
Add method to add line item.

### 3. `Core/Models/OrderItemModels.swift` (may need to create)
Request/response models for order items.

---

## Implementation Details

### OrderItemModels.swift

```swift
import Foundation

// MARK: - Order Item Type

enum OrderItemType: String, Codable, CaseIterable, Sendable {
    case labor
    case parts
    case diagnostic
    case accessories
    case warranty
    case other

    var displayName: String {
        switch self {
        case .labor: return "Labor"
        case .parts: return "Parts"
        case .diagnostic: return "Diagnostic Fee"
        case .accessories: return "Accessories"
        case .warranty: return "Warranty"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .labor: return "wrench.and.screwdriver"
        case .parts: return "cpu"
        case .diagnostic: return "magnifyingglass"
        case .accessories: return "cable.connector"
        case .warranty: return "checkmark.shield"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Add Order Item Request

struct AddOrderItemRequest: Encodable, Sendable {
    let itemType: String
    let description: String
    let quantity: Int
    let unitPrice: Double
    let vatRate: Double?
    let deviceId: String?
    let isWarrantyItem: Bool?
    let warrantyNotes: String?
}

// MARK: - Order Item Response

struct OrderItemResponse: Decodable, Sendable {
    let id: String
    let orderId: String
    let itemType: String
    let description: String
    let quantity: Int
    let unitPrice: Double
    let vatRate: Double
    let lineTotal: Double
    let vatAmount: Double
    let lineTotalIncVat: Double
    let deviceId: String?
    let authorizationStatus: String?
    let createdAt: String
}
```

### AddLineItemSheet.swift

```swift
import SwiftUI

// MARK: - Add Line Item Sheet

/// Sheet for adding a quote line item
struct AddLineItemSheet: View {
    let orderId: String
    let deviceId: String
    let defaultVatRate: Double
    let onComplete: (DeviceLineItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: OrderItemType = .labor
    @State private var description = ""
    @State private var quantity = "1"
    @State private var unitPrice = ""
    @State private var vatRate: Double
    @State private var isWarrantyItem = false
    @State private var warrantyNotes = ""
    @State private var isSaving = false
    @State private var error: String?

    @FocusState private var focusedField: Field?

    enum Field {
        case description, quantity, price, warranty
    }

    init(
        orderId: String,
        deviceId: String,
        defaultVatRate: Double = 20.0,
        onComplete: @escaping (DeviceLineItem) -> Void
    ) {
        self.orderId = orderId
        self.deviceId = deviceId
        self.defaultVatRate = defaultVatRate
        self.onComplete = onComplete
        self._vatRate = State(initialValue: defaultVatRate)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Item type
                Section("Type") {
                    Picker("Item Type", selection: $selectedType) {
                        ForEach(OrderItemType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedType) { _, newValue in
                        if newValue == .warranty {
                            isWarrantyItem = true
                        }
                    }
                }

                // Description
                Section("Description") {
                    TextField("e.g., Screen replacement labor", text: $description, axis: .vertical)
                        .focused($focusedField, equals: .description)
                        .lineLimit(2...4)
                }

                // Pricing
                Section("Pricing") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("1", text: $quantity)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .focused($focusedField, equals: .quantity)
                    }

                    HStack {
                        Text("Unit Price")
                        Spacer()
                        Text("£")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $unitPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .focused($focusedField, equals: .price)
                    }

                    HStack {
                        Text("VAT Rate")
                        Spacer()
                        Picker("VAT", selection: $vatRate) {
                            Text("0%").tag(0.0)
                            Text("5%").tag(5.0)
                            Text("20%").tag(20.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                }

                // Calculated totals
                Section("Totals") {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(formattedSubtotal)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("VAT (\(Int(vatRate))%)")
                        Spacer()
                        Text(formattedVat)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(formattedTotal)
                            .fontWeight(.semibold)
                    }
                }

                // Warranty options
                if selectedType == .warranty || isWarrantyItem {
                    Section("Warranty") {
                        Toggle("Warranty Claim", isOn: $isWarrantyItem)

                        if isWarrantyItem {
                            TextField("Warranty notes", text: $warrantyNotes, axis: .vertical)
                                .lineLimit(2...4)
                                .focused($focusedField, equals: .warranty)
                        }
                    }
                }

                // Error
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Quote Item")
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
                        Button("Add") {
                            Task { await addItem() }
                        }
                        .disabled(!isValid)
                    }
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    // MARK: - Calculations

    private var parsedQuantity: Int {
        Int(quantity) ?? 1
    }

    private var parsedUnitPrice: Double {
        Double(unitPrice) ?? 0
    }

    private var subtotal: Double {
        Double(parsedQuantity) * parsedUnitPrice
    }

    private var vatAmount: Double {
        subtotal * (vatRate / 100)
    }

    private var total: Double {
        subtotal + vatAmount
    }

    private var formattedSubtotal: String {
        formatCurrency(subtotal)
    }

    private var formattedVat: String {
        formatCurrency(vatAmount)
    }

    private var formattedTotal: String {
        formatCurrency(total)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: NSNumber(value: amount)) ?? "£0.00"
    }

    private var isValid: Bool {
        !description.isEmpty && parsedQuantity > 0 && parsedUnitPrice > 0
    }

    // MARK: - Actions

    private func addItem() async {
        isSaving = true
        error = nil

        do {
            let request = AddOrderItemRequest(
                itemType: selectedType.rawValue,
                description: description,
                quantity: parsedQuantity,
                unitPrice: parsedUnitPrice,
                vatRate: vatRate,
                deviceId: deviceId,
                isWarrantyItem: isWarrantyItem ? true : nil,
                warrantyNotes: warrantyNotes.isEmpty ? nil : warrantyNotes
            )

            let item: DeviceLineItem = try await APIClient.shared.request(
                .createOrderItem(orderId: orderId),
                body: request
            )

            onComplete(item)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - Preview

#Preview {
    AddLineItemSheet(
        orderId: "order-1",
        deviceId: "device-1",
        defaultVatRate: 20.0
    ) { item in
        print("Added: \(item.description)")
    }
}
```

### Update DeviceDetailView.swift - Line Items Section

```swift
// Add state variable
@State private var showingAddLineItem = false

// Update lineItemsSection
private func lineItemsSection(_ device: DeviceDetail) -> some View {
    Section {
        // Existing line items
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

        // Totals
        if !device.lineItems.isEmpty {
            HStack {
                Text("Total")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(formatCurrency(device.totalLineItemsAmount))
                    .font(.subheadline.weight(.semibold))
            }
        }

        // Add item button
        Button {
            showingAddLineItem = true
        } label: {
            Label("Add Quote Item", systemImage: "plus.circle.fill")
                .foregroundStyle(.blue)
        }
    } header: {
        HStack {
            Text("Quote Items")
            Spacer()
            Text("\(device.lineItems.count)")
                .foregroundStyle(.secondary)
        }
    }
    .sheet(isPresented: $showingAddLineItem) {
        AddLineItemSheet(
            orderId: viewModel.orderId,
            deviceId: viewModel.deviceId,
            defaultVatRate: 20.0  // Could be fetched from company settings
        ) { item in
            Task { await viewModel.refresh() }
        }
    }
}
```

---

## Database Changes
None (backend schema already exists)

---

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Validation - empty description | No description | Add button disabled |
| Validation - zero price | Price = 0 | Add button disabled |
| Basic item add | Type, description, price | Item created |
| VAT calculation | £100 @ 20% | VAT = £20, Total = £120 |
| Zero VAT | £100 @ 0% | VAT = £0, Total = £100 |
| Quantity multiply | Qty 2 × £50 | Subtotal = £100 |
| Warranty item | Toggle warranty | Flag set in request |
| Refresh after add | Add item | Appears in list, total updates |

---

## Acceptance Checklist

- [ ] AddLineItemSheet form created
- [ ] Type picker shows all item types
- [ ] Description is required
- [ ] Quantity defaults to 1
- [ ] Unit price is required
- [ ] VAT rate picker works (0%, 5%, 20%)
- [ ] Totals calculate in real-time
- [ ] Warranty toggle appears for warranty type
- [ ] Add button calls API
- [ ] Success refreshes device
- [ ] Total in section header updates
- [ ] Build passes with no errors

---

## Deployment
```bash
xcodebuild -scheme "Repair Minder" -destination "generic/platform=iOS Simulator" build
```

---

## Handoff Notes
- The default VAT rate should ideally come from company settings (future enhancement)
- Stage 09 will add delete functionality for line items
- Line items are added via the Order Items endpoint, not a device-specific endpoint
- The `deviceId` links the item to the specific device
