//
//  Ticket.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Ticket

/// Support ticket/enquiry model
struct Ticket: Codable, Identifiable, Sendable, Equatable, Hashable {
    let id: String
    let ticketNumber: Int
    let subject: String
    let status: TicketStatus
    let ticketType: TicketType
    let assignedUserId: String?
    let assignedUser: AssignedUser?
    let mergedIntoTicketId: String?
    let locationId: String?
    let location: TicketLocation?
    let requiresLocation: Bool?
    let receivedCustomEmail: CustomEmail?
    let lastReplyFromCustomEmailId: String?
    let createdAt: String
    let updatedAt: String
    let lastClientUpdate: String?
    let client: TicketClient?
    let messages: [TicketMessage]?
    let order: TicketOrder?
    let notes: [TicketNote]?
    let smsAvailable: Bool?
    let smsRemaining: Int?
    let smsAlreadySent: Bool?
    /// 'sell' | 'repair_order' | 'enquiry', or nil on anything not from the storefront.
    let enquiryKind: String?
    /// 'visit' | 'collection' | 'doorstep', or nil when the customer was never asked.
    let fulfilment: String?
    /// Nil on every ticket with no doorstep collection in play, which is most.
    let collectionSlot: CollectionSlot?
    /// What the seller declared at order time. Staff need it as FIELDS, not as the
    /// paragraph in the storefront note: the not-confirmed list is the bench
    /// checklist, and a grade sitting next to the seller's own free-text note is what
    /// makes a contradiction visible. Nil outside a sell order.
    ///
    /// NO DEFAULT VALUE. `let x: T? = nil` compiles and keeps the memberwise init
    /// source-compatible, but Swift then omits the property from the synthesised
    /// Decodable conformance entirely - so it stays nil forever whatever the API
    /// sends, silently, with a green build. Pinned by
    /// SellDeclarationDecodeTests.staffTicketCarriesTheDeclaration.
    let sellDeclaration: SellDeclaration?
    /// Label state for a device-inbound ticket, so the row can show at a
    /// glance whether a postal ticket actually has its label. Absent on most
    /// tickets - the key is omitted, not null - so every field is optional.
    let buybackLabels: TicketBuybackLabels?

    // MARK: - Computed Properties

    /// Display name for ticket (e.g., "#100000001")
    var displayNumber: String {
        "#\(ticketNumber)"
    }

    /// Whether the ticket can receive replies
    var canReply: Bool {
        status != .closed && mergedIntoTicketId == nil
    }

    /// Whether the ticket can receive notes
    var canAddNote: Bool {
        status != .closed && mergedIntoTicketId == nil
    }

    /// Whether this ticket has been merged into another
    var isMerged: Bool {
        mergedIntoTicketId != nil
    }

    /// Time since last update
    var lastUpdatedDate: Date? {
        DateFormatters.parseDate(updatedAt)
    }

    /// Time since last client message
    var lastClientUpdateDate: Date? {
        guard let lastClientUpdate else { return nil }
        return DateFormatters.parseDate(lastClientUpdate)
    }

    /// Formatted last update time
    var formattedLastUpdate: String {
        guard let date = lastUpdatedDate else { return updatedAt }
        return DateFormatters.formatHumanDate(date)
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Assigned User

/// Staff member assigned to the ticket
struct AssignedUser: Codable, Equatable, Sendable {
    let firstName: String?
    let lastName: String?

    var fullName: String {
        [firstName, lastName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    var initials: String {
        let first = firstName?.first.map(String.init) ?? ""
        let last = lastName?.first.map(String.init) ?? ""
        return "\(first)\(last)".uppercased()
    }
}

// MARK: - Ticket Location

/// Location associated with the ticket
struct TicketLocation: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}

// MARK: - Custom Email

/// Custom email address for sending/receiving
struct CustomEmail: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let emailAddress: String
    let displayName: String?
}

// MARK: - Ticket Client

/// Customer/client associated with the ticket
struct TicketClient: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let email: String
    let name: String?
    let phone: String?
    let emailSuppressed: Int?
    let emailSuppressedAt: String?
    let isGeneratedEmail: Int?
    let suppressionStatus: String?
    let suppressionError: String?

    /// Display name or email if name is missing
    var displayName: String {
        name?.trimmingCharacters(in: .whitespaces).isEmpty == false
            ? name!
            : email
    }

    /// First name extracted from full name
    var firstName: String {
        name?.components(separatedBy: " ").first ?? email.components(separatedBy: "@").first ?? "Customer"
    }

    /// Whether email is suppressed (bounced/blocked)
    var isEmailSuppressed: Bool {
        (emailSuppressed ?? 0) == 1
    }

    /// Whether this is a system-generated placeholder email
    var hasGeneratedEmail: Bool {
        (isGeneratedEmail ?? 0) == 1
    }
}

// MARK: - Ticket Order

/// Order linked to this ticket (if ticket_type = "order")
struct TicketOrder: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let status: String
    let deviceCount: Int
    let devices: [TicketOrderDevice]?
}

// MARK: - Ticket Order Device

/// Device on the order linked to this ticket
struct TicketOrderDevice: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let status: String
}

// MARK: - Ticket Note

/// Internal note shown in ticket list (summary view)
struct TicketNote: Codable, Equatable, Sendable {
    let body: String
    let createdAt: String
    let createdBy: String?
    let deviceId: String?
    let deviceName: String?

    var formattedDate: String {
        guard let date = DateFormatters.parseDate(createdAt) else {
            return createdAt
        }
        return DateFormatters.formatHumanDate(date)
    }
}

// MARK: - Ticket List Response

/// Response from GET /api/tickets
struct TicketListResponse: Decodable, Sendable {
    let tickets: [Ticket]
    let companyLocations: [CompanyLocation]?
    let statusCounts: StatusCounts
    let ticketTypeCounts: TicketTypeCounts
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
}

// MARK: - Status Counts

/// Count of tickets by status
struct StatusCounts: Decodable, Equatable, Sendable {
    let open: Int
    let pending: Int
    let resolved: Int
    let closed: Int

    /// Total active tickets (not closed)
    var totalActive: Int {
        open + pending + resolved
    }
}

// MARK: - Ticket Type Counts

/// Count of tickets by type
struct TicketTypeCounts: Decodable, Equatable, Sendable {
    let lead: Int
    let order: Int

    var total: Int {
        lead + order
    }
}

// MARK: - Company Location

/// Location for filtering
struct CompanyLocation: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let isPrimary: Bool?
}

// MARK: - Ticket Buyback Labels

/// Mirrors the `buyback_labels` block the tickets list already returns, and
/// the web's BuybackLabelChips. Named for the endpoint that produces it; it
/// covers repair tickets too, which is why the chips say "customer".
struct TicketBuybackLabels: Codable, Equatable, Hashable, Sendable {
    let hasReturnLabel: Bool?
    let hasOutboundLabel: Bool?
    let packagingRequestedAt: String?
    /// A return-label request staged by a storefront submission or the
    /// customer's own portal press, awaiting staff approve/reject. See
    /// label_requests and docs/superpowers/specs/2026-08-11-label-request-staging-design.md.
    let hasPendingLabelRequest: Bool?

    /// Asked for and not yet sent - the one that needs a human.
    var packagingPending: Bool {
        packagingRequestedAt != nil && hasOutboundLabel != true
    }
}

