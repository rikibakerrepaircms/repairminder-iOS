//
//  Macro.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Macro

/// Macro/canned response template with optional follow-up stages
struct Macro: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let category: String?
    let description: String?
    let initialActionType: String // "email" or "note"
    let initialSubject: String?
    let initialContent: String
    let replyBehavior: String? // "cancel", "pause", "continue"
    let pauseExpiryDays: Int?
    let isActive: Int
    let sortOrder: Int
    let stageCount: Int?
    let stages: [MacroStage]?
    let createdAt: String?

    // MARK: - Computed Properties

    /// Whether this is an email macro (vs note)
    var isEmailMacro: Bool {
        initialActionType == "email"
    }

    /// Whether the macro is currently active
    var isEnabled: Bool {
        isActive == 1
    }

    /// Whether this macro has follow-up stages
    var hasFollowUps: Bool {
        (stageCount ?? 0) > 0
    }

    /// Human-readable reply behavior description
    var replyBehaviorDescription: String {
        switch replyBehavior {
        case "cancel":
            return "Cancels workflow when customer replies"
        case "pause":
            return "Pauses workflow when customer replies"
        case "continue":
            return "Continues regardless of replies"
        default:
            return "Default behavior"
        }
    }

    /// Category display name
    var categoryDisplayName: String {
        category?.replacingOccurrences(of: "_", with: " ").capitalized ?? "General"
    }
}

// MARK: - Macro Stage

/// A follow-up stage in a macro workflow
struct MacroStage: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let stageNumber: Int
    let delayMinutes: Int
    let delayDisplay: String?
    let actionType: String
    let subject: String?
    let content: String?
    let sendEmail: Int?
    let addNote: Int?
    let changeStatus: Int?
    let newStatus: String?
    let noteContent: String?
    let isActive: Int?

    // MARK: - Computed Properties

    /// Whether this stage sends an email
    var sendsEmail: Bool {
        (sendEmail ?? 0) == 1
    }

    /// Whether this stage adds an internal note
    var addsNote: Bool {
        (addNote ?? 0) == 1
    }

    /// Whether this stage changes the ticket status
    var changesStatus: Bool {
        (changeStatus ?? 0) == 1
    }

    /// Whether this stage is enabled
    var isEnabled: Bool {
        (isActive ?? 1) == 1
    }

    /// Human-readable delay description
    var delayDescription: String {
        if let display = delayDisplay, !display.isEmpty {
            return display
        }
        return formatDelay(minutes: delayMinutes)
    }

    /// Summary of actions this stage will perform
    var actionSummary: String {
        var actions: [String] = []
        if sendsEmail { actions.append("Send email") }
        if addsNote { actions.append("Add note") }
        if changesStatus, let status = newStatus {
            actions.append("Set status to \(status)")
        }
        return actions.joined(separator: ", ")
    }

    private func formatDelay(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
        let days = hours / 24
        return "\(days) day\(days == 1 ? "" : "s")"
    }
}

// MARK: - Macro List Response

/// Response from GET /api/macros
struct MacroListResponse: Decodable, Sendable {
    let macros: [Macro]
}

// MARK: - Execute Macro Request

/// Request body for POST /api/tickets/:id/macro
struct ExecuteMacroRequest: Encodable {
    let macroId: String
    let variableOverrides: [String: String]?
    let sendSms: Bool?
}

// MARK: - Execute Macro Response

/// Response from POST /api/tickets/:id/macro
struct ExecuteMacroResponse: Decodable, Sendable {
    let execution: MacroExecutionResult
}

/// Execution result after running a macro
struct MacroExecutionResult: Decodable, Sendable {
    let id: String
    let macroId: String
    let macroName: String
    let ticketId: String
    let status: String
    let initialMessageId: String?
    let scheduledStages: [ScheduledStage]?
    let createdAt: String
}

/// A scheduled follow-up stage
struct ScheduledStage: Decodable, Sendable, Equatable, Identifiable {
    let stageNumber: Int
    let scheduledFor: String
    let delayDisplay: String

    var id: Int { stageNumber }

    /// Scheduled date
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

    /// Relative time until execution
    var timeUntil: String {
        guard let date = scheduledDate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Macro Categories

/// Common macro categories
enum MacroCategory: String, CaseIterable, Sendable {
    case general
    case quotes
    case followUp = "follow_up"
    case reviews
    case collection
    case custom

    var label: String {
        switch self {
        case .general: return "General"
        case .quotes: return "Quotes"
        case .followUp: return "Follow-up"
        case .reviews: return "Reviews"
        case .collection: return "Collection"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .general: return "text.bubble"
        case .quotes: return "dollarsign.circle"
        case .followUp: return "clock.arrow.circlepath"
        case .reviews: return "star"
        case .collection: return "bag"
        case .custom: return "square.and.pencil"
        }
    }
}
