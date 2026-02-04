//
//  APIEndpoints.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import Foundation

/// Type-erasing wrapper for Encodable bodies
struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        encodeClosure = { encoder in
            try wrapped.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

/// Represents an API endpoint with all necessary request information
struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let body: AnyEncodable?
    let queryParameters: [String: String]?

    init(
        path: String,
        method: HTTPMethod = .get,
        body: (some Encodable)? = nil as AnyEncodable?,
        queryParameters: [String: String]? = nil
    ) {
        self.path = path
        self.method = method
        self.body = body.map { AnyEncodable($0) }
        self.queryParameters = queryParameters
    }

    init(
        path: String,
        method: HTTPMethod = .get,
        queryParameters: [String: String]? = nil
    ) {
        self.path = path
        self.method = method
        self.body = nil
        self.queryParameters = queryParameters
    }
}

// MARK: - Auth Endpoints
extension APIEndpoint {
    static func login(email: String, password: String, twoFactorToken: String? = nil) -> APIEndpoint {
        struct LoginBody: Encodable {
            let email: String
            let password: String
            let twoFactorToken: String?
        }
        return APIEndpoint(
            path: "/api/auth/login",
            method: .post,
            body: LoginBody(email: email, password: password, twoFactorToken: twoFactorToken)
        )
    }

    static func logout() -> APIEndpoint {
        APIEndpoint(path: "/api/auth/logout", method: .post)
    }

    static func refreshToken(refreshToken: String) -> APIEndpoint {
        struct RefreshBody: Encodable {
            let refreshToken: String
        }
        return APIEndpoint(
            path: "/api/auth/refresh",
            method: .post,
            body: RefreshBody(refreshToken: refreshToken)
        )
    }

    static func me() -> APIEndpoint {
        APIEndpoint(path: "/api/auth/me")
    }

    static func requestMagicLink(email: String) -> APIEndpoint {
        struct MagicLinkBody: Encodable {
            let email: String
        }
        return APIEndpoint(
            path: "/api/auth/magic-link/request",
            method: .post,
            body: MagicLinkBody(email: email)
        )
    }

    static func verifyMagicLinkCode(email: String, code: String) -> APIEndpoint {
        struct VerifyCodeBody: Encodable {
            let email: String
            let code: String
        }
        return APIEndpoint(
            path: "/api/auth/magic-link/verify-code",
            method: .post,
            body: VerifyCodeBody(email: email, code: code)
        )
    }
}

// MARK: - Dashboard Endpoints
extension APIEndpoint {
    static func dashboardStats(scope: String = "user", period: String = "this_month") -> APIEndpoint {
        APIEndpoint(
            path: "/api/dashboard/stats",
            queryParameters: ["scope": scope, "period": period]
        )
    }

    static func enquiryStats(scope: String = "user", includeBreakdown: Bool = false) -> APIEndpoint {
        APIEndpoint(
            path: "/api/dashboard/enquiry-stats",
            queryParameters: [
                "scope": scope,
                "include_breakdown": String(includeBreakdown)
            ]
        )
    }

    static func categoryBreakdown(scope: String = "user", period: String = "this_month") -> APIEndpoint {
        APIEndpoint(
            path: "/api/dashboard/category-breakdown",
            queryParameters: ["scope": scope, "period": period]
        )
    }
}

// MARK: - Orders Endpoints
extension APIEndpoint {
    static func orders(
        page: Int = 1,
        limit: Int = 20,
        status: String? = nil,
        search: String? = nil
    ) -> APIEndpoint {
        var params: [String: String] = [
            "page": String(page),
            "limit": String(limit)
        ]
        if let status = status { params["status"] = status }
        if let search = search { params["search"] = search }

        return APIEndpoint(path: "/api/orders", queryParameters: params)
    }

    static func order(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/orders/\(id)")
    }

    static func createOrder<T: Encodable>(body: T) -> APIEndpoint {
        APIEndpoint(path: "/api/orders", method: .post, body: body)
    }

    static func updateOrder<T: Encodable>(id: String, body: T) -> APIEndpoint {
        APIEndpoint(path: "/api/orders/\(id)", method: .patch, body: body)
    }
}

// MARK: - Devices Endpoints
extension APIEndpoint {
    static func devices(
        page: Int = 1,
        limit: Int = 20,
        status: String? = nil,
        orderId: String? = nil
    ) -> APIEndpoint {
        var params: [String: String] = [
            "page": String(page),
            "limit": String(limit)
        ]
        if let status = status { params["status"] = status }
        if let orderId = orderId { params["order_id"] = orderId }

        return APIEndpoint(path: "/api/devices", queryParameters: params)
    }

