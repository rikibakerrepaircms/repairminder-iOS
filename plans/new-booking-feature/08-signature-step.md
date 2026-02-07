# Stage 08: Signature Step

## Objective

Create the terms agreement and signature capture step, reusing the existing `CustomerSignatureView` component.

## Dependencies

`[Requires: Stage 02 complete]` - Needs BookingViewModel and BookingFormData
`[Requires: Stage 04 complete]` - Needs wizard container

## Complexity

**Medium** - Integrating existing signature component, API-fetched terms.

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Staff/Booking/Steps/SignatureStepView.swift` | Terms and signature capture |

> **Note:** No `SignaturePadView` needed — reuse existing `CustomerSignatureView` from `Features/Customer/Components/CustomerSignatureView.swift`. It already supports drawn (Canvas + DragGesture) and typed signatures, outputs `"data:image/png;base64,..."` strings, and has a clear button.

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

                        Text("Receive occasional emails about offers from \(viewModel.companyName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Divider()

            // Signature Section — reuses existing CustomerSignatureView
            VStack(alignment: .leading, spacing: 16) {
                Text("Signature")
                    .font(.headline)

                Text("Draw your signature below or type your name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // CustomerSignatureView requires 3 bindings:
                // 1. signatureType — .typed or .drawn (stored in formData)
                // 2. typedName — text input for typed signatures (stored in formData)
                // 3. drawnSignature — UIImage? from canvas (stored in formData)
                // The computed formData.signatureData property returns:
                //   - Drawn: "data:image/png;base64,..." string
                //   - Typed: nil (typed name is sent separately via typedName field)
                CustomerSignatureView(
                    signatureType: $viewModel.formData.signatureType,
                    typedName: $viewModel.formData.typedName,
                    drawnSignature: $viewModel.formData.drawnSignature
                )
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
            TermsAndConditionsSheet(termsContent: viewModel.termsContent)
        }
        .task {
            if viewModel.termsContent.isEmpty {
                await viewModel.loadTermsAndConditions()
            }
        }
    }
}

// MARK: - Terms Sheet

struct TermsAndConditionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let termsContent: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if termsContent.isEmpty {
                        ProgressView("Loading terms...")
                    } else {
                        Text(termsContent)
                            .font(.body)
                    }
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
}

#Preview {
    ScrollView {
        SignatureStepView(viewModel: BookingViewModel())
            .padding()
    }
}
```

---

## Key Design Decisions

### Reuse CustomerSignatureView
The existing `CustomerSignatureView` (in `Features/Customer/Components/`) already implements:
- **Drawn signatures** via SwiftUI Canvas + DragGesture
- **Typed signatures** via text field with cursive preview
- **Clear button** to reset paths and nil out `drawnSignature`
- **`signatureData` computed property** returning typed name or `"data:image/png;base64,..."` string
- **`isValid` property** for validation
- **Nested `SignatureType` enum** (`.typed`, `.drawn`) — accessed as `CustomerSignatureView.SignatureType`

**Required bindings (3):**
1. `signatureType: Binding<CustomerSignatureView.SignatureType>` — toggles typed vs drawn
2. `typedName: Binding<String>` — text input for typed signatures
3. `drawnSignature: Binding<UIImage?>` — canvas output image

The `BookingFormData` stores all three as properties, and the computed `signatureData` property converts them to the string format the backend expects.

No need to create a separate `SignaturePadView` or bring in PencilKit. Just embed `CustomerSignatureView` in this step.

### API-Fetched Terms
Terms and conditions are fetched from the backend via `GET /api/company/public-info` (which returns `{ name, terms_conditions }`). The `BookingViewModel.loadTermsAndConditions()` method fetches this and stores it in `viewModel.termsContent`. The `TermsAndConditionsSheet` displays the fetched content — no hardcoded T&Cs.

### Signature Data Format
`formData.signatureData` is a **computed** `String?` property (not stored directly). It derives the value from the CustomerSignatureView bindings:
- **Typed:** returns `nil` (typed name is sent separately via the `typedName` field in the signature payload)
- **Drawn:** converts `drawnSignature: UIImage?` to `"data:image/png;base64,..."` string, or `nil` if no drawing

This matches what the backend expects in the `POST /api/orders` signature payload: `signature_data` for drawn signatures, `typed_name` for typed signatures (the backend requires one or the other). The submit method sends `signatureData` only for drawn mode and `typedName` only for typed mode.

---

## Database Changes

**None**

---

## Test Cases

### Test 1: Terms Toggle
- Toggle is off by default
- Can toggle on/off
- "View terms" opens sheet

### Test 2: Terms Content Loaded from API
- Terms sheet shows loading indicator initially
- After API response, shows fetched terms text
- NOT hardcoded — content comes from company settings

### Test 3: Marketing Toggle
- Toggle is on by default
- Shows company name from API
- Can toggle on/off

### Test 4: Signature Drawing
- Can draw on canvas with finger
- Drawing appears as black ink
- "Sign here" placeholder disappears when drawing

### Test 5: Clear Signature
- Clear button removes drawing
- Placeholder reappears
- signatureData becomes nil

### Test 6: Typed Name
- Can type name as alternative
- Updates formData.typedName

### Test 7: Validation
- Step invalid when: termsAgreed is false
- Step invalid when: no signature AND no typed name
- Step valid when: termsAgreed AND (signature OR typed name)

### Test 8: Signature Export Format
- Signature exported as base64 data URL string (`"data:image/png;base64,..."`)
- Stored in `formData.signatureData` as `String?`

---

## Acceptance Checklist

- [ ] `SignatureStepView.swift` created
- [ ] Reuses existing `CustomerSignatureView` (no new `SignaturePadView`)
- [ ] Terms agreement toggle works
- [ ] Marketing consent toggle shows company name
- [ ] "View terms" sheet displays API-fetched content
- [ ] Signature canvas accepts finger drawing
- [ ] Signature exported as base64 data URL string
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

- Reuses `CustomerSignatureView` from `Features/Customer/Components/CustomerSignatureView.swift`
- **3 bindings required:** `signatureType`, `typedName`, `drawnSignature` — all stored in `formData`
- `formData.signatureData` is a **computed** `String?` property (converts bindings to backend format)
- Terms fetched from `GET /api/company/public-info` (requires auth) via `viewModel.loadTermsAndConditions()`
- Company name shown in marketing consent text via `viewModel.companyName`
- `formData.signatureType` is `CustomerSignatureView.SignatureType` (`.typed` or `.drawn`)
- [See: Stage 09] Confirmation shows after successful submit
- Submit happens when user taps "Complete Booking" on this step
