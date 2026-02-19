# Stage 2: OrderItemFormSheet

## Objective

Create a new `OrderItemFormSheet.swift` view that serves as both the add and edit form for order line items, presented as a `.sheet()` from `OrderDetailView`.

## Dependencies

[Requires: Stage 1 complete] — needs `OrderItemRequest` struct from [Ref: Core/Models/Order.swift].

## Complexity

Medium-High (largest stage — form with type picker, device picker, price conversion, validation, totals preview, iPad/iPhone responsive layout)

## Files to Modify

None.

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Staff/Orders/OrderItemFormSheet.swift` | Complete add/edit line item form with type picker, device selector, price input, VAT, totals preview |

## Implementation Details

### View Structure

```
OrderItemFormSheet
├── NavigationStack
│   ├── .navigationTitle("Add Line Item" / "Edit Line Item")
│   ├── .navigationBarTitleDisplayMode(.inline)
│   ├── .toolbar
│   │   ├── cancellationAction: "Cancel" → dismiss()
│   │   └── confirmationAction: "Add"/"Update" → saveItem()
│   │       ├── .fontWeight(.semibold)
│   │       └── .disabled(isSaving || !isFormValid)
│   ├── ScrollView
│   │   └── VStack(spacing: 20)
│   │       ├── itemTypePicker         — 2×2 LazyVGrid of tappable cards
│   │       ├── devicePicker           — Picker .menu style (conditional: order has devices)
│   │       ├── descriptionField       — FormTextField (reused from Booking)
│   │       ├── quantityAndPriceSection — AnyLayout: HStack (iPad) / VStack (iPhone)
│   │       │   ├── quantity +/- buttons
│   │       │   └── price inc VAT FormTextField
│   │       ├── vatRateField           — TextField with company default hint
│   │       ├── totalsPreview          — Computed net/VAT/total card
│   │       └── devicePurchaseNote     — Orange info banner (conditional)
│   ├── .alert("Error", isPresented: $showError)
│   ├── .interactiveDismissDisabled(isSaving)
│   └── .onAppear { populateForEditing() }
```

### Props & Environment

```swift
struct OrderItemFormSheet: View {
    let order: Order                                    // For devices list + company VAT rates
    let editingItem: OrderItem?                         // nil = add mode, non-nil = edit mode
    let onSave: (OrderItemRequest) async -> Bool        // Injected — returns true on success

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
}
```

### Local `FormItemType` Enum

Only the 4 valid API types. Excludes legacy `part`, `labour`, `labor`, `other` from `OrderItemType` which exist for backward-compatible decoding but cannot be sent to the create/update API.

```swift
private enum FormItemType: String, CaseIterable, Identifiable {
    case repair
    case deviceSale = "device_sale"
    case accessory
    case devicePurchase = "device_purchase"

    var id: String { rawValue }
    var label: String { ... }       // "Repair", "Device Sale", "Accessory", "Device Purchase"
    var subtitle: String { ... }    // "Repair service charge", etc.
    var icon: String { ... }        // SF Symbol names
    var color: Color { ... }        // .blue, .orange, .purple, .green

    var requiresDevice: Bool {      // repair + device_purchase require device_id
        self == .repair || self == .devicePurchase
    }
}
```

### Form State

```swift
@State private var selectedItemType: FormItemType = .repair
@State private var selectedDeviceId: String = ""
@State private var descriptionText: String = ""
@State private var quantity: Int = 1
@State private var priceIncVatText: String = ""     // String for TextField binding
@State private var vatRate: Double = 20.0
@State private var isSaving = false
@State private var errorMessage: String?
@State private var showError = false
```

### Item Type Picker — 2×2 Grid

Uses `LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())])`.

Each card:
- Circular icon with type-coloured background
- Label (`.subheadline .medium`)
- Subtitle (`.caption2 .secondary`)
- Selected: coloured border (2pt) + tinted background
- Unselected: `.systemGray6` background, no border
- `minHeight: 100` for comfortable tap targets
- `.disabled(editingItem != nil)` — can't change type when editing (matches web)

When tapped: updates `selectedItemType`, resets `vatRate` to company default for new type, auto-selects device if order has exactly 1 device.

### Device Picker (Conditional)

Only shown when `order.devices` is non-empty:

```swift
@ViewBuilder
private func devicePicker(_ devices: [OrderDeviceSummary]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 4) {
            Text("Link to Device")
                .font(.subheadline).fontWeight(.medium)
            if selectedItemType.requiresDevice {
                Text("*").foregroundStyle(.red)
            }
        }

        Picker("Device", selection: $selectedDeviceId) {
            if selectedItemType.requiresDevice {
                Text("-- Select a device --").tag("")
            } else {
                Text("No specific device").tag("")
            }
            ForEach(devices) { device in
                Text(devicePickerLabel(device)).tag(device.id)
            }
        }
        .pickerStyle(.menu)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Build a distinguishable label for the device picker.