    static func device(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/devices/\(id)")
    }

    static func updateDevice<T: Encodable>(id: String, body: T) -> APIEndpoint {
        APIEndpoint(path: "/api/devices/\(id)", method: .patch, body: body)
    }

    static func myQueue(page: Int = 1, limit: Int = 20) -> APIEndpoint {
        APIEndpoint(
            path: "/api/devices/my-queue",
            queryParameters: ["page": String(page), "limit": String(limit)]
        )
    }
}

// MARK: - Clients Endpoints
extension APIEndpoint {
    static func clients(
        page: Int = 1,
        limit: Int = 20,
        search: String? = nil
    ) -> APIEndpoint {
        var params: [String: String] = [
            "page": String(page),
            "limit": String(limit)
        ]
        if let search = search { params["search"] = search }

        return APIEndpoint(path: "/api/clients", queryParameters: params)
    }

    static func client(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/clients/\(id)")
    }

    static func clientOrders(id: String, page: Int = 1, limit: Int = 20) -> APIEndpoint {
        APIEndpoint(
            path: "/api/clients/\(id)/orders",
            queryParameters: ["page": String(page), "limit": String(limit)]
        )
    }
}

// MARK: - Tickets/Enquiries Endpoints
extension APIEndpoint {
    static func tickets(
        page: Int = 1,
        limit: Int = 20,
        status: String? = nil
    ) -> APIEndpoint {
        var params: [String: String] = [
            "page": String(page),
            "limit": String(limit)
        ]
        if let status = status { params["status"] = status }

        return APIEndpoint(path: "/api/tickets", queryParameters: params)
    }

    static func ticket(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/tickets/\(id)")
    }

    static func ticketMessages(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/tickets/\(id)/messages")
    }

    static func sendTicketMessage<T: Encodable>(id: String, body: T) -> APIEndpoint {
        APIEndpoint(path: "/api/tickets/\(id)/messages", method: .post, body: body)
    }
}

// MARK: - Scanner/Lookup Endpoints
extension APIEndpoint {
    static func lookupByQR(code: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/lookup/qr",
            queryParameters: ["code": code]
        )
    }

    static func lookupByBarcode(barcode: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/lookup/barcode",
            queryParameters: ["barcode": barcode]
        )
    }
}

// MARK: - User Settings Endpoints
extension APIEndpoint {
    static func userSettings() -> APIEndpoint {
        APIEndpoint(path: "/api/user/settings")
    }

    static func updateUserSettings<T: Encodable>(body: T) -> APIEndpoint {
        APIEndpoint(path: "/api/user/settings", method: .patch, body: body)
    }
}

// MARK: - Push Notification Endpoints
extension APIEndpoint {
    /// Register a device token for push notifications
    static func registerDeviceToken(token: String, appType: String = "staff") -> APIEndpoint {
        struct DeviceTokenBody: Encodable {
            let deviceToken: String
            let platform: String
            let appType: String
        }
        return APIEndpoint(
            path: "/api/user/device-token",
            method: .post,
            body: DeviceTokenBody(deviceToken: token, platform: "ios", appType: appType)
        )
    }

    /// Unregister a device token (call on logout)
    static func unregisterDeviceToken(token: String) -> APIEndpoint {
        struct DeviceTokenBody: Encodable {
            let deviceToken: String
        }
        return APIEndpoint(
            path: "/api/user/device-token",
            method: .delete,
            body: DeviceTokenBody(deviceToken: token)
        )
    }

    /// Get push notification preferences
    static func getPushPreferences() -> APIEndpoint {
        APIEndpoint(path: "/api/user/push-preferences")
    }

    /// Update push notification preferences
    static func updatePushPreferences(preferences: PushNotificationPreferences) -> APIEndpoint {
        APIEndpoint(
            path: "/api/user/push-preferences",
            method: .put,
            body: preferences
        )
    }
}

/// Push notification preferences model
struct PushNotificationPreferences: Codable {
    var notificationsEnabled: Bool
    var orderStatusChanged: Bool
    var orderCreated: Bool
    var orderCollected: Bool
    var deviceStatusChanged: Bool
    var quoteApproved: Bool
    var quoteRejected: Bool
    var paymentReceived: Bool
    var newEnquiry: Bool
    var enquiryReply: Bool

