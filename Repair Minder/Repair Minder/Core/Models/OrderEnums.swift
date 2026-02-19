//
//  OrderEnums.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Order Status

/// Order status - auto-calculated from device statuses, read-only in iOS
enum OrderStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case onHold = "on_hold"
    case cancelled
    case awaitingDevice = "awaiting_device"
    case inProgress = "in_progress"
    case serviceComplete = "service_complete"
    case awaitingCollection = "awaiting_collection"
    case collectedDespatched = "collected_despatched"

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .onHold: return "On Hold"
        case .cancelled: return "Cancelled"
        case .awaitingDevice: return "Awaiting Device"
        case .inProgress: return "In Progress"
        case .serviceComplete: return "Service Complete"
        case .awaitingCollection: return "Awaiting Collection"
        case .collectedDespatched: return "Collected/Despatched"
        }
    }

    var shortLabel: String {
        switch self {
        case .pending: return "Pending"
        case .onHold: return "On Hold"
        case .cancelled: return "Cancelled"
        case .awaitingDevice: return "Awaiting"
        case .inProgress: return "In Progress"
        case .serviceComplete: return "Complete"
        case .awaitingCollection: return "Collection"
        case .collectedDespatched: return "Collected"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .yellow
        case .onHold: return .red
        case .cancelled: return .gray
        case .awaitingDevice: return .gray
        case .inProgress: return .blue
        case .serviceComplete: return .purple
        case .awaitingCollection: return .orange
        case .collectedDespatched: return .green
        }
    }

    var backgroundColor: Color {
        color.opacity(0.15)
    }

    var icon: String {
        switch self {
        case .pending: return "clock.badge.questionmark"
        case .onHold: return "exclamationmark.triangle"
        case .cancelled: return "xmark.circle"
        case .awaitingDevice: return "clock"
        case .inProgress: return "wrench.and.screwdriver"
        case .serviceComplete: return "checkmark.circle"
        case .awaitingCollection: return "shippingbox"
        case .collectedDespatched: return "checkmark.seal"
        }
    }
}

// MARK: - Payment Status

enum PaymentStatus: String, Codable, CaseIterable, Sendable {
    case unpaid
    case partial
    case paid
    case refunded

    var label: String {
        switch self {
        case .unpaid: return "Unpaid"
        case .partial: return "Partially Paid"
        case .paid: return "Paid"
        case .refunded: return "Refunded"
        }
    }

    var color: Color {
        switch self {
        case .unpaid: return .red
        case .partial: return .orange
        case .paid: return .green
        case .refunded: return .purple
        }
    }

    var backgroundColor: Color {
        color.opacity(0.15)
    }

    var icon: String {
        switch self {
        case .unpaid: return "creditcard"
        case .partial: return "creditcard.trianglebadge.exclamationmark"
        case .paid: return "checkmark.circle"
        case .refunded: return "arrow.counterclockwise"
        }
    }
}

// MARK: - Intake Method

enum IntakeMethod: String, Codable, CaseIterable, Sendable {
    case walkIn = "walk_in"
    case mailIn = "mail_in"
    case courier
    case counterSale = "counter_sale"
    case accessoriesInStore = "accessories_in_store"
    case online

    var label: String {
        switch self {
        case .walkIn: return "Walk-in"
        case .mailIn: return "Mail-in"
        case .courier: return "Courier"
        case .counterSale: return "Counter Sale"
        case .accessoriesInStore: return "Accessories In-Store"
        case .online: return "Online"
        }
    }

    var icon: String {
        switch self {
        case .walkIn: return "figure.walk"
        case .mailIn: return "envelope"
        case .courier: return "shippingbox"
        case .counterSale: return "cart"
        case .accessoriesInStore: return "bag"
        case .online: return "globe"
        }
    }
}

// MARK: - Authorisation Type

enum AuthorisationType: String, Codable, CaseIterable, Sendable {
    case preAuthorised = "pre_authorised"
    case preApproved = "pre_approved"
    case phone
    case email
    case portal

    var label: String {
        switch self {
        case .preAuthorised, .preApproved: return "Pre-Approved"
        case .phone: return "Phone"
        case .email: return "Email"
        case .portal: return "Portal"
        }
    }
}

// MARK: - Payment Method

enum PaymentMethod: String, Codable, CaseIterable, Sendable {
    case cash
    case card
    case bankTransfer = "bank_transfer"
    case paypal
    case invoice
    case other

    var label: String {
        switch self {
        case .cash: return "Cash"
        case .card: return "Card"
        case .bankTransfer: return "Bank Transfer"
        case .paypal: return "PayPal"
        case .invoice: return "Invoice"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .card: return "creditcard"
        case .bankTransfer: return "building.columns"
        case .paypal: return "p.circle"
        case .invoice: return "doc.text"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Signature Type

enum SignatureType: String, Codable, CaseIterable, Sendable {
    case dropOff = "drop_off"
    case collection
    case authorization

    var label: String {
        switch self {
        case .dropOff: return "Drop-off"
        case .collection: return "Collection"
        case .authorization: return "Authorization"
        }
    }
}

// MARK: - Order Item Type

enum OrderItemType: String, Codable, CaseIterable, Sendable {
    case part
    case labour
    case labor
    case repair
    case deviceSale = "device_sale"
    case accessory
    case devicePurchase = "device_purchase"
    case other

    var label: String {
        switch self {
        case .part: return "Part"
        case .labour, .labor: return "Labour"
        case .repair: return "Repair"
        case .deviceSale: return "Device Sale"
        case .accessory: return "Accessory"
        case .devicePurchase: return "Device Purchase"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .part: return "cpu"
        case .labour, .labor: return "wrench.and.screwdriver"
        case .repair: return "wrench.and.screwdriver"
        case .deviceSale: return "iphone"
        case .accessory: return "bag"
        case .devicePurchase: return "cart"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Carrier

enum Carrier: String, Codable, CaseIterable, Sendable {
    case royalMail = "Royal Mail"
    case dpd = "DPD"
    case dhl = "DHL"
    case ups = "UPS"
    case fedEx = "FedEx"
    case hermes = "Hermes"
    case yodel = "Yodel"
    case other = "Other"

    var label: String { rawValue }
}
