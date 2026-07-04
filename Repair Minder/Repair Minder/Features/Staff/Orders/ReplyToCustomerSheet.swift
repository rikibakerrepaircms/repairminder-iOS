//
//  ReplyToCustomerSheet.swift
//  Repair Minder
//

import SwiftUI

/// Sheet for sending a reply to the customer on an order's associated ticket.
/// Posts to `POST /api/tickets/:id/reply` via `OrderDetailViewModel.replyToCustomer`.
struct ReplyToCustomerSheet: View {
    /// Whether SMS is available to offer as an additional send channel for this ticket's client.
    let smsAvailable: Bool
    let onSend: (_ plainText: String, _ sendSms: Bool) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var sendSms = false
    @State private var busy = false
    @State private var errorText: String?

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Message") {
                    TextField("Type your reply...", text: $text, axis: .vertical)
                        .lineLimit(5...12)
                        .accessibilityIdentifier("reply-body")
                }

                if smsAvailable {
                    Section {
                        Toggle("Send SMS too", isOn: $sendSms)
                            .accessibilityIdentifier("reply-send-sms")
                    }
                }

                if let errorText {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .navigationTitle("Reply to customer")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { errorText = nil; dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task {
                            busy = true
                            let err = await onSend(trimmedText, sendSms)
                            busy = false
                            if err == nil {
                                dismiss()
                            } else {
                                errorText = err
                            }
                        }
                    }
                    .disabled(trimmedText.isEmpty || busy)
                    .accessibilityIdentifier("reply-send")
                }
            }
        }
    }
}
