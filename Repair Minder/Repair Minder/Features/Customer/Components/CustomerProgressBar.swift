//
//  CustomerProgressBar.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// Progress bar showing device workflow stages for customers
struct CustomerProgressBar: View {
    let status: String
    let workflowType: DeviceWorkflowType

    var body: some View {
        VStack(spacing: 12) {
            // Progress stages
            HStack(spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                    stageIndicator(
                        number: index + 1,
                        isComplete: index < currentStageIndex,
                        isCurrent: index == currentStageIndex,
                        isLast: index == stages.count - 1
                    )

                    if index < stages.count - 1 {
                        connector(isComplete: index < currentStageIndex)
                    }
                }
            }
            .padding(.horizontal, 4)

            // Current stage banner
            currentStageBanner
        }
    }

    // MARK: - Stage Configuration

    private struct StageInfo {
        let label: String
        let description: String
        let statuses: [String]
    }

    private var stages: [StageInfo] {
        switch workflowType {
        case .repair:
            return repairStages
        case .buyback:
            return buybackStages
        }
    }

    private var repairStages: [StageInfo] {
        [
            StageInfo(
                label: "Received",
                description: "We have your device",
                statuses: ["device_received"]
            ),
            StageInfo(
                label: "Being Assessed",
                description: "Our technicians are checking your device",
                statuses: ["diagnosing"]
            ),
            StageInfo(
                label: "Quote Ready",
                description: "Please review and approve",
                statuses: ["ready_to_quote", "awaiting_authorisation"]
            ),
            StageInfo(
                label: "In Repair",
                description: "Work is in progress",
                statuses: ["authorised_source_parts", "authorised_awaiting_parts", "ready_to_repair", "repairing"]
            ),
            StageInfo(
                label: "Quality Check",
                description: "Final checks in progress",
                statuses: ["repaired_qc"]
            ),
            StageInfo(
                label: "Ready",
                description: "Ready for collection",
                statuses: ["repaired_ready"]
            ),
            StageInfo(
                label: "Complete",
                description: "All done!",
                statuses: ["collected", "despatched"]
            )
        ]
    }

    private var buybackStages: [StageInfo] {
        [
            StageInfo(
                label: "Received",
                description: "We have your device",
                statuses: ["device_received"]
            ),
            StageInfo(
                label: "Being Assessed",
                description: "Evaluating your device",
                statuses: ["diagnosing"]
            ),
            StageInfo(
                label: "Offer Ready",
                description: "Please review our offer",
                statuses: ["ready_to_quote", "awaiting_authorisation"]
            ),
            StageInfo(
                label: "Processing Payment",
                description: "Preparing your payment",
                statuses: ["ready_to_pay"]
            ),
            StageInfo(
                label: "Paid",
                description: "Payment has been sent",
                statuses: ["payment_made", "added_to_buyback"]
            )
        ]
    }

    // MARK: - Current Stage Calculation

    private var currentStageIndex: Int {
        // Handle special statuses
        if isRejectionStatus {
            return -1 // Will show rejection banner instead
        }

        for (index, stage) in stages.enumerated() {
            if stage.statuses.contains(status) {
                return index
            }
        }

        // Default to first stage if not found
        return 0
    }

    private var currentStage: StageInfo? {
        guard currentStageIndex >= 0 && currentStageIndex < stages.count else { return nil }
        return stages[currentStageIndex]
    }

    private var isRejectionStatus: Bool {
        ["rejected", "company_rejected", "rejection_qc", "rejection_ready"].contains(status)
    }

    // MARK: - Stage Indicator

    private func stageIndicator(number: Int, isComplete: Bool, isCurrent: Bool, isLast: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(circleColor(isComplete: isComplete, isCurrent: isCurrent))
                    .frame(width: 32, height: 32)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isCurrent ? .white : .secondary)
                }
            }
            .overlay {
                if isCurrent {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                        .frame(width: 40, height: 40)
                }
            }
        }
    }

    private func circleColor(isComplete: Bool, isCurrent: Bool) -> Color {
        if isComplete {
            return .green
        } else if isCurrent {
            return .blue
        } else {
            return Color.platformGray5
        }
    }

    // MARK: - Connector

    private func connector(isComplete: Bool) -> some View {
        Rectangle()
            .fill(isComplete ? Color.green : Color.platformGray5)
            .frame(height: 3)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Current Stage Banner

    @ViewBuilder
    private var currentStageBanner: some View {
        if isRejectionStatus {
            rejectionBanner
        } else if let stage = currentStage {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stage.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(stage.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var rejectionBanner: some View {
        HStack {
            Image(systemName: rejectionIcon)
                .foregroundStyle(rejectionColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(rejectionLabel)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(rejectionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(rejectionColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var rejectionLabel: String {
        switch status {
        case "rejected": return workflowType == .buyback ? "Offer Declined" : "Quote Declined"
        case "company_rejected": return "Assessment Failed"
        case "rejection_qc": return "Preparing Return"
        case "rejection_ready": return "Ready for Collection"
        default: return "Declined"
        }
    }

    private var rejectionDescription: String {
        switch status {
        case "rejected": return "Contact us to arrange collection"
        case "company_rejected": return workflowType == .buyback ? "Buyback cannot proceed" : "Repair cannot proceed"
        case "rejection_qc": return "Device being prepared for return"
        case "rejection_ready": return "Device ready, visit to collect"
        default: return ""
        }
    }

    private var rejectionIcon: String {
        switch status {
        case "rejection_ready": return "checkmark.circle.fill"
        default: return "xmark.circle.fill"
        }
    }

    private var rejectionColor: Color {
        switch status {
        case "rejection_ready": return .green
        case "company_rejected": return .orange
        default: return .red
        }
    }
}

// MARK: - Preview

#Preview("Repair - Received") {
    VStack(spacing: 24) {
        CustomerProgressBar(status: "device_received", workflowType: .repair)
        CustomerProgressBar(status: "diagnosing", workflowType: .repair)
        CustomerProgressBar(status: "awaiting_authorisation", workflowType: .repair)
        CustomerProgressBar(status: "repairing", workflowType: .repair)
        CustomerProgressBar(status: "repaired_ready", workflowType: .repair)
        CustomerProgressBar(status: "rejected", workflowType: .repair)
    }
    .padding()
}

#Preview("Buyback") {
    VStack(spacing: 24) {
        CustomerProgressBar(status: "device_received", workflowType: .buyback)
        CustomerProgressBar(status: "awaiting_authorisation", workflowType: .buyback)
        CustomerProgressBar(status: "payment_made", workflowType: .buyback)
    }
    .padding()
}
