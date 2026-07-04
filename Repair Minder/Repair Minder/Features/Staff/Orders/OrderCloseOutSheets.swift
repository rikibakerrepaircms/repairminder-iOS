//
//  OrderCloseOutSheets.swift
//  Repair Minder
//

import SwiftUI

// 1) Authorize
struct AuthorizeOrderSheet: View {
    let onAuthorize: (AuthorizeOrderRequest) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var type = "phone"
    @State private var targetStatus = "authorised_ready_to_repair"
    @State private var notes = ""
    @State private var busy = false
    @State private var errorText: String?
    var body: some View {
        NavigationStack {
            Form {
                Picker("Authorisation via", selection: $type) {
                    Text("Phone").tag("phone"); Text("Email").tag("email")
                    Text("Portal").tag("portal"); Text("Pre-authorised").tag("pre_authorised")
                }
                Picker("Then", selection: $targetStatus) {
                    Text("Ready to repair").tag("authorised_ready_to_repair")
                    Text("Awaiting parts").tag("authorised_awaiting_parts")
                }
                Section("Notes (optional)") {
                    TextField("Notes", text: $notes, axis: .vertical).accessibilityIdentifier("authorize-notes")
                }
                if let errorText { Text(errorText).foregroundStyle(.red).font(.footnote) }
            }
            .navigationTitle("Authorize order")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Authorize") {
                        Task {
                            busy = true
                            let ok = await onAuthorize(.init(authorisationType: type, targetStatus: targetStatus, authorisationNotes: notes.isEmpty ? nil : notes))
                            busy = false
                            if ok { dismiss() } else { errorText = "Could not authorize. Please try again." }
                        }
                    }.disabled(busy).accessibilityIdentifier("authorize-confirm")
                }
            }
        }
    }
}

// 2) Despatch
struct DespatchOrderSheet: View {
    let onDespatch: (DespatchOrderRequest) async -> Bool
    @Environment(\.dismiss) private var dismiss
    private let carriers = ["Royal Mail","DPD","DHL","UPS","FedEx","Hermes","Yodel","Other"]
    @State private var carrier = "Royal Mail"
    @State private var tracking = ""
    @State private var notify = true
    @State private var busy = false
    @State private var errorText: String?
    var body: some View {
        NavigationStack {
            Form {
                Picker("Carrier", selection: $carrier) { ForEach(carriers, id: \.self) { Text($0).tag($0) } }
                TextField("Tracking number (optional)", text: $tracking).accessibilityIdentifier("despatch-tracking")
                Toggle("Email customer", isOn: $notify)
                if let errorText { Text(errorText).foregroundStyle(.red).font(.footnote) }
            }
            .navigationTitle("Despatch order")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Despatch") {
                        Task {
                            busy = true
                            let ok = await onDespatch(.init(carrier: carrier, trackingNumber: tracking.isEmpty ? nil : tracking, sendNotification: notify))
                            busy = false
                            if ok { dismiss() } else { errorText = "Could not despatch. Please try again." }
                        }
                    }.disabled(busy).accessibilityIdentifier("despatch-confirm")
                }
            }
        }
    }
}

// 3) Collect (embeds the signature inner view)
struct CollectOrderSheet: View {
    let onCollect: (CollectOrderRequest) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var errorText: String?
    var body: some View {
        NavigationStack {
            VStack {
                OrderSignatureSheetInner { signatureData, typedName, agreed in
                    let ok = await onCollect(.init(deviceIds: nil, signatureData: signatureData, typedName: typedName, termsAgreed: agreed))
                    if ok { dismiss() } else { errorText = "Could not record collection." }
                }
                if let errorText { Text(errorText).foregroundStyle(.red).font(.footnote).padding() }
            }
            .navigationTitle("Collect order")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// 4) Refund one payment
struct RefundPaymentSheet: View {
    let payment: OrderPayment
    let onRefund: (CreateRefundRequest) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var reason = ""
    @State private var busy = false
    @State private var errorText: String?
    init(payment: OrderPayment, onRefund: @escaping (CreateRefundRequest) async -> Bool) {
        self.payment = payment; self.onRefund = onRefund
        _amountText = State(initialValue: String(format: "%.2f", payment.refundableAmount ?? payment.amount))
    }
    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Payment", value: CurrencyFormatter.format(payment.amount))
                if let refundable = payment.refundableAmount { LabeledContent("Refundable", value: CurrencyFormatter.format(refundable)) }
                TextField("Refund amount", text: $amountText).accessibilityIdentifier("refund-amount")
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                TextField("Reason (optional)", text: $reason)
                if let errorText { Text(errorText).foregroundStyle(.red).font(.footnote) }
            }
            .navigationTitle("Refund")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Refund") {
                        guard let amount = Double(amountText), amount > 0 else { errorText = "Enter a valid amount."; return }
                        Task {
                            busy = true
                            let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
                            let ok = await onRefund(.init(orderPaymentId: payment.id, amount: amount, refundDate: today, reason: reason.isEmpty ? nil : reason))
                            busy = false
                            if ok { dismiss() } else { errorText = "Refund failed (over-refund or permission)." }
                        }
                    }.disabled(busy).accessibilityIdentifier("refund-confirm")
                }
            }
        }
    }
}

// 5) Add note
struct AddOrderNoteSheet: View {
    let onAdd: (CreateTicketNoteRequest) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var busy = false
    @State private var errorText: String?
    var body: some View {
        NavigationStack {
            Form {
                TextField("Note", text: $text, axis: .vertical).lineLimit(3...8).accessibilityIdentifier("note-body")
                if let errorText { Text(errorText).foregroundStyle(.red).font(.footnote) }
            }
            .navigationTitle("Add note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { busy = true; let ok = await onAdd(.init(body: text, deviceId: nil)); busy = false; if ok { dismiss() } else { errorText = "Could not add note." } }
                    }.disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || busy).accessibilityIdentifier("note-add")
                }
            }
        }
    }
}