/// Note: The API's order.devices array does not include brand/model names —
/// only status, workflow_type, and authorization info. This helper combines
/// workflow type + status to give the best possible label.
/// Future improvement: add brand/model to the API device summary response.
private func devicePickerLabel(_ device: OrderDeviceSummary) -> String {
    let workflowLabel: String
    switch device.workflowType {
    case "repair": workflowLabel = "Repair"
    case "device_sale": workflowLabel = "Sale"
    case "device_purchase", "buyback_purchase": workflowLabel = "Purchase"
    default: workflowLabel = "Device"
    }
    return "\(workflowLabel) — \(device.deviceStatus.label)"
}
```

### Description Field

Reuses existing component [Ref: Features/Staff/Booking/Components/FormTextField.swift]:

```swift
FormTextField(
    label: "Description",
    text: $descriptionText,
    placeholder: "e.g. Screen replacement - iPhone 13",
    keyboardType: .default,
    autocapitalization: .sentences,
    isRequired: true
)
```

### Quantity + Price Section (iPad Responsive)

Uses `AnyLayout` to switch between `HStack` (iPad `.regular`) and `VStack` (iPhone `.compact`):

```swift
private var quantityAndPriceSection: some View {
    let isRegular = horizontalSizeClass == .regular
    let layout = isRegular
        ? AnyLayout(HStackLayout(spacing: 16))
        : AnyLayout(VStackLayout(spacing: 16))

    return layout {
        // Quantity with +/- buttons
        VStack(alignment: .leading, spacing: 6) {
            Text("Quantity").font(.subheadline).fontWeight(.medium)
            HStack {
                Button { if quantity > 1 { quantity -= 1 } } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2).foregroundStyle(.secondary)
                }
                Text("\(quantity)")
                    .font(.title3).fontWeight(.semibold)
                    .frame(minWidth: 40)
                Button { quantity += 1 } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2).foregroundStyle(.accentColor)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        // Price inc VAT
        FormTextField(
            label: "Price inc VAT (\u{00A3})",
            text: $priceIncVatText,
            placeholder: "0.00",
            keyboardType: .decimalPad,
            autocapitalization: .never,
            isRequired: true
        )
    }
}
```

**Why +/- buttons not Stepper:** The existing app has no Stepper usage anywhere. +/- circle buttons match the visual language used elsewhere (e.g. the booking wizard).

### VAT Rate Field

```swift
private var vatRateSection: some View {
    VStack(alignment: .leading, spacing: 6) {
        Text("VAT Rate (%)").font(.subheadline).fontWeight(.medium)
        TextField("20", text: vatRateBinding)
            .keyboardType(.decimalPad)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        Text("Default for \(selectedItemType.label): \(defaultVatRate(for: selectedItemType), specifier: "%.0f")%")
            .font(.caption).foregroundStyle(.secondary)
    }
}
```

`vatRateBinding` is a computed `Binding<String>` that bridges the `Double` state to a String for the TextField.

### Totals Preview Card

Live-computed from current form values. Matches the web's inline preview:

```swift
private var totalsPreview: some View {
    let price = Double(priceIncVatText) ?? 0
    let totalIncVat = Double(quantity) * price
    let totalNet = vatRate > 0 ? totalIncVat / (1 + vatRate / 100) : totalIncVat
    let totalVat = totalIncVat - totalNet

    return VStack(spacing: 6) {
        HStack {
            Text("Net Total").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(CurrencyFormatter.format(totalNet)).font(.subheadline)
        }
        HStack {
            Text("VAT (\(vatRate, specifier: "%.0f")%)").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(CurrencyFormatter.format(totalVat)).font(.subheadline)
        }
        Divider()
        HStack {
            Text("Total inc VAT").font(.subheadline).fontWeight(.semibold)
            Spacer()
            Text(CurrencyFormatter.format(totalIncVat)).font(.subheadline).fontWeight(.semibold)
        }
    }
    .padding()
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 10))
}
```

### Device Purchase Note (Conditional)

Only when `selectedItemType == .devicePurchase`:

```swift
HStack(spacing: 8) {
    Image(systemName: "info.circle").foregroundStyle(.orange)
    Text("This amount is a credit to the customer (stored as negative).")
        .font(.caption).foregroundStyle(.secondary)
}
.padding()
.background(Color.orange.opacity(0.1))
.clipShape(RoundedRectangle(cornerRadius: 8))
```

### Key Helper Functions

**Default VAT rate** — reads from `order.company` [Ref: Core/Models/Order.swift#OrderCompany]:

```swift
private func defaultVatRate(for type: FormItemType) -> Double {
    guard let company = order.company else { return 20 }
    switch type {
    case .repair:         return company.vatRateRepair ?? 20
    case .deviceSale:     return company.vatRateDeviceSale ?? 0
    case .accessory:      return company.vatRateAccessory ?? 20
    case .devicePurchase: return company.vatRateDevicePurchase ?? 0
    }
}
```

**Auto-select single device:**

```swift
private func autoSelectSingleDevice() {
    if selectedItemType.requiresDevice,
       let devices = order.devices, devices.count == 1 {
        selectedDeviceId = devices[0].id
    }
}
```

**Populate for editing** — called in `.onAppear`:

```swift
private func populateForEditing() {
    guard let item = editingItem else {
        vatRate = defaultVatRate(for: selectedItemType)
        autoSelectSingleDevice()
        return
    }
    if let raw = item.itemType?.rawValue, let ft = FormItemType(rawValue: raw) {
        selectedItemType = ft
    }
    descriptionText = item.description
    quantity = item.quantity
    selectedDeviceId = item.deviceId ?? ""
    vatRate = item.vatRate
    // Convert stored net price → VAT-inclusive for display (same as web's openEditItemModal)
    let net = abs(item.unitPrice)
    let incVat = net * (1 + item.vatRate / 100)
    priceIncVatText = String(format: "%.2f", incVat)
}
```

### Validation

```swift
private var isFormValid: Bool {
    let desc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !desc.isEmpty, desc.count <= 500 else { return false }
    guard let price = Double(priceIncVatText), price >= 0 else { return false }
    if selectedItemType.requiresDevice,
       let devices = order.devices, !devices.isEmpty,
       selectedDeviceId.isEmpty {
        return false
    }
    return true
}
```

### Save Action

Builds `OrderItemRequest`, negating prices for device purchases:

```swift
private func saveItem() async {
    guard let priceIncVat = Double(priceIncVatText) else { return }
    let netPrice = vatRate > 0
        ? priceIncVat / (1 + vatRate / 100)
        : priceIncVat
    let isDevicePurchase = selectedItemType == .devicePurchase

    let request = OrderItemRequest(
        itemType: selectedItemType.rawValue,
        description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
        quantity: quantity,
        unitPrice: isDevicePurchase ? -abs(netPrice) : netPrice,
        priceIncVat: isDevicePurchase ? -abs(priceIncVat) : priceIncVat,
        vatRate: vatRate,
        deviceId: selectedDeviceId.isEmpty ? nil : selectedDeviceId
    )

    isSaving = true
    let success = await onSave(request)
    isSaving = false

    if success {
        dismiss()
    } else {
        errorMessage = "Failed to save. Please try again."
        showError = true
    }
}
```

### iPad Considerations

1. **Sheet presentation**: On iPad within the `AnimatedSplitView` detail pane, `.sheet()` renders as a centered card. [See: Stage 3] applies `.presentationDetents([.large])` and `.presentationDragIndicator(.visible)` to ensure the form gets full height.
2. **Quantity + Price row**: Uses `AnyLayout` to `HStack` on iPad / `VStack` on iPhone — prevents fields cramping in the narrow detail pane (~476pt portrait, ~644pt landscape).
3. **Item type grid**: 2×2 `LazyVGrid` works at all widths. Cards have `minHeight: 100` and flexible columns.
4. **ScrollView**: Wraps entire form — handles overflow gracefully when keyboard is visible.

## Database Changes

None.

## Test Cases

| Scenario | Input | Expected |
|----------|-------|----------|
| Open add mode | `editingItem = nil` | Form blank, type = repair, VAT = company default for repair, device auto-selected if single |
| Open edit mode | `editingItem = someItem` | Form pre-filled: type disabled, description, qty, price as inc-VAT, VAT rate, device |
| Change item type to accessory | Tap accessory card | VAT rate changes to company accessory default |
| Select device purchase | Tap device purchase card | Info banner appears |
| Empty description | Leave description blank | "Add" button disabled |
| No price | Leave price blank | "Add" button disabled |
| Required device not selected | Repair type, order has 2 devices, none selected | "Add" button disabled |
| Single device on order | Repair type, 1 device | Device auto-selected |
| No devices on order | Any type | Device picker not shown |
| Save success | `onSave` returns `true` | Sheet dismisses |
| Save failure | `onSave` returns `false` | Error alert shown, sheet stays open |
| Price conversion | Enter £120, VAT 20% | Sends `unit_price: 100`, `price_inc_vat: 120` |
| Device purchase price | Enter £50, device purchase | Sends `unit_price: -41.67`, `price_inc_vat: -50` |
| iPad: form layout | Regular size class | Quantity and price side-by-side |
| iPhone: form layout | Compact size class | Quantity and price stacked |

## Acceptance Checklist

- [ ] `OrderItemFormSheet.swift` created in `Features/Staff/Orders/`
- [ ] 2×2 item type grid with coloured cards, disabled when editing
- [ ] Device picker shown conditionally (only when `order.devices` is non-empty)
- [ ] Device picker shows required asterisk for repair/device_purchase types
- [ ] Single device auto-selected on appear
- [ ] Description uses `FormTextField` with `isRequired: true`
- [ ] Quantity has +/- circle buttons (not Stepper)
- [ ] Price field is VAT-inclusive with `.decimalPad` keyboard
- [ ] VAT rate field with company default hint text below
- [ ] Live totals preview updates as user types (net, VAT amount, total inc VAT)
- [ ] Device purchase info banner shown when device_purchase selected
- [ ] Edit mode pre-populates all fields (price converted from net → inc-VAT)
- [ ] Validation disables toolbar Save button when form incomplete
- [ ] Save builds `OrderItemRequest` with correct net + inc-VAT prices
- [ ] Device purchase negates both unit_price and price_inc_vat
- [ ] Success → dismiss; failure → error alert
- [ ] `.interactiveDismissDisabled(isSaving)` prevents swipe-dismiss during save
- [ ] Quantity + price layout: `HStack` on iPad, `VStack` on iPhone
- [ ] File builds without warnings

## Deployment

No deployment — iOS code only. Can be previewed in Xcode with `#Preview` using mock data.

## Handoff Notes

[See: Stage 3] needs:
- `OrderItemFormSheet(order:editingItem:onSave:)` initialiser
- `editingItem: nil` for add mode, `editingItem: someItem` for edit mode
- `onSave` closure signature: `(OrderItemRequest) async -> Bool` — `true` = dismiss, `false` = show error
- Apply `.presentationDetents([.large])` and `.presentationDragIndicator(.visible)` to the sheet in the parent view
