//
//  CustomerDeviceCard.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// Card component showing device details in customer portal
struct CustomerDeviceCard: View {
    let device: CustomerDevice
    let items: [CustomerOrderItem]
    let currencyCode: String
    let onApprove: (() -> Void)?

    @State private var showDiagnostics: Bool = false
    @State private var showChecklist: Bool = false
    @State private var showImages: Bool = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Device Header
            deviceHeader

            // Progress Timeline
            CustomerProgressBar(status: device.status, workflowType: device.workflowType)

            // Authorization Status Banner
            if device.isApproved {
                approvalBanner
            }

            // Collection Location (when ready)
            if device.isReadyForCollection, let location = device.collectionLocation {
                collectionLocationCard(location)
            }

            // Payment Complete Banner (for buyback)
            if device.status == "payment_made", let payment = device.payment {
                paymentCompleteBanner(payment)
            }

            // Diagnostic Report (when awaiting authorization)
            if device.isAwaitingAuthorization && device.hasDiagnosticInfo {
                diagnosticSection
            }

            // Pre-Repair Images (when awaiting authorization)
            if device.isAwaitingAuthorization && device.hasImages {
                imagesSection
            }

            // Pre-Repair Checklist
            if device.isAwaitingAuthorization && device.hasChecklist {
                checklistSection
            }

            // Quote/Offer Items
            if !items.isEmpty && (device.isAwaitingAuthorization || device.isApproved) {
                quoteSection
            }

            // Customer Reported Issues
            if let issues = device.customerReportedIssues, !issues.isEmpty {
                reportedIssuesSection(issues)
            }

