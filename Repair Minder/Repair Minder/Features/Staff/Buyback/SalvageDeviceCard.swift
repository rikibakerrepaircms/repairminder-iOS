import SwiftUI

/// Salvage a buyback device into inventory assets. Configure items (group + grade +
/// value + screen LCD/glass + location), stage a batch, book within budget (confirm on
/// the first salvage), and remove booked salvage assets. Mirrors web `SalvageDeviceCard`.
struct SalvageDeviceCard: View {
    @StateObject private var viewModel: SalvageViewModel
    let onChanged: () async -> Void

    @State private var showConfirm = false
    @State private var selectedAssetId: String?

    init(buybackId: String, purchaseAmount: Double, salvaged: [SalvagedAssetSummary], onChanged: @escaping () async -> Void) {
        _viewModel = StateObject(wrappedValue: SalvageViewModel(buybackId: buybackId, purchaseAmount: purchaseAmount, salvaged: salvaged))
        self.onChanged = onChanged
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if viewModel.purchaseAmount <= 0 {
                Text("No purchase price recorded — salvage items must be booked at £0.").font(.caption).foregroundStyle(.orange)
            }
            stagingForm
            if !viewModel.staged.isEmpty { stagedList; bookButton }
            bookedList
            if let err = viewModel.error { Text(err).font(.footnote).foregroundStyle(.red) }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task { await viewModel.loadReferenceData() }
        .navigationDestination(item: $selectedAssetId) { InventoryDetailView(assetId: $0) }
        .alert("Mark device as Salvaged?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Salvage", role: .destructive) { Task { await book() } }
        } message: {
            Text("This books the parts as inventory and removes the device from sale.")
        }
    }

    private var header: some View {
        HStack {
            Label("Salvage", systemImage: "wrench.and.screwdriver").font(.headline)
            Spacer()
            Text("\(CurrencyFormatter.format(viewModel.remaining)) of \(CurrencyFormatter.format(viewModel.purchaseAmount)) left")
                .font(.caption).foregroundStyle(viewModel.overCap ? .red : .secondary)
        }
    }

    private var stagingForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Search inventory groups…", text: $viewModel.groupQuery)
                    .onChange(of: viewModel.groupQuery) { _, q in Task { await viewModel.searchGroups(q) } }
                if let selected = viewModel.selectedGroup {
                    HStack {
                        Text("Selected: \(selected.name)").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear", role: .destructive) {
                            viewModel.selectedGroup = nil
                            viewModel.groupQuery = ""
                        }.font(.caption)
                    }
                }
                ForEach(viewModel.groups) { g in
                    Button {
                        viewModel.selectedGroup = g
                        viewModel.groupQuery = g.name
                    } label: {
                        HStack {
                            Text(g.name)
                            Spacer()
                            if viewModel.selectedGroup?.id == g.id { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
            Picker("Grade", selection: $viewModel.grade) {
                ForEach(["A", "B", "C"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented)
            if viewModel.isScreen {
                Picker("LCD working?", selection: $viewModel.lcdWorking) {
                    Text("—").tag(Int?.none); Text("Yes").tag(Int?.some(1)); Text("No").tag(Int?.some(0))
                }.pickerStyle(.segmented)
                Picker("Glass cracked?", selection: $viewModel.glassCracked) {
                    Text("—").tag(Int?.none); Text("Yes").tag(Int?.some(1)); Text("No").tag(Int?.some(0))
                }.pickerStyle(.segmented)
            }
            TextField("Value (£)", text: $viewModel.value)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            Picker("Location", selection: $viewModel.locationId) {
                Text("Select…").tag(String?.none)
                ForEach(viewModel.locations) { Text($0.name).tag(String?.some($0.id)) }
            }
            .onChange(of: viewModel.locationId) { _, new in
                viewModel.subLocationId = nil
                if let id = new { Task { await viewModel.loadSubLocations(id) } }
            }
            if !viewModel.subLocations.isEmpty {
                Picker("Sub-location", selection: $viewModel.subLocationId) {
                    Text("None").tag(String?.none)
                    ForEach(viewModel.subLocations) { Text(subLocationLabel($0)).tag(String?.some($0.id)) }
                }
            }
            TextField("Notes", text: $viewModel.notes, axis: .vertical).lineLimit(1...3)
            Button { viewModel.addToBatch() } label: { Label("Add to batch", systemImage: "plus.circle") }
                .disabled(!viewModel.canAdd || viewModel.isBooking)
                .accessibilityIdentifier("salvage-add")
        }
    }

    /// Compose "code — description" when both are present; fall back to whichever exists.
    private func subLocationLabel(_ sl: AssetSubLocationOption) -> String {
        switch (sl.code, sl.description) {
        case let (code?, desc?): return "\(code) — \(desc)"
        case let (code?, nil): return code
        case let (nil, desc?): return desc
        default: return "—"
        }
    }

    private var stagedList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Batch").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(viewModel.staged) { item in
                HStack {
                    Text("\(item.name) · Grade \(item.request.conditionGrade) · \(CurrencyFormatter.format(item.request.value ?? 0))").font(.caption)
                    Spacer()
                    Button(role: .destructive) { viewModel.removeStaged(item.id) } label: { Image(systemName: "trash") }.buttonStyle(.plain)
                }
            }
        }
    }

    private var bookButton: some View {
        Button {
            if viewModel.needsConfirmation { showConfirm = true } else { Task { await book() } }
        } label: {
            HStack { Spacer(); Text("Book \(viewModel.staged.count) item\(viewModel.staged.count == 1 ? "" : "s") as assets"); Spacer() }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canBook)
        .accessibilityIdentifier("salvage-book")
        .overlay(alignment: .trailing) {
            if viewModel.overCap {
                Text("Over budget by \(CurrencyFormatter.format(abs(viewModel.remaining)))").font(.caption2).foregroundStyle(.red)
            }
        }
    }

    private var bookedList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Salvaged assets").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if viewModel.salvaged.isEmpty {
                Text("No parts salvaged from this device yet.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(viewModel.salvaged) { a in
                HStack {
                    Button { selectedAssetId = a.id } label: {
                        VStack(alignment: .leading) {
                            Text(a.assetTag).font(.caption.monospaced())
                            Text(bookedRowCaption(a)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                    Spacer()
                    if viewModel.removingId == a.id {
                        ProgressView().controlSize(.small)
                    } else {
                        Button(role: .destructive) { Task { await viewModel.removeSalvaged(a.id); await onChanged() } } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain)
                            .disabled(viewModel.removingId != nil)
                    }
                }
            }
        }
    }

    private func bookedRowCaption(_ a: SalvagedAssetSummary) -> String {
        var parts = ["\(a.name) · Grade \(a.conditionGrade ?? "—")"]
        if let loc = a.locationName, !loc.isEmpty { parts.append(loc) }
        parts.append(CurrencyFormatter.format(a.cost ?? 0))
        return parts.joined(separator: " · ")
    }

    private func book() async {
        if await viewModel.book() { await onChanged() }
    }
}
