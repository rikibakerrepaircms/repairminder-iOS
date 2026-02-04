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
    static func registerDeviceToken(token: String) -> APIEndpoint {
        struct DeviceTokenBody: Encodable {
            let deviceToken: String
            let platform: String
        }
        return APIEndpoint(
            path: "/api/user/device-token",
            method: .post,
            body: DeviceTokenBody(deviceToken: token, platform: "ios")
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
}

// MARK: - Customer Portal Authentication Endpoints
extension APIEndpoint {
    /// Request a magic link code for customer authentication
    static func customerRequestMagicLink(email: String) -> APIEndpoint {
        struct MagicLinkBody: Encodable {
            let email: String
        }
        return APIEndpoint(
            path: "/api/customer/auth/request-magic-link",
            method: .post,
            body: MagicLinkBody(email: email)
        )
    }

    /// Verify the magic link code for customer
    static func customerVerifyCode(email: String, code: String) -> APIEndpoint {
        struct VerifyCodeBody: Encodable {
            let email: String
            let code: String
        }
        return APIEndpoint(
            path: "/api/customer/auth/verify-code",
            method: .post,
            body: VerifyCodeBody(email: email, code: code)
        )
    }

    /// Customer logout
    static func customerLogout() -> APIEndpoint {
        APIEndpoint(path: "/api/customer/auth/logout", method: .post)
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

    /// Get a specific customer order
    static func customerOrder(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/customer/orders/\(id)")
    }

    /// Get order timeline events
    static func customerOrderTimeline(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/customer/orders/\(id)/timeline")
    }

    /// Get order quote for approval
    static func customerOrderQuote(orderId: String) -> APIEndpoint {
        APIEndpoint(path: "/api/customer/orders/\(orderId)/quote")
    }

    /// Approve an order quote
    static func customerApproveQuote(orderId: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/customer/orders/\(orderId)/approve-quote",
            method: .post
        )
    }

    /// Reject an order quote
    static func customerRejectQuote(orderId: String, reason: String) -> APIEndpoint {
        struct RejectBody: Encodable {
            let reason: String
        }
        return APIEndpoint(
            path: "/api/customer/orders/\(orderId)/reject-quote",
            method: .post,
            body: RejectBody(reason: reason)
        )
    }
}

// MARK: - Customer Enquiries Endpoints
extension APIEndpoint {
    /// Get customer's enquiries
    static func customerEnquiries(page: Int = 1, limit: Int = 20) -> APIEndpoint {
        APIEndpoint(
            path: "/api/customer/enquiries",
            queryParameters: ["page": String(page), "limit": String(limit)]
        )
    }

    /// Get a specific enquiry
    static func customerEnquiry(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/customer/enquiries/\(id)")
    }

    /// Submit a new enquiry
    static func customerSubmitEnquiry(
        shopId: String,
        deviceType: String,
        deviceBrand: String,
        deviceModel: String,
        issueDescription: String,
        preferredContact: String
    ) -> APIEndpoint {
        struct EnquiryBody: Encodable {
            let shopId: String
            let deviceType: String
            let deviceBrand: String
            let deviceModel: String
            let issueDescription: String
            let preferredContact: String
        }
        return APIEndpoint(
            path: "/api/customer/enquiries",
            method: .post,
            body: EnquiryBody(
                shopId: shopId,
                deviceType: deviceType,
                deviceBrand: deviceBrand,
                deviceModel: deviceModel,
                issueDescription: issueDescription,
                preferredContact: preferredContact
            )
        )
    }

    /// Reply to an enquiry
    static func customerEnquiryReply(enquiryId: String, message: String) -> APIEndpoint {
        struct ReplyBody: Encodable {
            let message: String
        }
        return APIEndpoint(
            path: "/api/customer/enquiries/\(enquiryId)/reply",
            method: .post,
            body: ReplyBody(message: message)
        )
    }
}

// MARK: - Customer Shops Endpoints
extension APIEndpoint {
    /// Get customer's previous shops
    static func customerShops() -> APIEndpoint {
        APIEndpoint(path: "/api/customer/shops")
    }
}

// MARK: - Customer Messages Endpoints
extension APIEndpoint {
    /// Get customer's conversations/messages
    static func customerConversations() -> APIEndpoint {
        APIEndpoint(path: "/api/customer/messages")
    }

    /// Get messages for a specific order
    static func customerOrderMessages(orderId: String) -> APIEndpoint {
        APIEndpoint(path: "/api/customer/orders/\(orderId)/messages")
    }

    /// Send a message for an order
    static func customerSendMessage(orderId: String, message: String) -> APIEndpoint {
        struct MessageBody: Encodable {
            let message: String
        }
        return APIEndpoint(
            path: "/api/customer/orders/\(orderId)/messages",
            method: .post,
            body: MessageBody(message: message)
        )
    }
}

// MARK: - Staff Enquiries Endpoints
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
        return APIEndpoint(path: "/api/enquiries", queryParameters: params)
    }

    /// Fetch a single enquiry by ID
    static func enquiry(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/enquiries/\(id)")
    }

    /// Fetch messages for an enquiry
    static func enquiryMessages(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/enquiries/\(id)/messages")
    }

    /// Send a reply to an enquiry
    static func sendEnquiryReply(id: String, message: String) -> APIEndpoint {
        struct ReplyBody: Encodable { let message: String }
        return APIEndpoint(
            path: "/api/enquiries/\(id)/messages",
            method: .post,
            body: ReplyBody(message: message)
        )
    }

    /// Fetch enquiry statistics for staff dashboard
    static func enquiryStatsEndpoint() -> APIEndpoint {
        APIEndpoint(path: "/api/enquiries/stats")
    }

    /// Mark an enquiry as read
    static func markEnquiryRead(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/enquiries/\(id)/read", method: .post)
    }

    /// Archive an enquiry
    static func archiveEnquiry(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/enquiries/\(id)/archive", method: .post)
    }

    /// Mark an enquiry as spam
    static func markEnquirySpam(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/enquiries/\(id)/spam", method: .post)
    }

    /// Convert an enquiry to an order
    static func convertEnquiryToOrder<T: Encodable>(id: String, body: T) -> APIEndpoint {
        APIEndpoint(path: "/api/enquiries/\(id)/convert", method: .post, body: body)
    }
}
