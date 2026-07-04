//
//  OrderItemFormSheet.swift
//  Repair Minder
//

import SwiftUI

// MARK: - Form Item Type

/// Only the 4 valid API types for creating/updating line items.
/// Excludes legacy part, labour, labor, other from OrderItemType.
private enum FormItemType: String, CaseIterable, Identifiable {
    case repair
    case deviceSale = "device_sale"
    case accessory
    case devicePurchase = "device_purchase"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .repair: return "Repair"
        case .deviceSale: return "Device Sale"
        case .accessory: return "Accessory"
        case .devicePurchase: return "Device Purchase"
        }
    }

    var subtitle: String {
        switch self {
        case .repair: return "Repair service charge"
        case .deviceSale: return "Selling a device"
        case .accessory: return "Accessory or add-on"
        case .devicePurchase: return "Buying from customer"
        }
    }

    var icon: String {
        switch self {
        case .repair: return "wrench.and.screwdriver"
        case .deviceSale: return "iphone"
        case .accessory: return "bag"
        case .devicePurchase: return "cart"
        }
    }

    var color: Color {
        switch self {
        case .repair: return .blue
        case .deviceSale: return .orange
        case .accessory: return .purple
        case .devicePurchase: return .green
        }
    }

    var requiresDevice: Bool {
        self == .repair || self == .devicePurchase
    }
}

// MARK: - Discount Kind

/// Discount kind for a line item. Percent and Amount are mutually exclusive
/// per the backend's XOR validation rule (`validateDiscountFields`).
private enum ItemDiscountKind: String, CaseIterable, Identifiable {
    case none
    case percent
    case amount

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .percent: return "Percent"
        case .amount: return "Amount"
        }
    }
}

// MARK: - OrderItemFormSheet

struct OrderItemFormSheet: View {
    let order: Order
    let editingItem: OrderItem?
    let onSave: (OrderItemRequest) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Form State

    @State private var selectedItemType: FormItemType = .repair
    @State private var selectedDeviceId: String = ""
    @State private var descriptionText: String = ""
    @State private var quantity: Int = 1
    @State private var priceIncVatText: String = ""
    @State private var vatRate: Double = 20.0
    @State private var discountKind: ItemDiscountKind = .none
    @State private var discountValueText: String = ""
    @State private var discountReasonText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    // Product search state
    @State private var productSearchText: String = ""
    @State private var productSearchResults: [ProductTypeSearchResult] = []
    @State private var isSearchingProducts = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedProductId: String?
    @State private var showQuickCreate = false
    @State private var quickCreateInitialName = ""
    @State private var createdProductName: String?
    @State private var showCreatedBanner = false

    // MARK: - Computed Properties

    private var isEditing: Bool {
        editingItem != nil
    }

    private var isFormValid: Bool {
        let desc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty, desc.count <= 500 else { return false }
        guard let price = Double(priceIncVatText), price >= 0 else { return false }
        if selectedItemType.requiresDevice,
           let devices = order.devices, !devices.isEmpty,
           selectedDeviceId.isEmpty {
            return false
        }
        if discountKind != .none {
            guard let value = parseDecimal(discountValueText), value >= 0 else { return false }
            if discountKind == .percent && value > 100 { return false }
            if discountReasonMissing { return false }
        }
        return true
    }

    private var discountReasonMissing: Bool {
        discountKind != .none && discountReasonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var discountPercentOutOfRange: Bool {
        guard discountKind == .percent, let value = parseDecimal(discountValueText) else { return false }
        return value < 0 || value > 100
    }

    private var vatRateBinding: Binding<String> {
        Binding<String>(
            get: {
                if vatRate == vatRate.rounded(.down) {
                    return String(format: "%.0f", vatRate)
                }
                return String(format: "%.2f", vatRate)
            },
            set: { newValue in
                if let parsed = Double(newValue) {
                    vatRate = parsed
                } else if newValue.isEmpty {
                    vatRate = 0
                }
            }
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if showCreatedBanner, let productName = createdProductName {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Product created")
                                    .font(.subheadline.weight(.medium))
                                Text("\(productName) saved to your catalog")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                withAnimation { showCreatedBanner = false }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    itemTypePicker
                    if !isEditing {
                        productSearchSection
                    }
                    if let devices = order.devices, !devices.isEmpty {
                        devicePicker(devices)
                    }
                    descriptionField
                    quantityAndPriceSection
                    vatRateSection
                    discountSection
                    totalsPreview
                    if selectedItemType == .devicePurchase {
                        devicePurchaseNote
                    }
                }
                .padding()
            }
            .navigationTitle(isEditing ? "Edit Line Item" : "Add Line Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") {
                        Task {
                            await saveItem()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving || !isFormValid)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unexpected error occurred.")
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear {
                populateForEditing()
            }
            .sheet(isPresented: $showQuickCreate) {
                QuickCreateProductSheet(
                    initialName: quickCreateInitialName,
                    initialPrice: Double(priceIncVatText)
                ) { createdProduct in
                    selectCreatedProduct(createdProduct)
                }
            }
        }
    }

    // MARK: - Item Type Picker

    private var itemTypePicker: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(FormItemType.allCases) { type in
                Button {
                    selectedItemType = type
                    vatRate = defaultVatRate(for: type)
                    autoSelectSingleDevice()
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(type.color.opacity(0.15))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: type.icon)
                                    .font(.system(size: 18))
                                    .foregroundStyle(type.color)
                            )
                        Text(type.label)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text(type.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(
                        selectedItemType == type
                            ? type.color.opacity(0.08)
                            : Color.platformGray6
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectedItemType == type ? type.color : .clear,
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(isEditing)
                .opacity(isEditing && selectedItemType != type ? 0.4 : 1)
            }
        }
    }

