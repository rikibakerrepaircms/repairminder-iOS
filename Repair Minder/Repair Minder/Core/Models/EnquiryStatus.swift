//
//  EnquiryStatus.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

enum EnquiryStatus: String, Codable, CaseIterable, Sendable {
    case new = "new"
    case pending = "pending"
    case awaitingCustomer = "awaiting_customer"
    case converted = "converted"
    case spam = "spam"
    case archived = "archived"

    var displayName: String {
        switch self {
        case .new: return "New"
        case .pending: return "Pending Reply"
        case .awaitingCustomer: return "Awaiting Customer"
        case .converted: return "Converted"
        case .spam: return "Spam"
        case .archived: return "Archived"
        }
    }

    var shortName: String {
        switch self {
        case .new: return "New"
        case .pending: return "Pending"
        case .awaitingCustomer: return "Waiting"
        case .converted: return "Order"
        case .spam: return "Spam"
        case .archived: return "Done"
        }
    }

    var color: Color {
        switch self {
        case .new: return .blue
        case .pending: return .orange
        case .awaitingCustomer: return .purple
        case .converted: return .green
        case .spam: return .red
        case .archived: return .gray
        }
    }

    var isActive: Bool {
        switch self {
        case .new, .pending, .awaitingCustomer:
            return true
        case .converted, .spam, .archived:
            return false
        }
    }
}

// MARK: - EnquiryFilter
enum EnquiryFilter: String, CaseIterable, Sendable {
    case all = "all"
    case new = "new"
    case pending = "pending"
    case awaitingCustomer = "awaiting_customer"

    var displayName: String {
        switch self {
        case .all: return "All"
        case .new: return "New"
        case .pending: return "Needs Reply"
        case .awaitingCustomer: return "Waiting"
        }
    }

    var statusValue: String? {
        switch self {
        case .all: return nil
        case .new: return "new"
        case .pending: return "pending"
        case .awaitingCustomer: return "awaiting_customer"
        }
    }
}

// MARK: - EnquiryDeviceType
enum EnquiryDeviceType: String, Codable, CaseIterable, Sendable {
    case smartphone
    case tablet
    case laptop
    case desktop
    case console
    case other

    var displayName: String {
        switch self {
        case .smartphone: return "Smartphone"
        case .tablet: return "Tablet"
        case .laptop: return "Laptop"
        case .desktop: return "Desktop"
        case .console: return "Game Console"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .smartphone: return "iphone"
        case .tablet: return "ipad"
        case .laptop: return "laptopcomputer"
        case .desktop: return "desktopcomputer"
        case .console: return "gamecontroller"
        case .other: return "wrench.and.screwdriver"
        }
    }
}
