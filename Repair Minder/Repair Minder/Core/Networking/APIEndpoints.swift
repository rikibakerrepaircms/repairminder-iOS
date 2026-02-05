//
//  APIEndpoints.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

/// HTTP methods supported by the API
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// All API endpoints with their paths and methods
enum APIEndpoint {

    // MARK: - Auth

    case login
    case twoFactorRequest
    case twoFactorVerify
    case magicLinkRequest
    case magicLinkVerifyCode
    case refreshToken
    case me
    case logout
    case totpSetup
    case totpVerifySetup
    case totpDisable
    case totpStatus

    // MARK: - Passcode

    case setPasscode
    case verifyPasscode
    case changePasscode
    case resetPasscodeRequest
    case resetPasscode
    case togglePasscodeEnabled
    case passcodeTimeout

    // MARK: - Customer Auth

    case customerMagicLinkRequest
    case customerVerifyCode
    case customerMe
    case customerLogout

    // MARK: - Dashboard

    case dashboardStats(scope: String?, period: String?)
    case enquiryStats(scope: String?, includeBreakdown: Bool?)
    case lifecycle
    case categoryBreakdown
    case activityLog
    case bookingHeatmap
    case buybackStats
    case bookingsByTime

    // MARK: - Devices

    case devices(filter: DeviceListFilter)
    case myQueue(page: Int, limit: Int, search: String?, category: String?)
    case myActiveWork
    case orderDevices(orderId: String)
    case createOrderDevice(orderId: String)
    case orderDevice(orderId: String, deviceId: String)
    case updateOrderDevice(orderId: String, deviceId: String)
    case deleteOrderDevice(orderId: String, deviceId: String)
    case updateDeviceStatus(orderId: String, deviceId: String)
    case deviceActions(orderId: String, deviceId: String)
    case executeDeviceAction(orderId: String, deviceId: String)

    // MARK: - Orders

    case orders(page: Int, limit: Int, status: String?)
    case createOrder
    case order(id: String)
    case updateOrder(id: String)
    case orderItems(orderId: String)
    case createOrderItem(orderId: String)
    case updateOrderItem(orderId: String, itemId: String)
    case deleteOrderItem(orderId: String, itemId: String)
    case orderPayments(orderId: String)
    case createOrderPayment(orderId: String)
    case deleteOrderPayment(orderId: String, paymentId: String)
    case orderSignatures(orderId: String)
    case createOrderSignature(orderId: String)
    case sendQuote(orderId: String)
    case authorizeOrder(orderId: String)
    case despatchOrder(orderId: String)
    case collectOrder(orderId: String)

    // MARK: - Clients

    case clients(page: Int, limit: Int, search: String?)
    case createClient
    case client(id: String)
    case updateClient(id: String)
    case deleteClient(id: String)
    case clientSearch(query: String)
    case clientsExport
    case clientsImport

    // MARK: - Tickets/Enquiries

    case tickets(page: Int, limit: Int, status: String?, ticketType: String?, locationId: String?, assignedUserId: String?, workflowStatus: String?, sortBy: String?, sortOrder: String?, search: String?)
    case createTicket
    case ticket(id: String)
    case updateTicket(id: String)
    case ticketReply(id: String)
    case ticketNote(id: String)
    case ticketGenerateResponse(id: String)
    case ticketMacroExecutions(id: String)
    case ticketExecuteMacro(id: String)
    case ticketResolve(id: String)
    case ticketReassign(id: String)
    case createEnquiry

    // MARK: - Macros

    case macros(category: String?, includeStages: Bool?)
    case macro(id: String)

    // MARK: - Macro Executions

    case macroExecutions(status: String?, ticketId: String?, page: Int?, perPage: Int?)
    case macroExecution(id: String)
    case pauseMacroExecution(id: String)
    case resumeMacroExecution(id: String)
    case cancelMacroExecution(id: String)

    // MARK: - Push Notifications

    case registerDeviceToken
    case unregisterDeviceToken
    case deviceTokens
    case pushPreferences
    case updatePushPreferences

    // MARK: - Customer Portal

    case customerOrders
    case customerOrder(orderId: String)
    case customerApproveQuote(orderId: String)
    case customerOrderReply(orderId: String)
    case customerOrderInvoice(orderId: String)
    case customerDeviceImage(deviceId: String, imageId: String)

    // MARK: - Path