    // MARK: - Device Picker

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
            .background(Color.platformGray6)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

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

    // MARK: - Product Search

    private var productSearchSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Search Products")
                .font(.subheadline).fontWeight(.medium)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search by name, SKU, or manufacturer...", text: $productSearchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if isSearchingProducts {
                    ProgressView()
                        .controlSize(.small)
                } else if !productSearchText.isEmpty {
                    Button {
                        productSearchText = ""
                        productSearchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.platformGray6)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onChange(of: productSearchText) { _, newValue in
                searchTask?.cancel()
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count >= 2 else {
                    productSearchResults = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await searchProducts(query: trimmed)
                }
            }

            if !productSearchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(productSearchResults) { product in
                        Button {
                            selectProduct(product)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    HStack(spacing: 6) {
                                        if let sku = product.sku {
                                            Text(sku)
                                                .font(.caption2)
                                                .monospaced()
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.platformGray5)
                                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                        }
                                        if let manufacturer = product.manufacturer {
                                            Text(manufacturer)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                Spacer(minLength: 8)
                                if let price = product.formattedPrice {
                                    Text(price)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if product.id != productSearchResults.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }

                    Divider()

                    Button {
                        quickCreateInitialName = productSearchText
                        showQuickCreate = true
                    } label: {
                        Label("Create new product instead", systemImage: "plus.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color.platformBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            } else if !isSearchingProducts && productSearchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
                VStack(spacing: 8) {
                    Text("No products found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        quickCreateInitialName = productSearchText
                        showQuickCreate = true
                    } label: {
                        Label("Create \"\(productSearchText)\" as new product", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                }
                .padding()
            }

            Text("Search your product catalog to auto-fill details")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func searchProducts(query: String) async {
        isSearchingProducts = true
        defer { isSearchingProducts = false }
        do {
            let results: [ProductTypeSearchResult] = try await APIClient.shared.request(
                .productTypes(search: query)
            )
            guard !Task.isCancelled else { return }
            productSearchResults = results
        } catch {
            guard !Task.isCancelled else { return }
            productSearchResults = []
        }
    }

    private func selectProduct(_ product: ProductTypeSearchResult) {
        selectedProductId = product.id
        descriptionText = product.name

        // Auto-fill price (inc VAT) from default sell price
        if let sellPrice = product.defaultSellPrice {
            // defaultSellPrice from API is already inc VAT
            priceIncVatText = String(format: "%.2f", sellPrice)
        }

        // Auto-fill VAT rate
        if let rate = product.vatRate {
            vatRate = rate
        }

        // Auto-detect item type from category
        if let category = product.category?.lowercased() {
            if category == "accessory" || category == "accessories" {
                selectedItemType = .accessory
            }
            // Leave as-is for other categories (user already picked type)
        }

        // Clear search
        productSearchText = ""
        productSearchResults = []
    }

    private func selectCreatedProduct(_ product: ProductTypeCreateResponse) {
        selectedProductId = product.id
        descriptionText = product.name

        if let price = product.defaultSellPrice {
            priceIncVatText = String(format: "%.2f", price)
        }
        if let vat = product.vatRate {
            vatRate = vat
        }

        let category = product.category.lowercased()
        if category == "accessory" || category == "accessories" {
            selectedItemType = .accessory
        }

        productSearchText = ""
        productSearchResults = []

        // Show creation confirmation banner
        createdProductName = product.name
        withAnimation { showCreatedBanner = true }
        Task {
            try? await Task.sleep(for: .seconds(4))
            await MainActor.run { withAnimation { showCreatedBanner = false } }
        }
    }

    // MARK: - Description Field

    private var descriptionField: some View {
        FormTextField(
            label: "Description",
            text: $descriptionText,
            placeholder: "e.g. Screen replacement - iPhone 13",
            keyboardType: .default,
            autocapitalization: .sentences,
            isRequired: true
        )
    }

    // MARK: - Quantity + Price Section

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
                    Button {
                        if quantity > 1 { quantity -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2).foregroundStyle(.secondary)
                    }
                    Text("\(quantity)")
                        .font(.title3).fontWeight(.semibold)
                        .frame(minWidth: 40)
                    Button {
                        quantity += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2).foregroundStyle(Color.accentColor)
                    }
                }
                .padding()
                .background(Color.platformGray6)
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

    // MARK: - VAT Rate Section

    private var vatRateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("VAT Rate (%)").font(.subheadline).fontWeight(.medium)
            TextField("20", text: vatRateBinding)
                .keyboardType(.decimalPad)
                .padding()
                .background(Color.platformGray6)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text("Default for \(selectedItemType.label): \(defaultVatRate(for: selectedItemType), specifier: "%.0f")%")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Discount Section

    private var discountSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Discount").font(.subheadline).fontWeight(.medium)

            Picker("Discount Type", selection: $discountKind) {
                ForEach(ItemDiscountKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            if discountKind != .none {
                TextField(
                    discountKind == .percent ? "Percent off (e.g. 10)" : "Amount off (\u{00A3})",
                    text: $discountValueText
                )
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .padding()
                .background(Color.platformGray6)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                FormTextField(
                    label: "Reason",
                    text: $discountReasonText,
                    placeholder: "e.g. Loyalty discount",
                    isRequired: true
                )

                if discountReasonMissing {
                    Text("A reason is required when a discount is applied.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if discountPercentOutOfRange {
                    Text("Percent must be between 0 and 100.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Totals Preview

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
        .background(Color.platformGray6)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Device Purchase Note

    private var devicePurchaseNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle").foregroundStyle(.orange)
            Text("This amount is a credit to the customer (stored as negative).")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private func defaultVatRate(for type: FormItemType) -> Double {
        guard let company = order.company else { return 20 }
        switch type {
        case .repair: return company.vatRateRepair ?? 20
        case .deviceSale: return company.vatRateDeviceSale ?? 0
        case .accessory: return company.vatRateAccessory ?? 20
        case .devicePurchase: return company.vatRateDevicePurchase ?? 0
        }
    }

    private func autoSelectSingleDevice() {
        if selectedItemType.requiresDevice,
           let devices = order.devices, devices.count == 1 {
            selectedDeviceId = devices[0].id
        }
    }

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
        // Convert stored net price → VAT-inclusive for display
        let net = abs(item.unitPrice)
        let incVat = net * (1 + item.vatRate / 100)
        priceIncVatText = String(format: "%.2f", incVat)

        if let percent = item.discountPercent, percent > 0 {
            discountKind = .percent
            discountValueText = formatDecimalForEditing(percent)
        } else if let amount = item.discountAmount, amount > 0 {
            discountKind = .amount
            discountValueText = formatDecimalForEditing(amount)
        } else {
            discountKind = .none
            discountValueText = ""
        }
        discountReasonText = item.discountReason ?? ""
    }

    // MARK: - Save

    private func saveItem() async {
        guard let priceIncVat = Double(priceIncVatText) else { return }
        let netPrice = vatRate > 0
            ? priceIncVat / (1 + vatRate / 100)
            : priceIncVat
        let isDevicePurchase = selectedItemType == .devicePurchase

        var discountPercent: Double?
        var discountAmount: Double?
        var discountReason: String?
        if discountKind != .none, let value = parseDecimal(discountValueText) {
            if discountKind == .percent {
                discountPercent = value
            } else {
                discountAmount = value
            }
            let reason = discountReasonText.trimmingCharacters(in: .whitespacesAndNewlines)
            discountReason = reason.isEmpty ? nil : reason
        }

        let request = OrderItemRequest(
            itemType: selectedItemType.rawValue,
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: quantity,
            unitPrice: isDevicePurchase ? -abs(netPrice) : netPrice,
            priceIncVat: isDevicePurchase ? -abs(priceIncVat) : priceIncVat,
            vatRate: vatRate,
            deviceId: selectedDeviceId.isEmpty ? nil : selectedDeviceId,
            productTypeId: selectedProductId,
            discountPercent: discountPercent,
            discountAmount: discountAmount,
            discountReason: discountReason
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
}
