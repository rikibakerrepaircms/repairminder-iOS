//
//  TicketEnums.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Ticket Status

/// Status of a support ticket
enum TicketStatus: String, Codable, CaseIterable, Sendable {
    case open
    case pending
    case resolved
    case closed

    var label: String {
        switch self {
        case .open: return "Open"
        case .pending: return "Pending"
        case .resolved: return "Resolved"
        case .closed: return "Closed"
        }
    }

    var shortLabel: String {
        switch self {
        case .open: return "Open"
        case .pending: return "Pending"
        case .resolved: return "Resolved"
        case .closed: return "Closed"
        }
    }

    var color: Color {
        switch self {
        case .open: return .blue
        case .pending: return .orange
        case .resolved: return .green
        case .closed: return .gray
        }
    }

    var icon: String {
        switch self {
        case .open: return "envelope.open"
        case .pending: return "clock"
        case .resolved: return "checkmark.circle"
        case .closed: return "archivebox"
        }
    }
}

// MARK: - Ticket Type

/// Type of ticket: lead (enquiry) or order-related
enum TicketType: String, Codable, CaseIterable, Sendable {
    case lead
    case order

    var label: String {
        switch self {
        case .lead: return "Lead/Enquiry"
        case .order: return "Order"
        }
    }

    var shortLabel: String {
        switch self {
        case .lead: return "Lead"
        case .order: return "Order"
        }
    }

    var icon: String {
        switch self {
        case .lead: return "envelope"
        case .order: return "bag"
        }
    }

    var color: Color {
        switch self {
        case .lead: return .purple
        case .order: return .blue
        }
    }
}

// MARK: - Message Type

/// Type of message in a ticket conversation
enum MessageType: String, Codable, Sendable {
    case inbound
    case outbound
    case note
    case outboundSms = "outbound_sms"

    /// Whether this message is visible to customers
    var isPublic: Bool {
        switch self {
        case .inbound, .outbound, .outboundSms:
            return true
        case .note:
            return false
        }
    }

    /// Whether this is an incoming message from the customer
    var isFromCustomer: Bool {
        self == .inbound
    }

    var label: String {
        switch self {
        case .inbound: return "Customer"
        case .outbound: return "Email"
        case .note: return "Internal Note"
        case .outboundSms: return "SMS"
        }
    }

    var icon: String {
        switch self {
        case .inbound: return "envelope.badge"
        case .outbound: return "paperplane"
        case .note: return "note.text"
        case .outboundSms: return "message"
        }
    }
}

// MARK: - Macro Execution Status

/// Status of a macro execution (workflow)
enum ExecutionStatus: String, Codable, CaseIterable, Sendable {
    case active
    case paused
    case completed
    case cancelled

    var label: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var color: Color {
        switch self {
        case .active: return .green
        case .paused: return .orange
        case .completed: return .blue
        case .cancelled: return .gray
        }
    }

    var icon: String {
        switch self {
        case .active: return "play.circle"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }

    /// Whether the execution can be modified
    var isModifiable: Bool {
        self == .active || self == .paused
    }
}

// MARK: - Workflow Status Filter

/// Filter options for workflow status in ticket list
enum WorkflowStatusFilter: String, CaseIterable, Sendable {
    case all
    case none
    case active
    case paused
    case completed
    case cancelled

    var label: String {
        switch self {
        case .all: return "All"
        case .none: return "No Workflow"
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Scheduling Option

/// Options for resuming a paused workflow
enum SchedulingOption: String, Codable, CaseIterable, Sendable {
    case immediate
    case keepOriginal = "keep_original"
    case rescheduleFromNow = "reschedule_from_now"

    var label: String {
        switch self {
        case .immediate: return "Execute Immediately"
        case .keepOriginal: return "Keep Original Schedule"
        case .rescheduleFromNow: return "Reschedule from Now"
        }
    }

    var description: String {
        switch self {
        case .immediate:
            return "Run the next stage right away"
        case .keepOriginal:
            return "Continue with the original scheduled times"
        case .rescheduleFromNow:
            return "Recalculate all delays starting from now"
        }
    }
}
