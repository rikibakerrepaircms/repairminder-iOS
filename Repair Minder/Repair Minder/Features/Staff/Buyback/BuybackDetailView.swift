//
//  BuybackDetailView.swift
//  Repair Minder
//
//  Created on 20/02/2026.
//

import SwiftUI

struct BuybackDetailView: View {
    @StateObject private var viewModel: BuybackDetailViewModel
    @State private var showPurchasePrice = false
    @State private var showPurchaseEdit = false
    @State private var showAddNote = false
    @State private var showSell = false
    @State private var showRefurbSheet = false
    @State private var editingRefurbItem: RefurbishmentItem?
    @State private var pendingDeleteRefurbItem: RefurbishmentItem?
    @State private var showListingEdit = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    init(buybackId: String) {
        _viewModel = StateObject(wrappedValue: BuybackDetailViewModel(buybackId: buybackId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.buyback == nil {
                loadingView
            } else if let error = viewModel.error, viewModel.buyback == nil {
                errorView(error)
            } else if let buyback = viewModel.buyback {
                detailContent(buyback)
            }
        }
        .navigationTitle(viewModel.buyback?.deviceDisplayName ?? "Device")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await viewModel.loadDetail() }
        .onDisappear { viewModel.cancelListingGeneration() }
        .sheet(isPresented: $showPurchaseEdit) {
            if let buyback = viewModel.buyback {
                BuybackPurchaseEditSheet(detail: buyback) { fields in
                    let success = await viewModel.updatePurchase(fields: fields)
                    return success ? nil : viewModel.actionError
                }
            }
        }
        .sheet(isPresented: $showAddNote) {
            AddBuybackNoteSheet { text in
                await viewModel.addNote(text)
            }
        }
        .sheet(isPresented: $showSell) {
            if let buyback = viewModel.buyback {
                SellBuybackSheet(detail: buyback) { request in
                    await viewModel.sell(request)
                }
            }
        }
        .sheet(isPresented: $showRefurbSheet) {
            RefurbishmentEditSheet(existingItem: editingRefurbItem) { addRequest, updateRequest in
                if let addRequest {
                    return await viewModel.addRefurbishment(addRequest)
                } else if let updateRequest, let itemId = editingRefurbItem?.id {
                    return await viewModel.updateRefurbishment(itemId: itemId, updateRequest)
                }
                return "Nothing to save"
            }
        }
        .sheet(isPresented: $showListingEdit) {
            if let buyback = viewModel.buyback {
                ListingEditSheet(detail: buyback) { fields in
                    let success = await viewModel.updateListing(fields: fields)
                    return success ? nil : viewModel.actionError
                }
            }
        }
        .confirmationDialog(
            "Delete this refurbishment item?",
            isPresented: Binding(
                get: { pendingDeleteRefurbItem != nil },
                set: { if !$0 { pendingDeleteRefurbItem = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let itemId = pendingDeleteRefurbItem?.id {
                    Task { _ = await viewModel.deleteRefurbishment(itemId: itemId) }
                }
                pendingDeleteRefurbItem = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteRefurbItem = nil
            }
        }
    }

    // MARK: - Content

    private func detailContent(_ buyback: BuybackDetail) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                statusHeader(buyback)
                publishSection(buyback)
                listingSection(buyback)
                costSummarySection(buyback)

                if let images = buyback.images, !images.isEmpty {
                    imagesSection(images)
                }

                deviceDetailsSection(buyback)
                purchaseInfoSection(buyback)

                if buyback.saleDate != nil {
                    saleInfoSection(buyback)
                }

                refurbishmentSection(buyback.refurbishmentItems ?? [], totals: buyback.totals)

                if buyback.locationName != nil || buyback.engineerName != nil {
                    locationSection(buyback)
                }

                if buyback.status.lowercased() != "sold" {
                    SalvageDeviceCard(
                        buybackId: buyback.id,
                        purchaseAmount: buyback.purchaseAmount ?? 0,
                        salvaged: buyback.salvagedAssets ?? [],
                        onChanged: { await viewModel.refresh() })
                }

                notesSection(buyback.notes ?? [])
            }
            .padding()
            .frame(maxWidth: isRegularWidth ? 700 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Status Header

    private func statusHeader(_ buyback: BuybackDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                BuybackStatusBadge(status: buyback.status)
                Spacer()
                if buyback.isVatLocked {
                    Label("VAT Locked", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            HStack {
                let currentStatus = buyback.buybackStatus ?? .unknown
                let transitions = nextBuybackStatuses(for: currentStatus)
                if !transitions.isEmpty {
                    Menu {
                        ForEach(transitions, id: \.self) { target in
                            Button(target.displayName) {
                                Task { _ = await viewModel.changeStatus(to: target.rawValue) }
                            }
                        }
                    } label: {
                        Label("Change Status", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                    }
                    .disabled(viewModel.isMutating)
                }

                Spacer()

                if currentStatus == .forSale {
                    Button("Sell") { showSell = true }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(viewModel.isMutating)
                }
            }

            if let actionError = viewModel.actionError {
                Text(actionError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Storefront Publish

    private func publishSection(_ buyback: BuybackDetail) -> some View {
        SectionCard(title: "Storefront", icon: "storefront") {
            Toggle(
                "Published to storefront",
                isOn: Binding(
                    get: { buyback.storefrontPublished == 1 },
                    set: { newValue in Task { _ = await viewModel.setPublished(newValue) } }
                )
            )
            .disabled(viewModel.isMutating)
        }
    }

    // MARK: - AI Listing

    private func listingSection(_ buyback: BuybackDetail) -> some View {
        SectionCard(title: "Listing", icon: "sparkles") {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.isGeneratingListing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Generating…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if buyback.listingTitle != nil {
                    Text(buyback.listingTitle ?? "")
                        .font(.subheadline.weight(.semibold))

                    if let short = buyback.listingShortDescription, !short.isEmpty {
                        Text(short)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let sellPrice = buyback.formattedSellPrice {
                        detailRow("Price", value: sellPrice)
                    }
                    if let condition = buyback.listingCondition, !condition.isEmpty {
                        detailRow("Condition", value: condition.replacingOccurrences(of: "_", with: " ").capitalized)
                    }
                    if let generatedAt = buyback.listingGeneratedAt,
                       let formatted = DateFormatters.formatRelativeDate(generatedAt) {
                        detailRow("Generated", value: formatted)
                    }

                    HStack {
                        Button("Edit listing") { showListingEdit = true }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.isMutating)

                        Button("Regenerate") {
                            viewModel.beginListingGeneration()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(viewModel.isMutating || viewModel.isGeneratingListing)
                    }
                } else {
                    Text("No AI listing generated yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Generate listing") {
                        viewModel.beginListingGeneration()
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(viewModel.isMutating || viewModel.isGeneratingListing)
                    .accessibilityIdentifier("buyback-generate-listing")
                }

                if let listingError = viewModel.listingError {
                    Text(listingError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Cost Summary

    private func costSummarySection(_ buyback: BuybackDetail) -> some View {
        SectionCard(title: "Cost Summary", icon: "sterlingsign.circle") {
            VStack(spacing: 8) {
                costRow("Purchase", value: buyback.formattedPurchaseAmount, blurred: !showPurchasePrice)
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showPurchasePrice.toggle() } }
                costRow("Refurbishment", value: buyback.totals?.formattedRefurbishmentCost)

                if let totals = buyback.totals, let labour = totals.labourCost, labour > 0 {
                    costRow("Labour (\(totals.repairMinutes ?? 0)m)", value: CurrencyFormatter.format(labour))
                }

                if let salvage = buyback.salvageBudget {
                    if let cap = salvage.cap {
                        costRow("Salvage budget", value: CurrencyFormatter.format(cap))
                    }
                    if let booked = salvage.booked {
                        costRow("Salvage booked", value: CurrencyFormatter.format(booked))
                    }
                    if let remaining = salvage.remaining {
                        costRow("Salvage remaining", value: CurrencyFormatter.format(remaining))
                    }
                }

                Divider()

                costRow("Total Cost", value: buyback.totals?.formattedTotalCost, bold: true)

                if buyback.sellPrice != nil || buyback.saleAmount != nil {
                    Divider()

                    if let sellPrice = buyback.formattedSellPrice {
                        costRow("Sell Price", value: sellPrice)
                    }
                    if let specialOffer = buyback.specialOfferPrice {
                        costRow("Offer Price", value: CurrencyFormatter.format(specialOffer))
                    }
                    if buyback.saleAmount != nil {
                        costRow("Sale Amount", value: buyback.formattedSaleAmount)
                    }
                    if let fee = buyback.formattedPlatformFee {
                        costRow("Platform Fee", value: fee, negative: true)
                    }

                    Divider()

                    if let profit = buyback.totals?.profit {
                        HStack {
                            Text("Net Profit")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(CurrencyFormatter.format(profit))
                                .fontWeight(.semibold)
                                .foregroundStyle(profit >= 0 ? .green : .red)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }

    private func costRow(_ label: String, value: String?, bold: Bool = false, negative: Bool = false, blurred: Bool = false) -> some View {
        HStack {
            Text(label)
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(value ?? "-")
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(negative ? Color.red : (value != nil ? Color.primary : Color.gray))
                .blur(radius: blurred ? 4 : 0)
        }
        .font(.subheadline)
    }

    // MARK: - Images

    private func imagesSection(_ images: [BuybackImage]) -> some View {
        SectionCard(title: "Photos (\(images.count))", icon: "photo.on.rectangle") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(images) { image in
                        AuthenticatedImageView(
                            imageId: image.id,
                            width: 80,
                            height: 80
                        )
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    // MARK: - Device Details

    private func deviceDetailsSection(_ buyback: BuybackDetail) -> some View {
        SectionCard(title: "Device Details", icon: "iphone") {
            VStack(spacing: 6) {
                detailRow("Brand", value: buyback.brand)
                detailRow("Model", value: buyback.model)
                detailRow("IMEI", value: buyback.imei)
                if let imei2 = buyback.imei2, !imei2.isEmpty {
                    detailRow("IMEI 2", value: imei2)
                }
                detailRow("Serial", value: buyback.serialNumber)
                detailRow("Storage", value: buyback.storageCapacity)
                detailRow("Colour", value: buyback.colour)

                if let battery = buyback.batteryHealth, !battery.isEmpty {
                    detailRow("Battery", value: battery)
                }

                Divider()

                checkRow("Find My", status: buyback.findMyStatus, goodValues: ["off"])
                checkRow("iCloud", status: buyback.icloudStatus, goodValues: ["clean"])
                checkRow("Blacklist", status: buyback.blacklistStatus, goodValues: ["clean"])
                checkRow("MDM", status: buyback.mdmStatus, goodValues: ["none"])
                if let simLock = buyback.simLockStatus, !simLock.isEmpty {
                    checkRow("SIM Lock", status: simLock, goodValues: ["unlocked"])
                }
            }
        }
    }

    private func detailRow(_ label: String, value: String?, blurred: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value ?? "-")
                .blur(radius: blurred ? 4 : 0)
            Spacer()
        }
        .font(.subheadline)
    }

    private func checkRow(_ label: String, status: String?, goodValues: [String]) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            if let status, !status.isEmpty {
                let normalised = status.lowercased()
                let isGood = goodValues.contains(normalised)
                    || normalised == "no"
                    || normalised == "none"
                    || normalised == "off"
                    || normalised == "unlocked"
                HStack(spacing: 4) {
                    Text(status.capitalized)
                    Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(isGood ? .green : .orange)
                        .font(.caption)
                }
            } else {
                Text("-")
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .font(.subheadline)
    }

    // MARK: - Purchase Info

    private func purchaseInfoSection(_ buyback: BuybackDetail) -> some View {
        SectionCard(title: "Purchase Info", icon: "cart") {
            VStack(spacing: 6) {
                HStack {
                    Spacer()
                    Button("Edit") { showPurchaseEdit = true }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(viewModel.isMutating)
                }

                if let date = buyback.purchaseDate {
                    detailRow("Date", value: DateFormatters.formatRelativeDate(date) ?? date)
                }
                detailRow("Amount", value: buyback.formattedPurchaseAmount, blurred: !showPurchasePrice)
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showPurchasePrice.toggle() } }
                if let method = buyback.purchasePaymentMethod {
                    detailRow("Payment", value: method.replacingOccurrences(of: "_", with: " ").capitalized)
                }
                if let ref = buyback.purchaseOrderReference, !ref.isEmpty {
                    detailRow("Reference", value: ref)
                }
                if let notes = buyback.purchaseNotes, !notes.isEmpty {
                    Divider()
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Sale Info

    private func saleInfoSection(_ buyback: BuybackDetail) -> some View {
        SectionCard(title: "Sale Info", icon: "tag") {
            VStack(spacing: 6) {
                if let date = buyback.saleDate {
                    detailRow("Date", value: DateFormatters.formatRelativeDate(date) ?? date)
                }
                detailRow("Amount", value: buyback.formattedSaleAmount)
                if let channel = buyback.saleChannel {
                    detailRow("Channel", value: channel.capitalized)
                }
                if let fee = buyback.formattedPlatformFee {
                    detailRow("Platform Fee", value: fee)
                }
            }
        }
    }

    // MARK: - Refurbishment

    private func refurbishmentSection(_ items: [RefurbishmentItem], totals: BuybackTotals?) -> some View {
        SectionCard(title: "Refurbishment (\(items.count) items)", icon: "wrench.and.screwdriver") {
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Button("Add item") {
                        editingRefurbItem = nil
                        showRefurbSheet = true
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("refurb-add")
                    .disabled(viewModel.isMutating)
                }

                if items.isEmpty {
                    Text("No refurbishment items yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(items) { item in
                    HStack {
                        if let type = item.formattedItemType {
                            Text(type)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(refurbTypeBadgeColor(item.itemType).opacity(0.1))
                                .foregroundStyle(refurbTypeBadgeColor(item.itemType))
                                .clipShape(Capsule())
                        }

                        Text(item.description ?? "Unknown")
                            .font(.subheadline)

                        Spacer()

                        Text(item.formattedTotalCost ?? "-")
                            .font(.subheadline.monospacedDigit())

                        Button {
                            pendingDeleteRefurbItem = item
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isMutating)
                        .accessibilityIdentifier("refurb-delete-\(item.id)")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingRefurbItem = item
                        showRefurbSheet = true
                    }
                }

                if let total = totals?.formattedRefurbishmentCost {
                    Divider()
                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(total)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func refurbTypeBadgeColor(_ type: String?) -> Color {
        switch type?.lowercased() {
        case "part": return .blue
        case "labor": return .purple
        default: return .gray
        }
    }

    // MARK: - Location

    private func locationSection(_ buyback: BuybackDetail) -> some View {
        SectionCard(title: "Location", icon: "mappin.and.ellipse") {
            VStack(spacing: 6) {
                if let location = buyback.locationName {
                    detailRow("Location", value: location)
                }
                if let sub = buyback.subLocationName, !sub.isEmpty {
                    detailRow("Sub-loc", value: sub)
                }
                if let engineer = buyback.engineerName {
                    detailRow("Assigned", value: engineer)
                }
            }
        }
    }

    // MARK: - Notes

    private func notesSection(_ notes: [BuybackNote]) -> some View {
        SectionCard(title: "Notes (\(notes.count))", icon: "note.text") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    Button("Add note") { showAddNote = true }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(viewModel.isMutating)
                }

                if notes.isEmpty {
                    Text("No notes yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(notes.enumerated()), id: \.element.stableId) { index, note in
                    VStack(alignment: .leading, spacing: 4) {
                        if let body = note.body {
                            Text(body)
                                .font(.subheadline)
                        }
                        HStack(spacing: 4) {
                            if let author = note.createdBy {
                                Text(author)
                            }
                            if let date = note.createdAt,
                               let formatted = DateFormatters.formatRelativeDate(date) {
                                Text("·")
                                Text(formatted)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }

                    if index < notes.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Loading & Error

    private var loadingView: some View {
        LottieLoadingView(size: 100, message: "Loading device...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Retry") {
                Task { await viewModel.loadDetail() }
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    NavigationStack {
        BuybackDetailView(buybackId: "test")
    }
}
