import SwiftUI

/// Full-screen kiosk container. Hosts the adaptive iPhone/iPad layout, wires all
/// sub-views and sheets, and bridges the "Card" button to the app's existing
/// `PosCardPaymentSheet` (Revolut / POS terminal payment).
struct KioskView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: KioskViewModel
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSize
    #endif

    @State private var allocationContext: AllocationContext?
    @State private var editingDiscountItemId: String?
    @State private var showGlobalDiscount = false

    // Card payment bridge state
    @State private var cardKioskOrder: KioskOrderResponse?
    @State private var cardFullOrder: Order?           // Order is Identifiable — drives .sheet(item:)
    @State private var cardTerminals: [PosTerminal] = []
    @State private var cardPaymentSucceeded = false
    @State private var isStartingCardPayment = false

    @State private var showExitConfirm = false
    #if os(iOS)
    @State private var iphoneTab: Int = 0
    #endif

    init(locationId: String? = nil) {
        _viewModel = StateObject(wrappedValue: KioskViewModel(locationId: locationId))
    }

    /// One shape for both "add new product" (from the catalog) and "reopen allocation
    /// for an existing serialized cart item". Carries plain fields so we never have to
    /// reconstruct a fragile `ProductTypeSearchResult`.
    struct AllocationContext: Identifiable {
        let id = UUID()
        let productTypeId: String
        let name: String
        let unitPrice: Double
        let vatRate: Double
        let sku: String?
        let existingItemId: String?
    }

    var body: some View {
        content
            .overlay(alignment: .top) { header }
            .sheet(item: $allocationContext) { ctx in allocationSheet(ctx) }
            .sheet(isPresented: $showGlobalDiscount) { globalDiscountSheet }
            .sheet(item: Binding(get: { editingDiscountItemId.map { IdBox(id: $0) } },
                                 set: { editingDiscountItemId = $0?.id })) { box in
                itemDiscountSheet(box.id)
            }
            .sheet(item: $cardFullOrder) { order in cardSheet(order) }
            .task { await viewModel.loadPosProvider() }
            .alert("Discard sale?", isPresented: $showExitConfirm) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep", role: .cancel) {}
            } message: { Text("The current cart will be lost.") }
            .alert("Payment error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } })) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: { Text(viewModel.errorMessage ?? "") }
    }

    // MARK: - Mode-driven content

    @ViewBuilder private var content: some View {
        switch viewModel.mode {
        case .shopping:
            shoppingLayout.padding(.top, 52)
        case .processing:
            ProgressView("Processing…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .receipt:
            if let order = viewModel.completedOrder {
                KioskReceiptView(
                    order: order,
                    onNewSale: { viewModel.startNewSale() },
                    onExit: { dismiss() })
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Kiosk").font(.headline)
            Spacer()
            Button {
                if viewModel.isEmpty || viewModel.mode == .receipt {
                    dismiss()
                } else {
                    showExitConfirm = true
                }
            } label: {
                Label("Exit", systemImage: "xmark")
            }
        }
        .padding(.horizontal)
        .frame(height: 44)
        .background(.bar)
        .opacity(viewModel.mode == .shopping ? 1 : 0)
    }

    // MARK: - Adaptive shopping layout

    @ViewBuilder private var shoppingLayout: some View {
        #if os(iOS)
        if hSize == .regular {
            HStack(spacing: 0) {
                cartPanel.frame(width: 380)
                Divider()
                catalogPanel
            }
        } else {
            VStack(spacing: 0) {
                Picker("", selection: $iphoneTab) {
                    Text("Catalog").tag(0)
                    Text("Cart (\(viewModel.items.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(8)
                if iphoneTab == 0 { catalogPanel } else { cartPanel }
            }
        }
        #else
        HStack(spacing: 0) {
            cartPanel.frame(width: 380)
            Divider()
            catalogPanel
        }
        #endif
    }

    private var catalogPanel: some View {
        KioskCatalogPanel(
            viewModel: viewModel,
            onSelectProduct: { handleSelectProduct($0) })
    }

    private var cartPanel: some View {
        KioskCartPanel(
            viewModel: viewModel,
            onPayCard: { Task { await startCardPayment() } },
            onSubmitPayment: { method, amount, notes in
                Task { await viewModel.submitCashOrManual(method: method, amount: amount, notes: notes) }
            },
            onEditItemDiscount: { editingDiscountItemId = $0.id },
            onEditGlobalDiscount: { showGlobalDiscount = true },
            onManageAssets: { item in
                if let ptId = item.productTypeId {
                    allocationContext = AllocationContext(
                        productTypeId: ptId,
                        name: item.description,
                        unitPrice: item.unitPrice,
                        vatRate: item.vatRate,
                        sku: item.productSku,
                        existingItemId: item.id)
                }
            })
    }

    // MARK: - Product selection

    private func handleSelectProduct(_ product: KioskProduct) {
        if !product.id.isEmpty {
            Task {
                let assets = (try? await KioskService()
                    .availableAssets(productTypeId: product.id, search: nil)) ?? []
                if assets.isEmpty {
                    addDirect(product)
                } else {
                    allocationContext = AllocationContext(
                        productTypeId: product.id,
                        name: product.name,
                        unitPrice: product.defaultSellPrice ?? 0,
                        vatRate: product.vatRate ?? 20,
                        sku: product.sku,
                        existingItemId: nil)
                }
            }
        } else {
            addDirect(product)
        }
    }

    private func addDirect(_ product: KioskProduct) {
        viewModel.addItem(KioskCartItem(
            productTypeId: product.id.isEmpty ? nil : product.id,
            description: product.name,
            quantity: 1,
            unitPrice: product.defaultSellPrice ?? 0,
            vatRate: product.vatRate ?? 20,
            itemType: "accessory",
            productSku: product.sku,
            selectedAssets: []))
    }

    // MARK: - Sheets

    private func allocationSheet(_ ctx: AllocationContext) -> some View {
        let existing = ctx.existingItemId.flatMap { id in viewModel.items.first { $0.id == id } }
        return KioskAllocationSheet(
            productName: ctx.name,
            productTypeId: ctx.productTypeId,
            unitPrice: ctx.unitPrice,
            vatRate: ctx.vatRate,
            initialQuantity: existing?.quantity ?? 1,
            initialAssetIds: Set(existing?.selectedAssets.map { $0.id } ?? []),
            onConfirm: { assets, qty in
                if let id = ctx.existingItemId {
                    viewModel.updateItem(id) { $0.quantity = qty; $0.selectedAssets = assets }
                } else {
                    viewModel.addItem(KioskCartItem(
                        productTypeId: ctx.productTypeId,
                        description: ctx.name,
                        quantity: qty,
                        unitPrice: ctx.unitPrice,
                        vatRate: ctx.vatRate,
                        itemType: "accessory",
                        productSku: ctx.sku,
                        selectedAssets: assets))
                }
            })
    }

    private func itemDiscountSheet(_ itemId: String) -> some View {
        let item = viewModel.items.first { $0.id == itemId }
        return KioskDiscountSheet(
            title: "Item Discount",
            initial: KioskDiscountValue(
                percent: item?.discountPercent,
                amount: item?.discountAmount,
                reason: item?.discountReason),
            onSave: { value in
                viewModel.updateItem(itemId) {
                    $0.discountPercent = value.percent
                    $0.discountAmount = value.amount
                    $0.discountReason = value.reason
                }
            })
    }

    private var globalDiscountSheet: some View {
        KioskDiscountSheet(
            title: "Order Discount",
            initial: KioskDiscountValue(
                percent: viewModel.globalDiscountPercent,
                amount: viewModel.globalDiscountAmount,
                reason: viewModel.globalDiscountReason),
            onSave: { value in
                viewModel.globalDiscountPercent = value.percent
                viewModel.globalDiscountAmount = value.amount
                viewModel.globalDiscountReason = value.reason
            })
    }

    // MARK: - Card payment bridge

    @MainActor
    private func startCardPayment() async {
        // Guard against a double-tap on "Card": without this, a second tap during the async
        // window creates a second unpaid order that is never cancelled (orphaned order).
        guard !isStartingCardPayment else { return }
        isStartingCardPayment = true
        defer { isStartingCardPayment = false }
        guard let kioskOrder = await viewModel.createUnpaidOrderForCard() else { return }
        cardKioskOrder = kioskOrder
        cardPaymentSucceeded = false
        cardTerminals = (try? await PaymentService().fetchTerminals(locationId: viewModel.locationId)) ?? []
        if let order: Order = try? await APIClient.shared.request(.order(id: kioskOrder.id)) {
            cardFullOrder = order
        } else {
            // Couldn't load the full order — roll back the unpaid order we just created.
            await viewModel.cancelUnpaidOrder(id: kioskOrder.id)
            cardKioskOrder = nil
        }
    }

    private func cardSheet(_ order: Order) -> some View {
        PosCardPaymentSheet(
            order: order,
            balanceDue: cardKioskOrder?.totals.grandTotal ?? 0,
            depositsEnabled: false,
            terminals: cardTerminals,
            paymentService: PaymentService(),
            onSuccess: {
                cardPaymentSucceeded = true
                if let ko = cardKioskOrder { viewModel.cardPaymentSucceeded(order: ko) }
            })
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onDisappear {
            if !cardPaymentSucceeded, let ko = cardKioskOrder {
                Task { await viewModel.cancelUnpaidOrder(id: ko.id) }
            }
            cardFullOrder = nil
        }
    }
}

/// Small Identifiable box so a `String` item id can drive a `.sheet(item:)`.
private struct IdBox: Identifiable { let id: String }
