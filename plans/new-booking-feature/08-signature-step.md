# Stage 08: Signature Step

## Objective

Create the terms agreement and signature capture step with a native iOS signature pad.

## Dependencies

`[Requires: Stage 02 complete]` - Needs BookingViewModel and BookingFormData
`[Requires: Stage 04 complete]` - Needs wizard container

## Complexity

**Medium** - Signature pad implementation using PencilKit or custom Canvas.

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Staff/Booking/Steps/SignatureStepView.swift` | Terms and signature capture |
| `Features/Staff/Booking/Components/SignaturePadView.swift` | Canvas for signature drawing |

---

## Implementation Details

### SignatureStepView.swift

```swift
//
//  SignatureStepView.swift
//  Repair Minder
//

import SwiftUI

struct SignatureStepView: View {
    @Bindable var viewModel: BookingViewModel
    @State private var showTermsSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Terms & Signature")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Please review the terms and provide a signature.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Terms Agreement
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    Toggle("", isOn: $viewModel.formData.termsAgreed)
                        .labelsHidden()
                        .tint(.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("I agree to the terms and conditions")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Button {
                            showTermsSheet = true
                        } label: {
                            Text("View terms and conditions")
                                .font(.caption)
                                .foregroundStyle(.accentColor)
                        }
                    }
                }

                // Marketing Consent
                HStack(spacing: 16) {
                    Toggle("", isOn: $viewModel.formData.marketingConsent)
                        .labelsHidden()
                        .tint(.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Receive updates and promotions")
                            .font(.subheadline)

                        Text("We'll send occasional emails about offers and updates")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Divider()

            // Signature Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Signature")
                    .font(.headline)

                Text("Draw your signature below or type your name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Signature Pad
                SignaturePadView(signatureData: $viewModel.formData.signatureData)

                // Typed Name Alternative
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or type your name")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Full name", text: $viewModel.formData.typedName)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Validation Message
            if !viewModel.formData.hasValidSignature {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Please agree to terms and provide a signature or typed name.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showTermsSheet) {
            TermsAndConditionsSheet()
        }
    }
}

// MARK: - Terms Sheet

struct TermsAndConditionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(termsText)
                        .font(.body)
                }
                .padding()
            }
            .navigationTitle("Terms & Conditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var termsText: String {
        """
        REPAIR SERVICE TERMS AND CONDITIONS

        1. ACCEPTANCE OF DEVICES
        By signing this agreement, you confirm that you are the owner or authorized representative of the device(s) being submitted for service.

        2. DIAGNOSTIC AND REPAIR SERVICES
        We will diagnose and repair your device to the best of our ability. If additional work is required beyond the initial estimate, we will contact you for approval before proceeding.

        3. DATA AND PRIVACY
        We recommend backing up your data before submitting your device. While we take every precaution, we are not responsible for data loss during the repair process.

        4. WARRANTIES
        Repairs are covered by a warranty as specified at the time of service. This warranty does not cover physical damage, water damage, or modifications made after the repair.

        5. UNCOLLECTED DEVICES
        Devices not collected within 90 days of completion notice may be disposed of or recycled. We will attempt to contact you before taking this action.

        6. LIABILITY
        Our liability is limited to the cost of the repair service. We are not liable for any indirect, incidental, or consequential damages.

        7. FIND MY / ACTIVATION LOCK
        You must disable Find My iPhone/iPad/Mac before submitting your device. We cannot work on devices with activation lock enabled.

        8. PAYMENT
        Payment is due upon collection unless otherwise agreed. We accept cash, card, and bank transfer.

        By signing, you acknowledge that you have read and agree to these terms.
        """
    }
}

#Preview {
    ScrollView {
        SignatureStepView(viewModel: BookingViewModel())
            .padding()
    }
}
```

### SignaturePadView.swift

```swift
//
//  SignaturePadView.swift
//  Repair Minder
//

import SwiftUI
import PencilKit

struct SignaturePadView: View {
    @Binding var signatureData: Data?
    @State private var canvasView = PKCanvasView()
    @State private var hasDrawing = false

    var body: some View {
        VStack(spacing: 12) {
            // Canvas
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)

                // Signature line
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                }