    var path: String {
        switch self {
        // Auth
        case .login:
            return "/api/auth/login"
        case .twoFactorRequest:
            return "/api/auth/2fa/request"
        case .twoFactorVerify:
            return "/api/auth/2fa/verify"
        case .magicLinkRequest:
            return "/api/auth/magic-link/request"
        case .magicLinkVerifyCode:
            return "/api/auth/magic-link/verify-code"
        case .refreshToken:
            return "/api/auth/refresh"
        case .me:
            return "/api/auth/me"
        case .logout:
            return "/api/auth/logout"
        case .totpSetup:
            return "/api/auth/totp/setup"
        case .totpVerifySetup:
            return "/api/auth/totp/verify-setup"
        case .totpDisable:
            return "/api/auth/totp/disable"
        case .totpStatus:
            return "/api/auth/totp/status"

        // Passcode
        case .setPasscode:
            return "/api/auth/set-passcode"
        case .verifyPasscode:
            return "/api/auth/verify-passcode"
        case .changePasscode:
            return "/api/auth/change-passcode"
        case .resetPasscodeRequest:
            return "/api/auth/reset-passcode-request"
        case .resetPasscode:
            return "/api/auth/reset-passcode"
        case .togglePasscodeEnabled:
            return "/api/auth/toggle-passcode-enabled"
        case .passcodeTimeout:
            return "/api/user/passcode-timeout"

        // Customer Auth
        case .customerMagicLinkRequest:
            return "/api/customer/auth/request-magic-link"
        case .customerVerifyCode:
            return "/api/customer/auth/verify-code"
        case .customerMe:
            return "/api/customer/auth/me"
        case .customerLogout:
            return "/api/customer/auth/logout"

        // Dashboard
        case .dashboardStats:
            return "/api/dashboard/stats"
        case .enquiryStats:
            return "/api/dashboard/enquiry-stats"
        case .lifecycle:
            return "/api/dashboard/lifecycle"
        case .categoryBreakdown:
            return "/api/dashboard/category-breakdown"
        case .activityLog:
            return "/api/dashboard/activity-log"
        case .bookingHeatmap:
            return "/api/dashboard/booking-heatmap"
        case .buybackStats:
            return "/api/dashboard/buyback-stats"
        case .bookingsByTime:
            return "/api/dashboard/bookings-by-time"

        // Devices
        case .devices:
            return "/api/devices"
        case .myQueue:
            return "/api/devices/my-queue"
        case .myActiveWork:
            return "/api/devices/my-active-work"
        case .orderDevices(let orderId), .createOrderDevice(let orderId):
            return "/api/orders/\(orderId)/devices"
        case .orderDevice(let orderId, let deviceId),
             .updateOrderDevice(let orderId, let deviceId),
             .deleteOrderDevice(let orderId, let deviceId):
            return "/api/orders/\(orderId)/devices/\(deviceId)"
        case .updateDeviceStatus(let orderId, let deviceId):
            return "/api/orders/\(orderId)/devices/\(deviceId)/status"
        case .deviceActions(let orderId, let deviceId):
            return "/api/orders/\(orderId)/devices/\(deviceId)/actions"
        case .executeDeviceAction(let orderId, let deviceId):
            return "/api/orders/\(orderId)/devices/\(deviceId)/action"

        // Orders
        case .orders, .createOrder:
            return "/api/orders"
        case .order(let id), .updateOrder(let id):
            return "/api/orders/\(id)"
        case .orderItems(let orderId), .createOrderItem(let orderId):
            return "/api/orders/\(orderId)/items"
        case .updateOrderItem(let orderId, let itemId), .deleteOrderItem(let orderId, let itemId):
            return "/api/orders/\(orderId)/items/\(itemId)"
        case .orderPayments(let orderId), .createOrderPayment(let orderId):
            return "/api/orders/\(orderId)/payments"
        case .deleteOrderPayment(let orderId, let paymentId):
            return "/api/orders/\(orderId)/payments/\(paymentId)"
        case .orderSignatures(let orderId), .createOrderSignature(let orderId):
            return "/api/orders/\(orderId)/signatures"
        case .sendQuote(let orderId):
            return "/api/orders/\(orderId)/send-quote"
        case .authorizeOrder(let orderId):
            return "/api/orders/\(orderId)/authorize"
        case .despatchOrder(let orderId):
            return "/api/orders/\(orderId)/despatch"
        case .collectOrder(let orderId):
            return "/api/orders/\(orderId)/collect"

        // Clients
        case .clients, .createClient:
            return "/api/clients"
        case .client(let id), .updateClient(let id), .deleteClient(let id):
            return "/api/clients/\(id)"
        case .clientSearch:
            return "/api/clients/search"
        case .clientsExport:
            return "/api/clients/export"
        case .clientsImport:
            return "/api/clients/import"

        // Tickets
        case .tickets, .createTicket:
            return "/api/tickets"
        case .ticket(let id), .updateTicket(let id):
            return "/api/tickets/\(id)"
        case .ticketReply(let id):
            return "/api/tickets/\(id)/reply"
        case .ticketNote(let id):
            return "/api/tickets/\(id)/note"
        case .ticketGenerateResponse(let id):
            return "/api/tickets/\(id)/generate-response"
        case .ticketMacroExecutions(let id):
            return "/api/tickets/\(id)/macro-executions"
        case .ticketExecuteMacro(let id):
            return "/api/tickets/\(id)/macro"
        case .ticketResolve(let id):
            return "/api/tickets/\(id)/resolve"
        case .ticketReassign(let id):
            return "/api/tickets/\(id)/reassign"
        case .createEnquiry:
            return "/api/tickets/enquiry"

        // Macros
        case .macros:
            return "/api/macros"
        case .macro(let id):
            return "/api/macros/\(id)"

        // Macro Executions
        case .macroExecutions:
            return "/api/macro-executions"
        case .macroExecution(let id), .cancelMacroExecution(let id):
            return "/api/macro-executions/\(id)"
        case .pauseMacroExecution(let id):
            return "/api/macro-executions/\(id)/pause"
        case .resumeMacroExecution(let id):
            return "/api/macro-executions/\(id)/resume"

        // Push Notifications
        case .registerDeviceToken, .unregisterDeviceToken:
            return "/api/user/device-token"
        case .deviceTokens:
            return "/api/user/device-tokens"
        case .pushPreferences, .updatePushPreferences:
            return "/api/user/push-preferences"

        // Customer Portal
        case .customerOrders:
            return "/api/customer/orders"
        case .customerOrder(let orderId):
            return "/api/customer/orders/\(orderId)"
        case .customerApproveQuote(let orderId):
            return "/api/customer/orders/\(orderId)/approve"
        case .customerOrderReply(let orderId):
            return "/api/customer/orders/\(orderId)/reply"
        case .customerOrderInvoice(let orderId):
            return "/api/customer/orders/\(orderId)/invoice"
        case .customerDeviceImage(let deviceId, let imageId):
            return "/api/customer/devices/\(deviceId)/images/\(imageId)/file"
        }
    }

