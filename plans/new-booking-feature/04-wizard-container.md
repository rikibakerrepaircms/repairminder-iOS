# Stage 04: Wizard Container (BookingWizardView)

## Objective

Create the main wizard container with step progress indicator and navigation controls.

## Dependencies

`[Requires: Stage 02 complete]` - Needs BookingViewModel
`[Requires: Stage 03 complete]` - Needs ServiceType enum

## Complexity

**Medium** - Step navigation logic and progress UI.

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Staff/Booking/BookingWizardView.swift` | Main wizard container with step navigation |
| `Features/Staff/Booking/Components/StepProgressView.swift` | Progress indicator showing current step |

---

## Implementation Details

### BookingWizardView.swift

```swift
//
//  BookingWizardView.swift
//  Repair Minder
//

import SwiftUI

struct BookingWizardView: View {
    let serviceType: ServiceType

    @State private var viewModel: BookingViewModel
    @Environment(\.dismiss) private var dismiss

    init(serviceType: ServiceType) {
        self.serviceType = serviceType
        self._viewModel = State(initialValue: BookingViewModel(serviceType: serviceType))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress Steps (hide on confirmation)
            if viewModel.currentStep != .confirmation {
                StepProgressView(
                    currentStep: viewModel.currentStep,
                    onStepTap: { step in
                        viewModel.goToStep(step)
                    }
                )
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }

            Divider()

            // Step Content
            ScrollView {
                stepContent
                    .padding()
            }

            // Footer Navigation (hide on confirmation)
            if viewModel.currentStep != .confirmation {
                Divider()
                footerNavigation
            }
        }
        .navigationTitle("New Booking")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.currentStep != .client)
        .toolbar {
            if viewModel.currentStep != .confirmation {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
        .alert("Error", isPresented: .constant(viewModel.submitError != nil)) {
            Button("OK") {
                viewModel.submitError = nil
            }
        } message: {
            if let error = viewModel.submitError {
                Text(error)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .client:
            ClientStepView(viewModel: viewModel)
        case .devices:
            DevicesStepView(viewModel: viewModel)
        case .summary:
            SummaryStepView(viewModel: viewModel)
        case .signature:
            SignatureStepView(viewModel: viewModel)
        case .confirmation:
            ConfirmationStepView(viewModel: viewModel) {
                dismiss()
            }
        }
    }

    private var footerNavigation: some View {
        HStack {
            // Back Button
            Button {
                if viewModel.canGoBack {
                    viewModel.goBack()
                } else {
                    dismiss()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            .disabled(viewModel.isSubmitting)

            Spacer()

            // Next/Submit Button
            if viewModel.currentStep == .signature {
                Button {
                    Task {
                        await viewModel.submit()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(viewModel.isSubmitting ? "Creating..." : "Complete Booking")
                        if !viewModel.isSubmitting {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(viewModel.isCurrentStepValid ? Color.accentColor : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!viewModel.isCurrentStepValid || viewModel.isSubmitting)
            } else {
                Button {
                    viewModel.goNext()
                } label: {
                    HStack(spacing: 4) {
                        Text("Continue")
                        Image(systemName: "chevron.right")
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(viewModel.isCurrentStepValid ? Color.accentColor : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!viewModel.isCurrentStepValid)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    NavigationStack {
        BookingWizardView(serviceType: .repair)
    }
}
```

### StepProgressView.swift

```swift
//
//  StepProgressView.swift
//  Repair Minder
//

import SwiftUI

struct StepProgressView: View {
    let currentStep: BookingStep
    let onStepTap: (BookingStep) -> Void

    // Only show first 4 steps (exclude confirmation)
    private var visibleSteps: [BookingStep] {
        BookingStep.allCases.filter { $0 != .confirmation }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(visibleSteps.enumerated()), id: \.element.id) { index, step in
                stepItem(step: step, index: index)

                if index < visibleSteps.count - 1 {
                    stepConnector(isCompleted: step.rawValue < currentStep.rawValue)
                }
            }
        }
    }

    @ViewBuilder
    private func stepItem(step: BookingStep, index: Int) -> some View {
        let isCompleted = step.rawValue < currentStep.rawValue
        let isCurrent = step == currentStep
        let isAccessible = step.rawValue <= currentStep.rawValue

        Button {
            if isAccessible {
                onStepTap(step)
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(stepBackgroundColor(isCompleted: isCompleted, isCurrent: isCurrent))
                        .frame(width: 32, height: 32)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    } else {
                        Text("\(step.number)")
                            .font(.caption.bold())
                            .foregroundStyle(isCurrent ? .white : .secondary)
                    }
                }

                Text(step.title)
                    .font(.caption2)
                    .foregroundStyle(isCurrent ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isAccessible)
    }

    @ViewBuilder
    private func stepConnector(isCompleted: Bool) -> some View {
        Rectangle()
            .fill(isCompleted ? Color.accentColor : Color(.systemGray4))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20) // Align with circles
    }

    private func stepBackgroundColor(isCompleted: Bool, isCurrent: Bool) -> Color {
        if isCompleted {
            return .accentColor
        } else if isCurrent {
            return .accentColor
        } else {
            return Color(.systemGray5)
        }
    }
}

#Preview("Step 1") {
    StepProgressView(currentStep: .client) { _ in }
        .padding()
}

#Preview("Step 3") {
    StepProgressView(currentStep: .summary) { _ in }
        .padding()
}
```

---

## Database Changes

**None**

---

## Test Cases

### Test 1: Initial State
- Opens on Client step (step 1)
- Progress shows step 1 highlighted
- Back button visible, Continue disabled (no valid data)

### Test 2: Progress Indicator
- Step 1: Only step 1 circle filled
- Step 2: Step 1 has checkmark, step 2 filled
- Step 3: Steps 1-2 have checkmarks, step 3 filled

### Test 3: Step Navigation
- Can tap on previous/current steps
- Cannot tap on future steps
- Tapping completed step navigates back

### Test 4: Continue Button
- Disabled when step is invalid
- Enabled when step is valid
- Navigates to next step on tap

### Test 5: Back Button
- On step 1: Dismisses view
- On steps 2+: Goes to previous step

### Test 6: Submission
- On signature step, button shows "Complete Booking"
- Shows loading state during submission
- Disabled during submission

### Test 7: Cancel
- X button dismisses entire wizard
- Not shown on confirmation step

---

## Acceptance Checklist

- [ ] `BookingWizardView.swift` created
- [ ] `StepProgressView.swift` created
- [ ] Progress indicator shows 4 steps (not confirmation)
- [ ] Current step highlighted with accent color
- [ ] Completed steps show checkmark
- [ ] Step tap navigation works for accessible steps
- [ ] Back button works (dismiss on step 1, go back on others)
- [ ] Continue button disabled when step invalid
- [ ] Submit button on signature step
- [ ] Loading state during submission
- [ ] Cancel button dismisses wizard
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

- Wizard container is the shell; step views render inside it
- viewModel is passed to each step view
- [See: Stage 05] will implement ClientStepView
- [See: Stage 06] will implement DevicesStepView
- [See: Stage 07] will implement SummaryStepView
- [See: Stage 08] will implement SignatureStepView
- [See: Stage 09] will implement ConfirmationStepView
- Until those are built, use placeholder views that just show "Step X"
