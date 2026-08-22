//
//  SellerIdCheckSheet.swift
//  Repair Minder
//
//  Recording the seller identity check for a buyback purchase, from the counter.
//
//  WHY IT IS HERE AND NOT ONLY ON THE WEB. Adding a device to buyback inventory
//  is now blocked unless a PASSING check exists (migration 0505), and this app
//  has an "Add to buyback" button. Without this sheet that button would fail
//  with an error staff could not resolve on the device in their hand, which is
//  precisely the shape of problem the cross-project sync rule exists to prevent.
//
//  DESIGNED FOR A COUNTER. Someone is standing in front of the person filling
//  this in, so the defaults are the common case — a UK seller with a photocard
//  licence, seen in person — the address is pre-filled from the client record
//  rather than retyped, and every validation problem comes back at once.
//
//  It collects no document number. See BuybackIdCheckModels.swift.
//
//  Web twin: src/components/buyback/SellerIdCheckPanel.tsx.
//

import SwiftUI

struct SellerIdCheckSheet: View {

    let orderId: String
    /// Called after a successful record so the caller can refresh anything gated
    /// on the check, e.g. whether "Add to buyback" will now succeed.
    var onRecorded: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var loading = true
    @State private var saving = false
    @State private var existing: BuybackIdCheck?
    @State private var clientName: String?
    @State private var clientAddress: String?
    @State private var errors: [String] = []

    // The defaults ARE the common case.
    @State private var photoIdType: PhotoIdType = .drivingLicence
    @State private var proofType: ProofOfAddressType?
    @State private var proofDated = Date()
    @State private var method: IdCheckMethod = .inPerson
    @State private var attachmentId = ""
    @State private var nameMatches = false
    @State private var addressMatches = false
    @State private var addressVerified = ""
    @State private var notes = ""

    private let service = BuybackService()

    /// yyyy-MM-dd, the only shape the API accepts. Fixed locale and timezone so a
    /// device set to a non-Gregorian calendar or a westerly timezone cannot send a
    /// date that reads as the day before.
    private static let wireDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView()
                } else {
                    form
                }
            }
            .navigationTitle("Seller ID check")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record") { Task { await save() } }
                        .disabled(saving || loading)
                }
            }
            .task { await load() }
        }
    }

    private var form: some View {
        Form {
            if let existing {
                Section {
                    Label(
                        existing.passes
                            ? "Checked - name and address both matched"
                            : "Checked - DID NOT pass",
                        systemImage: existing.passes ? "checkmark.seal" : "exclamationmark.triangle"
                    )
                    .foregroundStyle(existing.passes ? .green : .red)

                    LabeledContent("Documents") {
                        Text([existing.photoIdLabel, existing.proofOfAddressLabel]
                            .compactMap { $0 }
                            .joined(separator: " + "))
                    }
                    LabeledContent("How") { Text(existing.methodLabel) }
                    if let who = existing.checkedByName {
                        LabeledContent("Checked by") { Text(who) }
                    }
                } header: {
                    Text("Already recorded")
                } footer: {
                    Text("Recording again replaces this. The order's notes keep the history.")
                }
            }

            if let clientName {
                Section {
                    Text("Checking documents for \(clientName).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("What you saw") {
                Picker("Photo ID", selection: $photoIdType) {
                    ForEach(PhotoIdType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }

                Picker("Proof of address", selection: $proofType) {
                    Text(photoIdType.carriesAddress
                         ? "Not needed - the licence shows it"
                         : "None").tag(ProofOfAddressType?.none)
                    ForEach(ProofOfAddressType.allCases) { type in
                        Text(type.label).tag(ProofOfAddressType?.some(type))
                    }
                }

                // A passport carries no address, so it cannot settle the address side
                // on its own. Saying so here beats a server rejection after the fact.
                if proofType == nil && !photoIdType.carriesAddress {
                    Text("A \(photoIdType.label.lowercased()) does not show an address, so a separate proof of address is needed.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                if proofType != nil {
                    DatePicker(
                        "Date on the proof",
                        selection: $proofDated,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    Text("We tell sellers it must be dated within the last three months.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("How you saw them") {
                Picker("Method", selection: $method) {
                    ForEach(IdCheckMethod.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()

                if method == .imageSupplied {
                    TextField("Attachment id of the image", text: $attachmentId)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                    Text("Recording which attachment holds the document is what lets it be found and deleted later.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                TextField("Address as verified", text: $addressVerified, axis: .vertical)
                    .lineLimit(2...4)
                if let clientAddress, addressVerified != clientAddress {
                    Text("This differs from the address on the client record. Update the client too, or the purchase invoice will carry the old one.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("The address going on the purchase invoice")
            }

            Section("The finding") {
                Toggle("The name on the ID matches the seller", isOn: $nameMatches)
                Toggle("The address matches the one above", isOn: $addressMatches)
            }

            Section {
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            } footer: {
                Text("Do not record document numbers.")
            }

            if !errors.isEmpty {
                Section {
                    ForEach(errors, id: \.self) { message in
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let response = try await service.idCheck(orderId: orderId)
            existing = response.idCheck
            clientName = response.clientName
            clientAddress = response.clientAddress
            if let check = response.idCheck {
                photoIdType = PhotoIdType(rawValue: check.photoIdType) ?? .drivingLicence
                proofType = check.proofOfAddressType.flatMap { ProofOfAddressType(rawValue: $0) }
                if let dated = check.proofOfAddressDated,
                   let parsed = Self.wireDateFormatter.date(from: dated) {
                    proofDated = parsed
                }
                method = IdCheckMethod(rawValue: check.method) ?? .inPerson
                nameMatches = check.nameMatches
                addressMatches = check.addressMatches
                addressVerified = check.addressVerified ?? ""
                notes = check.notes ?? ""
            } else {
                // Pre-fill from the client record. This is the line the self-billed
                // purchase invoice will carry, so showing it at the moment of the check
                // is where a wrong one gets caught.
                addressVerified = response.clientAddress ?? ""
            }
        } catch {
            errors = ["Could not load the seller ID check."]
        }
    }

    private func save() async {
        saving = true
        errors = []
        defer { saving = false }

        let request = RecordBuybackIdCheckRequest(
            photoIdType: photoIdType.rawValue,
            proofOfAddressType: proofType?.rawValue,
            // Only ever sent alongside a document. A date with no document is a date
            // for nothing, and the server rejects the pair anyway.
            proofOfAddressDated: proofType == nil ? nil : Self.wireDateFormatter.string(from: proofDated),
            method: method.rawValue,
            // Never sent for an in-person check: the whole point is that we looked and
            // kept nothing.
            idAttachmentId: method == .imageSupplied
                ? (attachmentId.isEmpty ? nil : attachmentId)
                : nil,
            nameMatches: nameMatches,
            addressMatches: addressMatches,
            addressVerified: addressVerified.isEmpty ? nil : addressVerified,
            notes: notes.isEmpty ? nil : notes
        )

        do {
            _ = try await service.recordIdCheck(orderId: orderId, request: request)
            onRecorded?()
            dismiss()
        } catch {
            // The API returns every fault at once in validation_errors, and APIClient
            // surfaces the server's `error` string through localizedDescription. Show
            // it rather than a generic failure - someone has a customer in front of
            // them, and "record the check" with no reason is not actionable.
            errors = [error.localizedDescription]
        }
    }
}