    // MARK: - Method

    var method: HTTPMethod {
        switch self {
        // GET endpoints
        case .me, .totpStatus,
             .customerMe,
             .dashboardStats, .enquiryStats, .lifecycle, .categoryBreakdown, .activityLog,
             .bookingHeatmap, .buybackStats, .bookingsByTime,
             .devices, .myQueue, .myActiveWork, .orderDevices, .orderDevice, .deviceActions,
             .orders, .order, .orderItems, .orderPayments, .orderSignatures,
             .clients, .client, .clientSearch, .clientsExport,
             .tickets, .ticket, .ticketMacroExecutions,
             .macros, .macro, .macroExecutions, .macroExecution,
             .deviceTokens, .pushPreferences,
             .customerOrders, .customerOrder, .customerOrderInvoice, .customerDeviceImage:
            return .get

        // POST endpoints
        case .login, .twoFactorRequest, .twoFactorVerify,
             .magicLinkRequest, .magicLinkVerifyCode, .refreshToken, .logout,
             .totpSetup, .totpVerifySetup, .totpDisable,
             .customerMagicLinkRequest, .customerVerifyCode, .customerLogout,
             .setPasscode, .verifyPasscode, .changePasscode,
             .resetPasscodeRequest, .resetPasscode,
             .createOrderDevice, .executeDeviceAction,
             .createOrder, .createOrderItem, .createOrderPayment, .createOrderSignature,
             .sendQuote, .authorizeOrder, .despatchOrder, .collectOrder,
             .createClient, .clientsImport,
             .createTicket, .ticketReply, .ticketNote, .ticketGenerateResponse, .ticketExecuteMacro,
             .ticketResolve, .ticketReassign, .createEnquiry,
             .registerDeviceToken,
             .customerApproveQuote, .customerOrderReply:
            return .post

        // PATCH endpoints
        case .updateOrderDevice, .updateDeviceStatus,
             .updateOrder, .updateOrderItem,
             .updateClient,
             .updateTicket,
             .pauseMacroExecution, .resumeMacroExecution:
            return .patch

        // PUT endpoints
        case .togglePasscodeEnabled, .passcodeTimeout,
             .updatePushPreferences:
            return .put

        // DELETE endpoints
        case .deleteOrderDevice, .deleteOrderItem, .deleteOrderPayment,
             .deleteClient,
             .unregisterDeviceToken,
             .cancelMacroExecution:
            return .delete
        }
    }