            // Approve Button
            if device.isAwaitingAuthorization, let onApprove = onApprove {
                Button(action: onApprove) {
                    Text("Review \(device.quoteLabel)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Device Header

    private var deviceHeader: some View {
        HStack(spacing: 12) {
            // Device Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.platformGray6)
                    .frame(width: 44, height: 44)

                Image(systemName: deviceIcon)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if horizontalSizeClass != .regular {
                        workflowBadge
                    }

                    // Serial/IMEI
                    if let serial = device.serialNumber {
                        Text(serial)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let imei = device.imei {
                        Text("IMEI: \(imei)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if horizontalSizeClass == .regular {
                workflowBadge
            }
        }
    }

    private var workflowBadge: some View {
        Text(device.workflowType.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(device.isBuyback ? .purple : .blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((device.isBuyback ? Color.purple : Color.blue).opacity(0.15))
            .clipShape(Capsule())
    }

    private var diagnosticItems: [(label: String, value: String)] {
        var items: [(label: String, value: String)] = []
        if let v = device.visualCheck { items.append(("Visual Check", v)) }
        if let v = device.electricalCheck { items.append(("Electrical Check", v)) }
        if let v = device.mechanicalCheck { items.append(("Mechanical Check", v)) }
        if let v = device.damageMatchesReported { items.append(("Damage Assessment", v)) }
        return items
    }

    private var deviceIcon: String {
        let name = device.displayName.lowercased()
        if name.contains("iphone") || name.contains("phone") {
            return "iphone"
        } else if name.contains("ipad") || name.contains("tablet") {
            return "ipad"
        } else if name.contains("mac") || name.contains("laptop") {
            return "laptopcomputer"
        } else if name.contains("watch") {
            return "applewatch"
        } else {
            return "desktopcomputer"
        }
    }

    // MARK: - Approval Banner

    private var approvalBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(device.quoteLabel) Approved")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let date = device.authorizedAt {
                    Text(formatDate(date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Collection Location

    private func collectionLocationCard(_ location: CollectionLocation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.green)
                Text("Ready for Collection")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(location.formattedAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Opening Hours
            if let hours = location.openingHours?.todayHours {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Today: \(hours.displayString)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            // Maps Buttons
            if location.hasMapsUrl {
                HStack(spacing: 12) {
                    if let googleUrl = location.googleMapsUrl, let url = URL(string: googleUrl),
                       let scheme = url.scheme?.lowercased(), ["https", "http", "comgooglemaps"].contains(scheme) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Label("Google Maps", systemImage: "map")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }

                    if let appleUrl = location.appleMapsUrl, let url = URL(string: appleUrl),
                       let scheme = url.scheme?.lowercased(), ["https", "http", "maps"].contains(scheme) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Label("Apple Maps", systemImage: "map.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Payment Complete Banner

    private func paymentCompleteBanner(_ payment: DevicePayment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Payment Complete")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }

            HStack {
                Text("Amount: \(formatCurrency(payment.absoluteAmount))")
                    .font(.subheadline)
                Spacer()
                Text("via \(payment.methodDisplay)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Diagnostic Section

    private var diagnosticSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation {
                    showDiagnostics.toggle()
                }
            } label: {
                HStack {
                    Text("Technical Report")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: showDiagnostics ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }

            if showDiagnostics {
                Group {
                    if horizontalSizeClass == .regular && diagnosticItems.count > 1 {
                        LazyVGrid(columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 8) {
                            ForEach(diagnosticItems, id: \.label) { item in
                                diagnosticRow(item.label, value: item.value)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(diagnosticItems, id: \.label) { item in
                                diagnosticRow(item.label, value: item.value)
                            }
                        }
                    }
                }

                if let conclusion = device.diagnosisConclusion {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Diagnosis")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Text(conclusion)
                            .font(.subheadline)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(12)
        .background(Color.platformGray6)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func diagnosticRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }

    // MARK: - Images Section

    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation {
                    showImages.toggle()
                }
            } label: {
                HStack {
                    Text("Device Photos")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(device.images?.count ?? 0)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Image(systemName: showImages ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }

            if showImages, let images = device.images {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images) { image in
                            AsyncImage(url: URL(string: image.url)) { phase in
                                switch phase {
                                case .empty:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.platformGray5)
                                        .frame(width: 100, height: 100)
                                        .overlay {
                                            ProgressView()
                                        }
                                case .success(let loadedImage):
                                    loadedImage
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                case .failure:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.platformGray5)
                                        .frame(width: 100, height: 100)
                                        .overlay {
                                            Image(systemName: "photo")
                                                .foregroundStyle(.secondary)
                                        }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.platformGray6)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Checklist Section

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation {
                    showChecklist.toggle()
                }
            } label: {
                HStack {
                    Text("Pre-Repair Checklist")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: showChecklist ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }

            if showChecklist, let checklist = device.preRepairChecklist {
                LazyVGrid(
                    columns: horizontalSizeClass == .regular
                        ? [GridItem(.flexible()), GridItem(.flexible())]
                        : [GridItem(.flexible())],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(checklist.results.allItems, id: \.name) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.checklistStatus.icon)
                                .foregroundStyle(item.checklistStatus.color)
                                .font(.caption)

                            Text(item.name)
                                .font(.caption)

                            Spacer()

                            Text(item.checklistStatus.label)
                                .font(.caption)
                                .foregroundStyle(item.checklistStatus.color)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.platformGray6)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Quote Section

    private var quoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(device.isBuyback ? "Offer Details" : "Quote Details")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description)
                                .font(.subheadline)

                            if item.quantity > 1 {
                                Text("Qty: \(item.quantity) x \(formatCurrency(item.unitPrice))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text(formatCurrency(item.lineTotalIncVat))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }

                Divider()

                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(formatCurrency(items.grandTotal))
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
            }
        }
        .padding(12)
        .background(Color.platformGray6)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Reported Issues Section

    private func reportedIssuesSection(_ issues: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Reported Issues")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Text(issues)
                .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.platformGray6)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: amount as NSDecimalNumber) ?? "£\(amount)"
    }

    private func formatDate(_ date: Date) -> String {
        DateFormatters.formatHumanDate(date)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        CustomerDeviceCard(
            device: CustomerDevice(
                id: "1",
                displayName: "Apple iPhone 14 Pro",
                status: "awaiting_authorisation",
                workflowType: .repair,
                customerReportedIssues: "Screen cracked, battery drains fast",
                serialNumber: "FVFXC123456",
                imei: nil,
                visualCheck: "Screen cracked in multiple places",
                electricalCheck: "Battery health at 72%",
                mechanicalCheck: "All buttons functional",
                damageMatchesReported: "Yes, damage consistent with drop",
                diagnosisConclusion: "Screen replacement + battery recommended",
                authorizationStatus: "pending",
                authorizationMethod: nil,
                authorizedAt: nil,
                authIpAddress: nil,
                authUserAgent: nil,
                authSignatureType: nil,
                authSignatureData: nil,
                authorizationReason: nil,
                collectionLocation: nil,
                depositPaid: 50,
                payoutAmount: nil,
                payoutMethod: nil,
                payoutDate: nil,
                paidAt: nil,
                payment: nil,
                images: nil,
                preRepairChecklist: nil
            ),
            items: [],
            currencyCode: "GBP",
            onApprove: {}
        )
        .padding()
    }
}

// MARK: - CustomerDevice Initializer Extension

extension CustomerDevice {
    /// Memberwise initializer for previews/testing
    init(
        id: String,
        displayName: String,
        status: String,
        workflowType: DeviceWorkflowType,
        customerReportedIssues: String?,
        serialNumber: String?,
        imei: String?,
        visualCheck: String?,
        electricalCheck: String?,
        mechanicalCheck: String?,
        damageMatchesReported: String?,
        diagnosisConclusion: String?,
        authorizationStatus: String?,
        authorizationMethod: String?,
        authorizedAt: Date?,
        authIpAddress: String?,
        authUserAgent: String?,
        authSignatureType: String?,
        authSignatureData: String?,
        authorizationReason: String?,
        collectionLocation: CollectionLocation?,
        depositPaid: Decimal?,
        payoutAmount: Decimal?,
        payoutMethod: String?,
        payoutDate: String?,
        paidAt: Date?,
        payment: DevicePayment?,
        images: [DeviceImage]?,
        preRepairChecklist: PreRepairChecklist?
    ) {
        self.id = id
        self.displayName = displayName
        self.status = status
        self.workflowType = workflowType
        self.customerReportedIssues = customerReportedIssues
        self.serialNumber = serialNumber
        self.imei = imei
        self.visualCheck = visualCheck
        self.electricalCheck = electricalCheck
        self.mechanicalCheck = mechanicalCheck
        self.damageMatchesReported = damageMatchesReported
        self.diagnosisConclusion = diagnosisConclusion
        self.authorizationStatus = authorizationStatus
        self.authorizationMethod = authorizationMethod
        self.authorizedAt = authorizedAt
        self.authIpAddress = authIpAddress
        self.authUserAgent = authUserAgent
        self.authSignatureType = authSignatureType
        self.authSignatureData = authSignatureData
        self.authorizationReason = authorizationReason
        self.collectionLocation = collectionLocation
        self.depositPaid = depositPaid
        self.payoutAmount = payoutAmount
        self.payoutMethod = payoutMethod
        self.payoutDate = payoutDate
        self.paidAt = paidAt
        self.payment = payment
        self.images = images
        self.preRepairChecklist = preRepairChecklist
    }
}
