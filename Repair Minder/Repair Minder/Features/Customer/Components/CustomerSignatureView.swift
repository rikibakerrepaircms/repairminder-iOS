//
//  CustomerSignatureView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// Signature capture view supporting typed and drawn signatures
struct CustomerSignatureView: View {
    @Binding var signatureType: SignatureType
    @Binding var typedName: String
    @Binding var drawnSignature: UIImage?

    @State private var showFullscreenCanvas = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    enum SignatureType: String, CaseIterable {
        case typed = "typed"
        case drawn = "drawn"

        var label: String {
            switch self {
            case .typed: return "Type Name"
            case .drawn: return "Draw Signature"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Signature type picker
            Picker("Signature Type", selection: $signatureType) {
                ForEach(SignatureType.allCases, id: \.self) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Signature input
            switch signatureType {
            case .typed:
                typedSignatureInput
            case .drawn:
                drawnSignaturePreview
            }
        }
        .fullScreenCover(isPresented: $showFullscreenCanvas) {
            FullscreenSignatureView(drawnSignature: $drawnSignature)
        }
    }

    // MARK: - Typed Signature

    private var typedSignatureInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type your full name below to sign")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Full Name", text: $typedName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            if !typedName.isEmpty {
                // Preview of typed signature
                Text(typedName)
                    .font(.custom("Snell Roundhand", size: 32))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Drawn Signature (Preview / Tap to Expand)

    private var drawnSignaturePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(drawnSignature == nil ? "Tap below to sign" : "Tap to re-sign")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if drawnSignature != nil {
                    Button {
                        drawnSignature = nil
                    } label: {
                        Text("Clear")
                            .font(.caption)
                    }
                }
            }

            Button {
                showFullscreenCanvas = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))

                    if let image = drawnSignature {
                        // Show captured signature as preview
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                    } else {
                        // Placeholder
                        VStack(spacing: 8) {
                            Image(systemName: "pencil.and.scribble")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("Tap to open signature pad")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: horizontalSizeClass == .regular ? 250 : 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Validation

    /// Whether a valid signature has been provided
    var isValid: Bool {
        switch signatureType {
        case .typed:
            return !typedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .drawn:
            return drawnSignature != nil
        }
    }

    /// Get signature data as string (typed name or base64 image)
    var signatureData: String {
        switch signatureType {
        case .typed:
            return typedName.trimmingCharacters(in: .whitespacesAndNewlines)
        case .drawn:
            if let image = drawnSignature,
               let data = image.pngData() {
                return "data:image/png;base64," + data.base64EncodedString()
            }
            return ""
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State var signatureType: CustomerSignatureView.SignatureType = .typed
        @State var typedName: String = ""
        @State var drawnSignature: UIImage? = nil

        var body: some View {
            CustomerSignatureView(
                signatureType: $signatureType,
                typedName: $typedName,
                drawnSignature: $drawnSignature
            )
            .padding()
        }
    }

    return PreviewWrapper()
}
