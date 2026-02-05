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

    @State private var currentPath: Path = Path()
    @State private var paths: [Path] = []

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
                drawnSignatureCanvas
            }
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

    // MARK: - Drawn Signature Canvas

    private var drawnSignatureCanvas: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Draw your signature below")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Clear") {
                    paths.removeAll()
                    currentPath = Path()
                    drawnSignature = nil
                }
                .font(.caption)
                .disabled(paths.isEmpty)
            }

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))

                // Signature line
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.top, 100)

                // Drawn paths
                Canvas { context, size in
                    for path in paths {
                        context.stroke(path, with: .color(.primary), lineWidth: 2)
                    }
                    context.stroke(currentPath, with: .color(.primary), lineWidth: 2)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let point = value.location
                            if value.translation == .zero {
                                currentPath.move(to: point)
                            } else {
                                currentPath.addLine(to: point)
                            }
                        }
                        .onEnded { _ in
                            paths.append(currentPath)
                            currentPath = Path()
                            captureSignatureImage()
                        }
                )

                // Placeholder text
                if paths.isEmpty {
                    Text("Sign here")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Signature Capture

    private func captureSignatureImage() {
        let renderer = ImageRenderer(content: signatureCanvasContent)
        renderer.scale = 3.0
        drawnSignature = renderer.uiImage
    }

    private var signatureCanvasContent: some View {
        Canvas { context, size in
            for path in paths {
                context.stroke(path, with: .color(.black), lineWidth: 2)
            }
        }
        .frame(width: 300, height: 150)
        .background(.white)
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