    static let defaultPreferences = PushNotificationPreferences(
        notificationsEnabled: true,
        orderStatusChanged: true,
        orderCreated: true,
        orderCollected: true,
        deviceStatusChanged: true,
        quoteApproved: true,
        quoteRejected: true,
        paymentReceived: true,
        newEnquiry: true,
        enquiryReply: true
    )
}

// MARK: - Customer Portal Authentication Endpoints
extension APIEndpoint {
    /// Request a magic link code for customer authentication
    /// - Parameters:
    ///   - email: Customer's email address
    ///   - companyId: Optional company ID (ignored if on custom domain)
    static func customerRequestMagicLink(email: String, companyId: String? = nil) -> APIEndpoint {
        struct MagicLinkBody: Encodable {
            let email: String
            let companyId: String?
        }
        return APIEndpoint(
            path: "/api/customer/auth/request-magic-link",
            method: .post,
            body: MagicLinkBody(email: email, companyId: companyId)
        )
    }

    /// Verify the magic link code for customer
    /// - Parameters:
    ///   - email: Customer's email address
    ///   - code: The verification code
    ///   - companyId: Optional company ID (if provided, completes login; if not, returns company list)
    static func customerVerifyCode(email: String, code: String, companyId: String? = nil) -> APIEndpoint {
        struct VerifyCodeBody: Encodable {
            let email: String
            let code: String
            let companyId: String?
        }
        return APIEndpoint(
            path: "/api/customer/auth/verify-code",
            method: .post,
            body: VerifyCodeBody(email: email, code: code, companyId: companyId)
        )
    }

    /// Get current customer session info
    static func customerGetMe() -> APIEndpoint {
        APIEndpoint(path: "/api/customer/auth/me")
    }

    /// Customer logout
    static func customerLogout() -> APIEndpoint {
        APIEndpoint(path: "/api/customer/auth/logout", method: .post)
    }

    /// Verify order access token (for magic link direct order access)
    static func customerOrderAccess(token: String) -> APIEndpoint {
        APIEndpoint(path: "/api/customer/order-access/\(token)")
    }
}

// MARK: - Customer Orders Endpoints
extension APIEndpoint {
    /// Get customer's orders
    static func customerOrders(page: Int = 1, limit: Int = 20) -> APIEndpoint {
        APIEndpoint(
            path: "/api/customer/orders",
            queryParameters: ["page": String(page), "limit": String(limit)]
        )
    }

    /// Get a specific customer order with full details
    /// Returns: order info, devices, items, totals, messages, company info
    static func customerOrder(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/customer/orders/\(id)")
    }

    /// Approve or reject an order quote
    /// - Parameters:
    ///   - orderId: The order ID
    ///   - action: "approve" or "reject"
    ///   - signatureType: "typed" or "drawn"
    ///   - signatureData: The signature data (typed name or base64 drawing)
    ///   - amountAcknowledged: The total amount the customer acknowledges
    ///   - rejectionReason: Optional reason for rejection (only for reject action)
    static func customerApproveOrder(
        orderId: String,
        action: String,
        signatureType: String,
        signatureData: String,
        amountAcknowledged: Double? = nil,
        rejectionReason: String? = nil
    ) -> APIEndpoint {
        struct ApproveBody: Encodable {
            let action: String
            let signature_type: String
            let signature_data: String
            let amount_acknowledged: Double?
            let rejection_reason: String?
        }
        return APIEndpoint(
            path: "/api/customer/orders/\(orderId)/approve",
            method: .post,
            body: ApproveBody(
                action: action,
                signature_type: signatureType,
                signature_data: signatureData,
                amount_acknowledged: amountAcknowledged,
                rejection_reason: rejectionReason
            )
        )
    }

    /// Send a reply/message for an order
    /// - Parameters:
    ///   - orderId: The order ID
    ///   - message: The message content
    ///   - deviceId: Optional device ID if the message is about a specific device
    static func customerReply(orderId: String, message: String, deviceId: String? = nil) -> APIEndpoint {
        struct ReplyBody: Encodable {
            let message: String
            let device_id: String?
        }
        return APIEndpoint(
            path: "/api/customer/orders/\(orderId)/reply",
            method: .post,
            body: ReplyBody(message: message, device_id: deviceId)
        )
    }

    /// Download invoice for an order (returns HTML)
    static func customerDownloadInvoice(orderId: String) -> APIEndpoint {
        APIEndpoint(path: "/api/customer/orders/\(orderId)/invoice")
    }
}

