//
//  DeepLinkHandler.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import os.log

/// Handles deep linking from notifications and URL schemes
@MainActor
final class DeepLinkHandler {
    static let shared = DeepLinkHandler()

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "DeepLink")

    /// The router to use for navigation (set by the app on launch)
    weak var router: AppRouter?

    private init() {}

    // MARK: - Public API

    /// Handle a notification tap with userInfo payload
    func handle(userInfo: [AnyHashable: Any]) async {
        guard let payload = NotificationPayload(userInfo: userInfo) else {
            logger.debug("Could not parse notification payload")
            return
        }

        logger.debug("Handling notification: \(payload.debugDescription)")

        // Navigate based on notification type
        guard let entityId = payload.entityId else {
            logger.debug("No entity ID in notification, skipping navigation")
            return
        }

        navigate(for: payload.type, entityId: entityId)
    }

    /// Handle a URL scheme deep link
    /// Format: repairminder://order/{id}, repairminder://device/{id}, etc.
    func handle(url: URL) {
        logger.debug("Handling URL: \(url.absoluteString)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "repairminder" else {
            logger.debug("Invalid URL scheme")
            return
        }

        guard let host = components.host else {
            logger.debug("No host in URL")
            return
        }

        // Path components after the host
        let pathComponents = components.path
            .split(separator: "/")
            .map(String.init)

        switch host {
        case "order":
            if let id = pathComponents.first ?? components.queryItems?.first(where: { $0.name == "id" })?.value {
                navigate(to: .orderDetail(id: id))
            }

        case "device":
            if let id = pathComponents.first ?? components.queryItems?.first(where: { $0.name == "id" })?.value {
                navigate(to: .deviceDetail(id: id))
            }

        case "client":
            if let id = pathComponents.first ?? components.queryItems?.first(where: { $0.name == "id" })?.value {
                navigate(to: .clientDetail(id: id))
            }

        case "ticket":
            // TODO: Stage 15 - Ticket detail view
            if let id = pathComponents.first {
                logger.debug("Ticket navigation not yet implemented for: \(id)")
            }

        case "enquiry":
            if let id = pathComponents.first ?? components.queryItems?.first(where: { $0.name == "id" })?.value {
                navigate(to: .enquiryDetail(id: id))
            }

        case "dashboard":
            navigate(to: .dashboard)

        case "orders":
            navigate(to: .orders)

        case "devices":
            navigate(to: .devices)

        case "clients":
            navigate(to: .clients)

        case "scanner":
            navigate(to: .scanner)

        default:
            logger.debug("Unknown deep link host: \(host)")
        }
    }

    // MARK: - Private

    private func navigate(for type: NotificationPayload.NotificationType, entityId: String) {
        guard let router = router else {
            logger.error("Router not set, cannot navigate")
            return
        }

        switch type {
        case .orderCreated, .orderStatusChanged, .paymentReceived, .quoteApproved, .quoteRejected:
            router.selectedTab = .orders
            router.popToRoot()
            router.navigate(to: .orderDetail(id: entityId))
            logger.debug("Navigated to order: \(entityId)")

        case .deviceAssigned, .deviceStatusChanged:
            // Devices are accessed through orders tab
            router.selectedTab = .orders
            router.popToRoot()
            router.navigate(to: .deviceDetail(id: entityId))
            logger.debug("Navigated to device: \(entityId)")

        case .ticketMessage, .ticketReopened:
            // TODO: Stage 15 - Ticket detail view
            // For now, just log that we would navigate
            logger.debug("Ticket navigation not yet implemented for: \(entityId)")
            // When TicketDetailView is available:
            // router.navigate(to: .ticketDetail(id: entityId))

        case .enquiryReceived, .enquiryReply:
            router.selectedTab = .orders  // Enquiries accessed from Orders tab for now
            router.popToRoot()
            router.navigate(to: .enquiryDetail(id: entityId))
            logger.debug("Navigated to enquiry: \(entityId)")

        case .unknown:
            logger.debug("Unknown notification type, no navigation")
        }
    }

    private func navigate(to route: AppRoute) {
        guard let router = router else {
            logger.error("Router not set, cannot navigate")
            return
        }

        // Select appropriate tab if needed
        switch route {
        case .dashboard:
            router.selectedTab = .dashboard
            router.popToRoot()

        case .orders, .orderDetail:
            router.selectedTab = .orders
            router.popToRoot()
            if case .orderDetail = route {
                router.navigate(to: route)
            }

        case .devices, .deviceDetail:
            router.selectedTab = .orders
            router.popToRoot()
            router.navigate(to: route)

        case .clients, .clientDetail:
            router.selectedTab = .clients
            router.popToRoot()
            if case .clientDetail = route {
                router.navigate(to: route)
            }

        case .scanner:
            router.selectedTab = .dashboard
            router.popToRoot()
            router.navigate(to: .scanner)

        case .settings:
            router.selectedTab = .settings
            router.popToRoot()

        case .enquiries:
            router.selectedTab = .orders  // Enquiries accessed from Orders tab for now
            router.popToRoot()
            router.navigate(to: .enquiries)

        case .enquiryDetail:
            router.selectedTab = .orders  // Enquiries accessed from Orders tab for now
            router.popToRoot()
            router.navigate(to: route)

        case .login:
            break // Handle login separately
        }

        logger.debug("Navigated to: \(String(describing: route))")
    }
}