    // MARK: - Query Parameters

    /// Query parameters for GET requests
    var queryItems: [URLQueryItem]? {
        switch self {
        case .dashboardStats(let scope, let period):
            var items: [URLQueryItem] = []
            if let scope = scope {
                items.append(URLQueryItem(name: "scope", value: scope))
            }
            if let period = period {
                items.append(URLQueryItem(name: "period", value: period))
            }
            return items.isEmpty ? nil : items

        case .enquiryStats(let scope, let includeBreakdown):
            var items: [URLQueryItem] = []
            if let scope = scope {
                items.append(URLQueryItem(name: "scope", value: scope))
            }
            if let includeBreakdown = includeBreakdown, includeBreakdown {
                items.append(URLQueryItem(name: "include_breakdown", value: "true"))
            }
            return items.isEmpty ? nil : items

        case .myQueue(let page, let limit, let search, let category):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            if let search = search, !search.isEmpty {
                items.append(URLQueryItem(name: "search", value: search))
            }
            if let category = category, !category.isEmpty {
                items.append(URLQueryItem(name: "category", value: category))
            }
            return items

        case .devices(let filter):
            return filter.queryItems

        case .orders(let page, let limit, let status):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            if let status = status {
                items.append(URLQueryItem(name: "status", value: status))
            }
            return items

        case .clients(let page, let limit, let search):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            if let search = search {
                items.append(URLQueryItem(name: "search", value: search))
            }
            return items

        case .clientSearch(let query):
            return [URLQueryItem(name: "q", value: query)]

        case .tickets(let page, let limit, let status, let ticketType, let locationId, let assignedUserId, let workflowStatus, let sortBy, let sortOrder, let search):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            if let status = status {
                items.append(URLQueryItem(name: "status", value: status))
            }
            if let ticketType = ticketType {
                items.append(URLQueryItem(name: "ticket_type", value: ticketType))
            }
            if let locationId = locationId {
                items.append(URLQueryItem(name: "location_id", value: locationId))
            }
            if let assignedUserId = assignedUserId {
                items.append(URLQueryItem(name: "assigned_user_id", value: assignedUserId))
            }
            if let workflowStatus = workflowStatus {
                items.append(URLQueryItem(name: "workflow_status", value: workflowStatus))
            }
            if let sortBy = sortBy {
                items.append(URLQueryItem(name: "sort_by", value: sortBy))
            }
            if let sortOrder = sortOrder {
                items.append(URLQueryItem(name: "sort_order", value: sortOrder))
            }
            if let search = search, !search.isEmpty {
                items.append(URLQueryItem(name: "search", value: search))
            }
            return items

        case .macros(let category, let includeStages):
            var items: [URLQueryItem] = []
            if let category = category {
                items.append(URLQueryItem(name: "category", value: category))
            }
            if let includeStages = includeStages, includeStages {
                items.append(URLQueryItem(name: "include_stages", value: "true"))
            }
            return items.isEmpty ? nil : items

        case .macroExecutions(let status, let ticketId, let page, let perPage):
            var items: [URLQueryItem] = []
            if let status = status {
                items.append(URLQueryItem(name: "status", value: status))
            }
            if let ticketId = ticketId {
                items.append(URLQueryItem(name: "ticket_id", value: ticketId))
            }
            if let page = page {
                items.append(URLQueryItem(name: "page", value: String(page)))
            }
            if let perPage = perPage {
                items.append(URLQueryItem(name: "per_page", value: String(perPage)))
            }
            return items.isEmpty ? nil : items

        default:
            return nil
        }
    }

    // MARK: - Authentication Required

    /// Whether this endpoint requires authentication
    var requiresAuth: Bool {
        switch self {
        // Public endpoints (no auth required)
        case .login, .twoFactorRequest, .twoFactorVerify,
             .magicLinkRequest, .magicLinkVerifyCode, .refreshToken,
             .customerMagicLinkRequest, .customerVerifyCode,
             .createEnquiry:
            return false
        default:
            return true
        }
    }
}
