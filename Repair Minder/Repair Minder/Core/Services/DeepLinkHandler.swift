//
//  DeepLinkHandler.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import SwiftUI

// MARK: - Deep Link Handler

/// Handles deep linking from push notifications and URLs
@MainActor
final class DeepLinkHandler: ObservableObject {

    // MARK: - Singleton

    static let shared = DeepLinkHandler()

    // MARK: - Published State

    /// Pending deep link destination to navigate to
    @Published var pendingDestination: DeepLinkDestination?

    /// Whether we have a pending deep link
    var hasPendingDeepLink: Bool {
        pendingDestination != nil
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Handle Notification

    /// Handle a push notification payload
    /// - Parameter userInfo: The notification's userInfo dictionary
    func handleNotification(userInfo: [AnyHashable: Any]) {
        let payload = NotificationPayload(userInfo: userInfo)

        guard let destination = DeepLinkDestination.from(payload: payload) else {
            print("[DeepLinkHandler] Could not create destination from payload")
            return
        }

        print("[DeepLinkHandler] Setting pending destination: \(destination)")
        pendingDestination = destination
    }

    /// Handle notification when app is in foreground
    /// Returns true if notification should be displayed
    func shouldDisplayNotificationInForeground(userInfo: [AnyHashable: Any]) -> Bool {
        // For now, always display notifications even when in foreground
        // In the future, we might want to suppress notifications for the currently viewed screen
        return true
    }

    // MARK: - Clear Pending

    /// Clear the pending deep link after navigation
    func clearPendingDestination() {
        pendingDestination = nil
    }

    // MARK: - Handle URL

    /// Handle a URL deep link (e.g., from a Universal Link)
    /// - Parameter url: The URL to handle
    /// - Returns: Whether the URL was handled
    func handleURL(_ url: URL) -> Bool {
        // URL scheme: repairminder://order/uuid
        // Universal link: https://app.repairminder.com/order/uuid

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return false
        }

        let pathComponents = components.path.split(separator: "/").map(String.init)

        guard pathComponents.count >= 2 else {
            return false
        }

        let entityType = pathComponents[0]
        let entityId = pathComponents[1]

        switch entityType {
        case "order", "orders":
            pendingDestination = .order(id: entityId)
            return true

        case "device", "devices":
            pendingDestination = .device(id: entityId)
            return true

        case "enquiry", "enquiries":
            pendingDestination = .enquiry(id: entityId)
            return true

        case "ticket", "tickets":
            pendingDestination = .ticket(id: entityId)
            return true

        default:
            return false
        }
    }
}

// MARK: - Navigation Coordinator

/// Protocol for views that can handle deep link navigation
protocol DeepLinkNavigable {
    func navigate(to destination: DeepLinkDestination)
}
