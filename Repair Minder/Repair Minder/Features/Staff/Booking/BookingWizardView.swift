//
//  BookingWizardView.swift
//  Repair Minder
//

import SwiftUI

struct BookingWizardView: View {
    @State private var viewModel: BookingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    let onComplete: () -> Void

    init(viewModel: BookingViewModel, serviceType: ServiceType, onComplete: @escaping () -> Void) {
        self._viewModel = State(initialValue: viewModel)
        viewModel.formData.serviceType = serviceType
        self.onComplete = onComplete
    }

    private var completedSteps: [BookingStep] {
        BookingStep.allCases.filter { $0.rawValue < viewModel.currentStep.rawValue && $0 != .confirmation }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress Steps - iPhone only (hide on confirmation)
            if sizeClass != .regular && viewModel.currentStep != .confirmation {
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

            // Error Banner
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                    Spacer()
                    Button("Retry") {
                        viewModel.errorMessage = nil
                        Task { await viewModel.loadInitialData() }
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
            }

            // Step Content
            ScrollView {
                VStack(spacing: 16) {
                    // iPad: completed steps as collapsible summary cards
                    if sizeClass == .regular && viewModel.currentStep != .confirmation {
                        ForEach(completedSteps) { step in
                            CompletedStepCard(step: step, viewModel: viewModel) {
                                viewModel.goToStep(step)
                            }
                        }
                    }

                    stepContent
                }
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
                onComplete()
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

// MARK: - Completed Step Card (iPad)

/// Compact summary card shown for completed wizard steps on iPad.
/// Replaces the step progress bar, allowing tap-to-edit navigation.
struct CompletedStepCard: View {
    let step: BookingStep
    let viewModel: BookingViewModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var summaryText: String {
        switch step {
        case .client:
            let name = viewModel.formData.clientDisplayName
            let contact = viewModel.formData.noEmail ? viewModel.formData.phone : viewModel.formData.email
            return [name, contact].filter { !$0.isEmpty }.joined(separator: " · ")
        case .devices:
            let names = viewModel.formData.devices.map(\.displayName).joined(separator: ", ")
            return "\(viewModel.formData.devices.count) device\(viewModel.formData.devices.count != 1 ? "s" : "") · \(names)"
        case .summary:
            var parts: [String] = []
            if !viewModel.formData.internalNotes.isEmpty { parts.append("Notes added") }
            if viewModel.formData.readyByDate != nil { parts.append("Ready-by set") }
            if viewModel.formData.preAuthEnabled { parts.append("Pre-auth enabled") }
            return parts.isEmpty ? "No additional options" : parts.joined(separator: " · ")
        case .signature:
            return "Terms agreed · Signature provided"
        case .confirmation:
            return ""
        }
    }
}

#Preview {
    NavigationStack {
        BookingWizardView(viewModel: BookingViewModel(), serviceType: .repair, onComplete: {})
    }
}
