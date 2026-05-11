//
//  MailInShippingBanner.swift
//  Repair Minder
//
//  Customer-portal banner for mail-in orders awaiting their first device.
//  Mirrors the web banner content + always-visible prep checklist so the
//  customer sees the same advice whether they're reading the order page
//  or the mail-in instructions email.
//

import SwiftUI

struct MailInShippingBanner: View {
    let order: CustomerOrderDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 44, height: 44)
                    Image(systemName: "shippingbox.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Send us your device")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("We're ready to receive your device. Please post it to the address below and include your order number on or inside the package.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Send-to address card
            if let company = order.company {
                addressCard(company)
            }

            // Order reference card
            referenceCard

            // Prep checklist
            prepInstructions
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.10), Color.yellow.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func addressCard(_ company: CustomerCompanyInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SEND TO")
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(0.5)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                if let name = company.locationName, !name.isEmpty {
                    Text(name).fontWeight(.semibold)
                }
                if let line1 = company.addressLine1, !line1.isEmpty {
                    Text(line1)
                }
                if let line2 = company.addressLine2, !line2.isEmpty {
                    Text(line2)
                }
                let cityCounty = [company.city, company.county]
                    .compactMap { $0?.isEmpty == false ? $0 : nil }
                    .joined(separator: ", ")
                if !cityCounty.isEmpty {
                    Text(cityCounty)
                }
                if let postcode = company.postcode, !postcode.isEmpty {
                    Text(Self.formatPostcode(postcode))
                }
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var referenceCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("QUOTE YOUR REFERENCE")
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(order.orderReference)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var prepInstructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            instructionGroup(
                title: "Before you send — prepare your device",
                bullets: [
                    "Back up any data you want to keep — please do this before sending.",
                    "Disable device locks: Find My iPhone / iCloud, or your Google / Samsung account.",
                    "Either remove your passcode, factory reset, or include your passcode with the package — we need to test the device after repair.",
                    "Don't include your SIM card, memory card or accessories (charger, case, cables). We can't guarantee they'll be returned."
                ]
            )
            instructionGroup(
                title: "Packaging",
                bullets: [
                    "Pack the device safely and discreetly.",
                    "Use a fully tracked, recorded and insured postal service — loss or damage in transit is between you and the courier.",
                    "Add a \"From\" address on the outside of the package.",
                    "Include your order number inside the package, especially if the device won't power on."
                ]
            )
            VStack(alignment: .leading, spacing: 6) {
                Text("After we receive it")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("We'll email you once your device is booked in. If you haven't heard from us within 2 working days of delivery, please get in touch.")
                    .font(.footnote)
            }

            // Pre-paid label CTA — matches the web banner.
            VStack(alignment: .leading, spacing: 4) {
                Text("Need a pre-paid label and/or packaging?")
                    .font(.footnote)
                    .fontWeight(.semibold)
                Text("Just reply to your order confirmation email and let us know.")
                    .font(.footnote)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func instructionGroup(title: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(bullets, id: \.self) { line in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(.secondary)
                        Text(line).font(.footnote)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Insert the space before the inward code if missing (e.g. "CB99DZ"
    /// → "CB9 9DZ"). Matches the web's formatPostcode helper, so a tenant
    /// whose stored postcode has no space still renders correctly.
    private static func formatPostcode(_ pc: String) -> String {
        let trimmed = pc.trimmingCharacters(in: .whitespaces).uppercased()
        if trimmed.contains(" ") || trimmed.count < 5 { return trimmed }
        let inward = trimmed.suffix(3)
        let outward = trimmed.prefix(trimmed.count - 3)
        return "\(outward) \(inward)"
    }
}
