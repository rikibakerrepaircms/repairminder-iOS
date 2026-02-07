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
