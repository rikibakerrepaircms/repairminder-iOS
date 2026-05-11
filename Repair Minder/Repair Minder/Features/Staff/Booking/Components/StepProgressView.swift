//
//  StepProgressView.swift
//  Repair Minder
//

import SwiftUI

struct StepProgressView: View {
    let currentStep: BookingStep
    /// Steps to render in the progress bar. Caller supplies the filtered list
    /// so mail_in / courier flows skip Devices + Signature.
    let steps: [BookingStep]
    let onStepTap: (BookingStep) -> Void

    /// Drop the confirmation step from the progress bar (it's the end state).
    private var visibleSteps: [BookingStep] {
        steps.filter { $0 != .confirmation }
    }

    private var currentVisibleIndex: Int {
        visibleSteps.firstIndex(of: currentStep) ?? 0
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(visibleSteps.enumerated()), id: \.element.id) { index, step in
                stepItem(step: step, index: index)

                if index < visibleSteps.count - 1 {
                    stepConnector(isCompleted: index < currentVisibleIndex)
                }
            }
        }
    }

    @ViewBuilder
    private func stepItem(step: BookingStep, index: Int) -> some View {
        // index-based now that the visible list may skip steps.
        let isCompleted = index < currentVisibleIndex
        let isCurrent = step == currentStep
        let isAccessible = index <= currentVisibleIndex

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
                        Text("\(index + 1)")
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
            .fill(isCompleted ? Color.accentColor : Color.platformGray4)
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
            return Color.platformGray5
        }
    }
}

#Preview("Walk-in · Step 1") {
    StepProgressView(currentStep: .client, steps: BookingStep.allCases) { _ in }
        .padding()
}

#Preview("Walk-in · Step 3") {
    StepProgressView(currentStep: .summary, steps: BookingStep.allCases) { _ in }
        .padding()
}

#Preview("Mail-in · Summary") {
    StepProgressView(
        currentStep: .summary,
        steps: [.client, .summary, .confirmation]
    ) { _ in }
    .padding()
}