// MARK: - Customer Device Endpoints
extension APIEndpoint {
    /// Authorize a specific device for repair
    /// - Parameters:
    ///   - deviceId: The device ID to authorize
    ///   - authorized: Whether to authorize or reject
    ///   - signatureType: "typed" or "drawn"
    ///   - signatureData: The signature data
    static func customerAuthorizeDevice(
        deviceId: String,
        authorized: Bool,
        signatureType: String,
        signatureData: String
    ) -> APIEndpoint {
        struct AuthorizeBody: Encodable {
            let authorized: Bool
            let signature_type: String
            let signature_data: String
        }
        return APIEndpoint(
            path: "/api/customer/devices/\(deviceId)/authorize",
            method: .post,
            body: AuthorizeBody(
                authorized: authorized,
                signature_type: signatureType,
                signature_data: signatureData
            )
        )
    }

    /// Get device image URL for customer portal
    static func customerDeviceImage(deviceId: String, imageId: String) -> APIEndpoint {
        APIEndpoint(path: "/api/customer/devices/\(deviceId)/images/\(imageId)/file")
    }
}

// MARK: - Staff Enquiries Endpoints (uses /api/tickets backend)
extension APIEndpoint {
    /// Fetch paginated list of enquiries for staff
    static func enquiries(
        page: Int = 1,
        limit: Int = 20,
        status: String? = nil
    ) -> APIEndpoint {
        var params: [String: String] = [
            "page": String(page),
            "limit": String(limit)
        ]
        if let status = status { params["status"] = status }
        return APIEndpoint(path: "/api/tickets", queryParameters: params)
    }

    /// Fetch a single enquiry by ID
    static func enquiry(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/tickets/\(id)")
    }

    /// Fetch messages for an enquiry
    static func enquiryMessages(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/tickets/\(id)/messages")
    }

    /// Send a reply to an enquiry
    static func sendEnquiryReply(id: String, message: String) -> APIEndpoint {
        struct ReplyBody: Encodable { let message: String }
        return APIEndpoint(
            path: "/api/tickets/\(id)/messages",
            method: .post,
            body: ReplyBody(message: message)
        )
    }

    /// Fetch enquiry statistics for staff dashboard
    static func enquiryStatsEndpoint() -> APIEndpoint {
        APIEndpoint(path: "/api/tickets/stats")
    }

    /// Mark an enquiry as read
    static func markEnquiryRead(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/tickets/\(id)/read", method: .post)
    }

    /// Archive an enquiry
    static func archiveEnquiry(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/tickets/\(id)/archive", method: .post)
    }

    /// Mark an enquiry as spam
    static func markEnquirySpam(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/tickets/\(id)/spam", method: .post)
    }

    /// Convert an enquiry to an order
    static func convertEnquiryToOrder<T: Encodable>(id: String, body: T) -> APIEndpoint {
        APIEndpoint(path: "/api/tickets/\(id)/convert", method: .post, body: body)
    }

    /// Generate an AI reply for an enquiry
    static func generateEnquiryReply(id: String, locationId: String? = nil) -> APIEndpoint {
        struct GenerateBody: Encodable {
            let locationId: String?
            enum CodingKeys: String, CodingKey {
                case locationId = "location_id"
            }
        }
        return APIEndpoint(
            path: "/api/tickets/\(id)/generate-response",
            method: .post,
            body: GenerateBody(locationId: locationId)
        )
    }

    /// Execute a workflow on an enquiry
    static func executeEnquiryWorkflow(enquiryId: String, workflowId: String, variableOverrides: [String: String]? = nil) -> APIEndpoint {
        struct ExecuteBody: Encodable {
            let macroId: String
            let variableOverrides: [String: String]?
            enum CodingKeys: String, CodingKey {
                case macroId = "macro_id"
                case variableOverrides = "variable_overrides"
            }
        }
        return APIEndpoint(
            path: "/api/tickets/\(enquiryId)/macro",
            method: .post,
            body: ExecuteBody(macroId: workflowId, variableOverrides: variableOverrides)
        )
    }
}

// MARK: - Workflow (Macro) Endpoints
extension APIEndpoint {
    /// Fetch list of available workflows
    static func workflows(includeStages: Bool = true) -> APIEndpoint {
        var params: [String: String] = [:]
        if includeStages { params["include_stages"] = "true" }
        return APIEndpoint(path: "/api/macros", queryParameters: params)
    }

    /// Fetch a single workflow by ID
    static func workflow(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/macros/\(id)")
    }
}
