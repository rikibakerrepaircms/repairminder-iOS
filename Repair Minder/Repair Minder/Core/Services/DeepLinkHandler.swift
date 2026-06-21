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
            #if DEBUG
            print("[DeepLinkHandler] Could not create destination from payload")
            #endif
            return
        }

        #if DEBUG
        print("[DeepLinkHandler] Setting pending destination: \(destination)")
        #endif
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

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return false
        }

        // Shop pairing (mechanism-agnostic — QR, universal link, or Bridge USB-launch):
        //   repairminder://diagnostics/pair?shop=NNNNNN   (or repairminder://pair?shop=NNNNNN,
        //   or .../pair/NNNNNN). Marks this device as belonging to the shop so diagnostic runs
        //   auto-send to it. See DiagnosticsShopPairing.
        let host = (components.host ?? "").lowercased()
        let rawPath = components.path.split(separator: "/").map(String.init)
        if host == "pair" || (host == "diagnostics" && rawPath.first?.lowercased() == "pair") {
            // Preferred: a server-issued pairing token (revocable server-side).
            if let token = components.queryItems?.first(where: { $0.name == "token" })?.value, !token.isEmpty {
                DiagnosticsShopPairing.pairWithToken(token)
                return true
            }
            // Fallback: a raw shop code.
            let shop = components.queryItems?.first(where: { $0.name == "shop" })?.value ?? rawPath.last
            if let shop, DiagnosticsShopPairing.isValidCode(shop) {
                DiagnosticsShopPairing.pair(shop)
                return true
            }
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

        case "buyback", "buybacks":
            pendingDestination = .buyback(id: entityId)
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
