//
//  OrderSignatureSheet.swift
//  Repair Minder
//

import SwiftUI

/// Reusable signature-capture content for order close-out flows.
///
/// Wraps the existing cross-platform `CustomerSignatureView` (typed name or
/// drawn signature) plus a terms-agreement toggle. This is the
/// NavigationStack-free variant meant to be embedded inside a larger flow
/// (e.g. a future "Collect order" sheet with multiple steps).
///
/// `CustomerSignatureView.signatureData` returns a single combined string:
/// the trimmed typed name when `.typed`, or a `data:image/png;base64,...`
/// string when `.drawn`. Rather than forwarding that ambiguous combined
/// string, this view disambiguates it into the two output parameters the
/// caller receives via `onConfirm`:
///   - `signatureData`: the base64 PNG data URI, only when a signature was
///     drawn (`nil` otherwise).
///   - `typedName`: the trimmed typed name, only when the name was typed
///     (`nil` otherwise).
/// The two are therefore mutually exclusive — at most one is non-nil.
struct OrderSignatureSheetInner: View {
    /// Called with (signatureData base64 data URI or nil, typedName or nil, termsAgreed).
    let onConfirm: (String?, String?, Bool) async -> Void

    @State private var signatureType: CustomerSignatureView.SignatureType = .typed
    @State private var typedName: String = ""
    @State private var drawnSignature: PlatformImage?
    @State private var termsAgreed: Bool = false
    @State private var isSubmitting: Bool = false

    /// Whether a valid signature (drawn) or non-empty typed name has been provided.
    private var hasValidSignature: Bool {
        switch signatureType {
        case .typed:
            return !typedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .drawn:
            return drawnSignature != nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CustomerSignatureView(
                    signatureType: $signatureType,
                    typedName: $typedName,
                    drawnSignature: $drawnSignature
                )

                Toggle("Customer agrees to terms", isOn: $termsAgreed)
                    .accessibilityIdentifier("signature-terms-toggle")

                Button {
                    Task {
                        isSubmitting = true
                        let (signatureData, typedNameOut) = outboundSignaturePayload()
                        await onConfirm(signatureData, typedNameOut, termsAgreed)
                        isSubmitting = false
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Confirm")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasValidSignature || isSubmitting)
                .accessibilityIdentifier("signature-confirm")
            }
            .padding()
        }
    }

    /// Splits the current signature state into the (signatureData, typedName) pair
    /// described above — mutually exclusive depending on `signatureType`.
    private func outboundSignaturePayload() -> (String?, String?) {
        switch signatureType {
        case .drawn:
            guard let image = drawnSignature, let data = image.pngData() else {
                return (nil, nil)
            }
            return ("data:image/png;base64," + data.base64EncodedString(), nil)
        case .typed:
            let trimmed = typedName.trimmingCharacters(in: .whitespacesAndNewlines)
            return (nil, trimmed.isEmpty ? nil : trimmed)
        }
    }
}

/// Thin `NavigationStack` wrapper around `OrderSignatureSheetInner` for presenting
/// signature capture as a standalone sheet.
struct OrderSignatureSheet: View {
    let title: String
    let onConfirm: (String?, String?, Bool) async -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            OrderSignatureSheetInner(onConfirm: onConfirm)
                .navigationTitle(title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview {
    OrderSignatureSheet(title: "Sign Order") { signatureData, typedName, termsAgreed in
        print("signatureData: \(signatureData ?? "nil")")
        print("typedName: \(typedName ?? "nil")")
        print("termsAgreed: \(termsAgreed)")
    }
}
