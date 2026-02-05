//
//  MacroExecution.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Macro Execution

/// An active or completed macro execution (workflow) on a ticket
struct MacroExecution: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let macroId: String
    let macroName: String
    let ticketId: String
    let ticketNumber: Int?
    let ticketSubject: String?
    let clientName: String?
    let clientEmail: String?
    let status: ExecutionStatus
    let executedByName: String?
    let createdAt: String
    let cancelledAt: String?
    let cancelledReason: String?
    let completedAt: String?
    let stagesCompleted: Int?
    let stagesTotal: Int?
    let nextStage: NextStage?

    // MARK: - Computed Properties

    /// Progress as a fraction (0.0 - 1.0)
    var progress: Double {
        guard let total = stagesTotal, total > 0 else { return 0 }
        let completed = stagesCompleted ?? 0
        return Double(completed) / Double(total)
    }

    /// Progress description (e.g., "2 of 3 stages")
    var progressDescription: String {
        let completed = stagesCompleted ?? 0
        let total = stagesTotal ?? 0
        return "\(completed) of \(total) stage\(total == 1 ? "" : "s")"
    }

    /// Whether there are pending stages
    var hasPendingStages: Bool {
        let completed = stagesCompleted ?? 0
        let total = stagesTotal ?? 0
        return completed < total
    }

    /// Formatted creation date
    var formattedCreatedAt: String {
        guard let date = ISO8601DateFormatter().date(from: createdAt) else {
            return createdAt
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Relative time since creation
    var relativeCreatedAt: String {
        guard let date = ISO8601DateFormatter().date(from: createdAt) else {
            return createdAt
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Formatted completion date
    var formattedCompletedAt: String? {
        guard let completedAt else { return nil }
        guard let date = ISO8601DateFormatter().date(from: completedAt) else {
            return completedAt
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Formatted cancellation date
    var formattedCancelledAt: String? {
        guard let cancelledAt else { return nil }
        guard let date = ISO8601DateFormatter().date(from: cancelledAt) else {
            return cancelledAt
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Next Stage

/// Information about the next scheduled stage
struct NextStage: Codable, Equatable, Sendable {
    let stageNumber: Int
    let scheduledFor: String
    let timeUntil: String?
    let delayMinutes: Int?

    /// Scheduled execution date
    var scheduledDate: Date? {
        ISO8601DateFormatter().date(from: scheduledFor)
    }

    /// Human-readable scheduled time
    var formattedScheduledTime: String {
        guard let date = scheduledDate else { return scheduledFor }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Whether this stage is overdue
    var isOverdue: Bool {
        guard let date = scheduledDate else { return false }
        return date < Date()
    }

    /// Time remaining until execution
    var timeRemaining: String {
        if let timeUntil, !timeUntil.isEmpty {
            return timeUntil
        }
        guard let date = scheduledDate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Execution List Response

/// Response from GET /api/tickets/:id/macro-executions
struct MacroExecutionListResponse: Decodable, Sendable {
    let executions: [MacroExecution]
    let pagination: ExecutionPagination?
}

/// Pagination for execution list
struct ExecutionPagination: Decodable, Sendable {
    let total: Int
    let page: Int
    let perPage: Int
    let totalPages: Int
}

// MARK: - Pause Request

/// Request body for PATCH /api/macro-executions/:id/pause
struct PauseExecutionRequest: Encodable {
    let reason: String?
}

// MARK: - Pause Response

/// Response from PATCH /api/macro-executions/:id/pause
struct PauseExecutionResponse: Decodable, Sendable {
    let success: Bool
    let execution: MacroExecution?
    let pendingStagesCount: Int?
    let message: String?
}

// MARK: - Resume Request

/// Request body for PATCH /api/macro-executions/:id/resume
struct ResumeExecutionRequest: Encodable {
    let schedulingOption: String // "immediate", "keep_original", "reschedule_from_now"
}

// MARK: - Resume Response

/// Response from PATCH /api/macro-executions/:id/resume
struct ResumeExecutionResponse: Decodable, Sendable {
    let success: Bool
    let execution: MacroExecution?
    let nextStage: NextStage?
    let message: String?
}

// MARK: - Cancel Request

/// Request body for DELETE /api/macro-executions/:id or PATCH .../cancel
struct CancelExecutionRequest: Encodable {
    let reason: String?
}

// MARK: - Cancel Response

/// Response from cancellation
struct CancelExecutionResponse: Decodable, Sendable {
    let success: Bool
    let cancelledStages: Int?
    let execution: MacroExecution?
    let message: String?
}

// MARK: - Update Variables Request

/// Request body for PATCH /api/macro-executions/:id/variables
struct UpdateExecutionVariablesRequest: Encodable {
    let variables: [String: String]
}

// MARK: - Update Variables Response

/// Response from updating variables
struct UpdateExecutionVariablesResponse: Decodable, Sendable {
    let success: Bool
    let variablesSnapshot: [String: String]?
    let message: String?
}