                // Canvas wrapper
                SignatureCanvasRepresentable(
                    canvasView: $canvasView,
                    onDrawingChanged: { hasContent in
                        hasDrawing = hasContent
                        if hasContent {
                            saveSignature()
                        } else {
                            signatureData = nil
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Placeholder
                if !hasDrawing {
                    Text("Sign here")
                        .font(.title3)
                        .foregroundStyle(.secondary.opacity(0.5))
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 200)

            // Clear Button
            HStack {
                Spacer()

                Button {
                    clearSignature()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
                .disabled(!hasDrawing)
                .opacity(hasDrawing ? 1 : 0.5)
            }
        }
    }

    private func saveSignature() {
        // Get the drawing as an image
        let image = canvasView.drawing.image(
            from: canvasView.bounds,
            scale: UIScreen.main.scale
        )

        // Convert to PNG data
        signatureData = image.pngData()
    }

    private func clearSignature() {
        canvasView.drawing = PKDrawing()
        hasDrawing = false
        signatureData = nil
    }
}

// MARK: - Canvas UIViewRepresentable

struct SignatureCanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let onDrawingChanged: (Bool) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false

        // Configure for finger drawing (works without Apple Pencil)
        canvasView.drawingPolicy = .anyInput

        // Set up ink tool (black pen)
        let ink = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.tool = ink

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        let onDrawingChanged: (Bool) -> Void

        init(onDrawingChanged: @escaping (Bool) -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let hasContent = !canvasView.drawing.bounds.isEmpty
            onDrawingChanged(hasContent)
        }
    }
}

// MARK: - Simple Fallback (if PencilKit unavailable)

struct SimpleSignatureCanvas: View {
    @Binding var signatureData: Data?
    @State private var lines: [[CGPoint]] = []
    @State private var currentLine: [CGPoint] = []

    var body: some View {
        Canvas { context, size in
            for line in lines {
                var path = Path()
                if let first = line.first {
                    path.move(to: first)
                    for point in line.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                context.stroke(path, with: .color(.black), lineWidth: 3)
            }

            // Current line
            var currentPath = Path()
            if let first = currentLine.first {
                currentPath.move(to: first)
                for point in currentLine.dropFirst() {
                    currentPath.addLine(to: point)
                }
            }
            context.stroke(currentPath, with: .color(.black), lineWidth: 3)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    currentLine.append(value.location)
                }
                .onEnded { _ in
                    lines.append(currentLine)
                    currentLine = []
                    saveAsImage()
                }
        )
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func saveAsImage() {
        // Simplified - in production use a proper renderer
        // This is a fallback if PencilKit doesn't work
    }
}

#Preview {
    VStack {
        SignaturePadView(signatureData: .constant(nil))
            .padding()
    }
}
```

---

## Database Changes

**None**

---

## Test Cases

### Test 1: Terms Toggle
- Toggle is off by default
- Can toggle on/off
- "View terms" opens sheet

### Test 2: Marketing Toggle
- Toggle is on by default
- Can toggle on/off

### Test 3: Signature Drawing
- Can draw on canvas with finger
- Drawing appears as black ink
- "Sign here" placeholder disappears when drawing

### Test 4: Clear Signature
- Clear button removes drawing
- Placeholder reappears
- signatureData becomes nil

### Test 5: Typed Name
- Can type name as alternative
- Updates formData.typedName

### Test 6: Validation
- Step invalid when: termsAgreed is false
- Step invalid when: no signature AND no typed name
- Step valid when: termsAgreed AND (signature OR typed name)

### Test 7: Signature Export
- Drawing exported as PNG data
- Data stored in formData.signatureData

---

## Acceptance Checklist

- [ ] `SignatureStepView.swift` created
- [ ] `SignaturePadView.swift` created
- [ ] Terms agreement toggle works
- [ ] Marketing consent toggle works
- [ ] "View terms" sheet displays
- [ ] Signature canvas accepts finger drawing
- [ ] Drawing exported as PNG data
- [ ] Clear button works
- [ ] Typed name alternative works
- [ ] Validation message shows when incomplete
- [ ] Step validation correct
- [ ] Previews render without error
- [ ] Project compiles without errors

---

## Deployment

```bash
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

---

## Handoff Notes

- Uses PencilKit for native signature experience
- Works with finger (no Apple Pencil required)
- Signature stored as PNG Data in formData.signatureData
- Typed name is an alternative to drawing
- [See: Stage 09] Confirmation shows after successful submit
- Submit happens when user taps "Complete Booking" on this step
