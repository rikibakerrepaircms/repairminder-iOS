//
//  BuybackDetailView.swift
//  Repair Minder
//
//  Created on 20/02/2026.
//

import SwiftUI

struct BuybackDetailView: View {
    @StateObject private var viewModel: BuybackDetailViewModel
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
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadDetail() }
    }

    // MARK: - Content

    private func detailContent(_ buyback: BuybackDetail) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                statusHeader(buyback)
                costSummarySection(buyback)

                if let images = buyback.images, !images.isEmpty {
                    imagesSection(images)
                }

                deviceDetailsSection(buyback)
                purchaseInfoSection(buyback)

                if buyback.saleDate != nil {
                    saleInfoSection(buyback)
                }

                if let items = buyback.refurbishmentItems, !items.isEmpty {
                    refurbishmentSection(items, totals: buyback.totals)
                }

                if buyback.locationName != nil || buyback.engineerName != nil {
                    locationSection(buyback)
                }

                if let notes = buyback.notes, !notes.isEmpty {
                    notesSection(notes)
                }
            }
            .padding()
            .frame(maxWidth: isRegularWidth ? 700 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Status Header

    private func statusHeader(_ buyback: BuybackDetail) -> some View {
        HStack {
            BuybackStatusBadge(status: buyback.status)
            Spacer()
            if buyback.isVatLocked {
                Label("VAT Locked", systemImage: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Cost Summary

    private func costSummarySection(_ buyback: BuybackDetail) -> some View {
        SectionCard(title: "Cost Summary", icon: "sterlingsign.circle") {
            VStack(spacing: 8) {
                costRow("Purchase", value: buyback.formattedPurchaseAmount)
                costRow("Refurbishment", value: buyback.totals?.formattedRefurbishmentCost)

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

    private func costRow(_ label: String, value: String?, bold: Bool = false, negative: Bool = false) -> some View {
        HStack {
            Text(label)
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(value ?? "-")
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(negative ? Color.red : (value != nil ? Color.primary : Color.gray))
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

    private func detailRow(_ label: String, value: String?) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value ?? "-")
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
                if let date = buyback.purchaseDate {
                    detailRow("Date", value: DateFormatters.formatRelativeDate(date) ?? date)
                }
                detailRow("Amount", value: buyback.formattedPurchaseAmount)
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
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading device...")
                .foregroundStyle(.secondary)
        }
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
