//
//  QuickCreateProductSheet.swift
//  Repair Minder
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct QuickCreateProductSheet: View {
    let initialName: String
    let initialPrice: Double?
    let onCreated: (ProductTypeCreateResponse) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var category = ""
    @State private var productKind = "service"
    @State private var sellPrice: String
    @State private var vatRate = "20"
    @State private var manufacturer = ""
    @State private var showMoreDetails = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var similarProducts: [ProductTypeSearchResult] = []
    @State private var similarSearchTask: Task<Void, Never>?

    private let suggestedCategories = [
        "Screens", "Batteries", "Charging Ports", "Cameras",
        "Speakers", "Accessories", "Repairs", "Other"
    ]

    init(initialName: String, initialPrice: Double? = nil, onCreated: @escaping (ProductTypeCreateResponse) -> Void) {
        self.initialName = initialName
        self.initialPrice = initialPrice
        self.onCreated = onCreated
        _name = State(initialValue: initialName)
        _sellPrice = State(initialValue: initialPrice.map { String(format: "%.2f", $0) } ?? "")
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !category.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isSubmitting
    }

    var body: some View {
        NavigationStack {
            Form {
                // Product Kind Picker
                Section {
                    Picker("Type", selection: $productKind) {
                        Text("Service / Repair").tag("service")
                        Text("Product").tag("product")
                        Text("Stock Item").tag("inventory_item")
                    }
                    .pickerStyle(.menu)
                }

                // Required Fields
                Section("Details") {
                    TextField("Product Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .onChange(of: name) { _, _ in checkSimilarProducts() }

                    if !similarProducts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Similar products exist")
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundStyle(.orange)
                            }

                            ForEach(Array(similarProducts.prefix(3))) { product in
                                Button {
                                    useExistingProduct(product)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(product.name)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            if let sku = product.sku {
                                                Text(sku)
                                                    .font(.caption2)
                                                    .monospaced()
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if let price = product.formattedPrice {
                                            Text(price)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }

                            Text("Tap to use an existing product instead")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    TextField("Category", text: $category)
                        .textInputAutocapitalization(.words)

                    if category.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestedCategories, id: \.self) { cat in
                                    Button(cat) {
                                        category = cat
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }

                    HStack {
                        Text("\u{00A3}")
                        TextField("Sell Price", text: $sellPrice)
                            .keyboardType(.decimalPad)
                    }

                    HStack {
                        Text("VAT Rate %")
                        Spacer()
                        TextField("20", text: $vatRate)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                // Optional Fields
                if showMoreDetails {
                    Section("Additional Details") {
                        TextField("Manufacturer", text: $manufacturer)
                            .textInputAutocapitalization(.words)
                        HStack {
                            Text("SKU")
                            Spacer()
                            Text("Auto-generated")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button(showMoreDetails ? "Hide Additional Details" : "Show Additional Details") {
                        withAnimation {
                            showMoreDetails.toggle()
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createProduct() }
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private func createProduct() async {
        isSubmitting = true
        errorMessage = nil

        var request = ProductTypeCreateRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category.trimmingCharacters(in: .whitespaces),
            productKind: productKind
        )

        if let price = Double(sellPrice) {
            request.defaultSellPrice = price
        }
        if let vat = Double(vatRate) {
            request.vatRate = vat
        }
        if !manufacturer.trimmingCharacters(in: .whitespaces).isEmpty {
            request.manufacturer = manufacturer.trimmingCharacters(in: .whitespaces)
        }

        do {
            let product: ProductTypeCreateResponse = try await APIClient.shared.request(
                .quickCreateProductType,
                body: request
            )
            await MainActor.run {
                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                onCreated(product)
                dismiss()
            }
        } catch {
            await MainActor.run {
                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                #endif
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }

    private func checkSimilarProducts() {
        similarSearchTask?.cancel()
        let query = name.trimmingCharacters(in: .whitespaces)
        guard query.count >= 3 else {
            similarProducts = []
            return
        }
        similarSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            do {
                let results: [ProductTypeSearchResult] = try await APIClient.shared.request(
                    .productTypes(search: query)
                )
                guard !Task.isCancelled else { return }
                await MainActor.run { similarProducts = results }
            } catch {
                // Silent fail — convenience check only
            }
        }
    }

    private func useExistingProduct(_ product: ProductTypeSearchResult) {
        let response = ProductTypeCreateResponse(
            id: product.id,
            name: product.name,
            sku: product.sku ?? "",
            category: product.category ?? "",
            defaultSellPrice: product.defaultSellPrice,
            vatRate: product.vatRate,
            productKind: product.productKind,
            manufacturer: product.manufacturer,
            modelNumber: nil
        )
        onCreated(response)
        dismiss()
    }
}
