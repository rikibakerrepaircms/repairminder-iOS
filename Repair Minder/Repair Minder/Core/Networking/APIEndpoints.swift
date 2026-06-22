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
    case commissionEstimate(scope: String?, period: String?)
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
    case updateDeviceBankDetails(deviceId: String)
    case updateDeviceEngineer(deviceId: String)
    case updateDeviceSubLocation(deviceId: String)

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
    case orderDocument(orderId: String, type: DocumentType)

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
    case ticketRewriteResponse(id: String)
    case ticketMacroExecutions(id: String)
    case ticketExecuteMacro(id: String)
    case ticketPreviewMacro(id: String)
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
    case customerRegisterDeviceToken
    case customerUnregisterDeviceToken

    // MARK: - Product Types

    case productTypes(search: String)
    case productComponents(productTypeId: String)
    case quickCreateProductType

    // MARK: - Booking / Lookup

    case locations
    case deviceSearch(query: String)
    case deviceTypes
    case companyPublicInfo
    case aiReadiness

    // MARK: - POS Integrations & Terminals

    case posIntegrations
    case posTerminals(locationId: String?)

    // MARK: - POS Terminal Payments

    case initiateTerminalPayment
    case pollTerminalPayment(transactionId: String)
    case cancelTerminalPayment(transactionId: String)
    case refundTerminalPayment(transactionId: String)

    // MARK: - POS Payment Links

    case paymentLinks(orderId: String)
    case createPaymentLink
    case cancelPaymentLink(linkId: String)
    case resendPaymentLinkEmail(linkId: String)

    // MARK: - Buyback Inventory

    case buybackList(page: Int, limit: Int, status: String?, search: String?, locationId: String?, engineerId: String?)
    case buybackDetail(id: String)
    case buybackImageFile(imageId: String, width: Int?, height: Int?)

    // MARK: - Board Config

    case boardColumns(scope: String)
    case boardSeedDefaults
    case boardCardPositions(scope: String)
    case boardPlaceCard
    case boardCreateColumn
    case boardUpdateColumn(id: String)
    case boardDeleteColumn(id: String)
    case boardReorderColumns
    case boardCreateAction(columnId: String)
    case boardDeleteAction(columnId: String, actionId: String)
    case boardPinnedPreferences
    case boardUpdatePinnedPreference(columnId: String)

    // MARK: - Schedule

    case schedule(date: String)
    case teamSchedule(date: String)
    case updateScheduleItem(id: String)

    // MARK: - Customer Portal

    case customerOrders
    case customerOrder(orderId: String)
    case customerApproveQuote(orderId: String)
    case customerOrderReply(orderId: String)
    case customerOrderInvoice(orderId: String)
    case customerDeviceImage(deviceId: String, imageId: String)

    // MARK: - Diagnostics

    case diagnosticsPublicCreate
    case diagnosticsSubmitResult
    case diagnosticsComplete(sessionId: String)

    // MARK: - Path

    var path: String {
        switch self {
        // Diagnostics
        case .diagnosticsPublicCreate:
            return "/api/public/diagnostics/session"
        case .diagnosticsSubmitResult:
            return "/api/diagnostics/results"
        case .diagnosticsComplete(let sessionId):
            return "/api/diagnostics/session/\(sessionId)/complete"
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
        case .commissionEstimate:
            return "/api/dashboard/commission-estimate"
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
        case .deviceActions(_, let deviceId):
            return "/api/devices/\(deviceId)/actions"
        case .executeDeviceAction(_, let deviceId):
            return "/api/devices/\(deviceId)/action"
        case .updateDeviceBankDetails(let deviceId):
            return "/api/devices/\(deviceId)/bank-details"
        case .updateDeviceEngineer(let deviceId):
            return "/api/devices/\(deviceId)/engineer"
        case .updateDeviceSubLocation(let deviceId):
            return "/api/devices/\(deviceId)/sub-location"

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
        case .orderDocument(let orderId, let type):
            return "/api/orders/\(orderId)/documents/\(type.rawValue)"

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
        case .ticketRewriteResponse(let id):
            return "/api/tickets/\(id)/rewrite-response"
        case .ticketMacroExecutions(let id):
            return "/api/tickets/\(id)/macro-executions"
        case .ticketExecuteMacro(let id):
            return "/api/tickets/\(id)/macro"
        case .ticketPreviewMacro(let id):
            return "/api/tickets/\(id)/macro/preview"
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

        // Product Types
        case .productTypes:
            return "/api/product-types"
        case .productComponents(let productTypeId):
            return "/api/product-types/\(productTypeId)/components"
        case .quickCreateProductType:
            return "/api/product-types/quick-create"

        // Booking / Lookup
        case .locations:
            return "/api/locations"
        case .deviceSearch:
            return "/api/device-search"
        case .deviceTypes:
            return "/api/device-types"
        case .companyPublicInfo:
            return "/api/company/public-info"
        case .aiReadiness:
            return "/api/company/ai-readiness"

        // Push Notifications
        case .registerDeviceToken, .unregisterDeviceToken:
            return "/api/user/device-token"
        case .deviceTokens:
            return "/api/user/device-tokens"
        case .pushPreferences, .updatePushPreferences:
            return "/api/user/push-preferences"
        case .customerRegisterDeviceToken, .customerUnregisterDeviceToken:
            return "/api/customer/device-token"

        // POS
        case .posIntegrations:
            return "/api/pos/integrations"
        case .posTerminals:
            return "/api/pos/terminals"
        case .initiateTerminalPayment:
            return "/api/pos/payments"
        case .pollTerminalPayment(let id):
            return "/api/pos/payments/\(id)/status"
        case .cancelTerminalPayment(let id):
            return "/api/pos/payments/\(id)/cancel"
        case .refundTerminalPayment(let id):
            return "/api/pos/payments/\(id)/refund"
        case .paymentLinks, .createPaymentLink:
            return "/api/pos/payment-links"
        case .cancelPaymentLink(let id):
            return "/api/pos/payment-links/\(id)/cancel"
        case .resendPaymentLinkEmail(let id):
            return "/api/pos/payment-links/\(id)/resend"

        // Buyback Inventory
        case .buybackList:
            return "/api/buyback"
        case .buybackDetail(let id):
            return "/api/buyback/\(id)"
        case .buybackImageFile(let imageId, _, _):
            return "/api/buyback/images/\(imageId)/file"

        // Board Config
        case .boardColumns:
            return "/api/board/columns"
        case .boardSeedDefaults:
            return "/api/board/seed-defaults"
        case .boardCardPositions:
            return "/api/board/card-positions"
        case .boardPlaceCard:
            return "/api/board/card-positions"
        case .boardCreateColumn:
            return "/api/board/columns"
        case .boardUpdateColumn(let id):
            return "/api/board/columns/\(id)"
        case .boardDeleteColumn(let id):
            return "/api/board/columns/\(id)"
        case .boardReorderColumns:
            return "/api/board/columns/reorder"
        case .boardCreateAction(let columnId):
            return "/api/board/columns/\(columnId)/actions"
        case .boardDeleteAction(let columnId, let actionId):
            return "/api/board/columns/\(columnId)/actions/\(actionId)"
        case .boardPinnedPreferences:
            return "/api/board/pinned-preferences"
        case .boardUpdatePinnedPreference(let columnId):
            return "/api/board/pinned-preferences/\(columnId)"

        // Schedule
        case .schedule:
            return "/api/schedule"
        case .teamSchedule:
            return "/api/schedule/team"
        case .updateScheduleItem(let id):
            return "/api/schedule/items/\(id)"

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
             .dashboardStats, .commissionEstimate, .enquiryStats, .lifecycle, .categoryBreakdown, .activityLog,
             .bookingHeatmap, .buybackStats, .bookingsByTime,
             .devices, .myQueue, .myActiveWork, .orderDevices, .orderDevice, .deviceActions,
             .orders, .order, .orderItems, .orderPayments, .orderSignatures, .orderDocument,
             .clients, .client, .clientSearch, .clientsExport,
             .tickets, .ticket, .ticketMacroExecutions,
             .macros, .macro, .macroExecutions, .macroExecution,
             .productTypes, .productComponents,
             .locations, .deviceSearch, .deviceTypes, .companyPublicInfo, .aiReadiness,
             .deviceTokens, .pushPreferences,
             .posIntegrations, .posTerminals, .pollTerminalPayment, .paymentLinks,
             .boardColumns, .boardCardPositions,
             .schedule, .teamSchedule, .boardPinnedPreferences,
             .buybackList, .buybackDetail, .buybackImageFile,
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
             .createTicket, .ticketReply, .ticketNote, .ticketGenerateResponse, .ticketRewriteResponse, .ticketExecuteMacro, .ticketPreviewMacro,
             .ticketResolve, .ticketReassign, .createEnquiry,
             .registerDeviceToken, .customerRegisterDeviceToken,
             .initiateTerminalPayment, .cancelTerminalPayment, .refundTerminalPayment,
             .boardSeedDefaults, .boardPlaceCard,
             .boardCreateColumn, .boardCreateAction,
             .createPaymentLink, .cancelPaymentLink, .resendPaymentLinkEmail,
             .customerApproveQuote, .customerOrderReply,
             .quickCreateProductType,
             .diagnosticsPublicCreate, .diagnosticsSubmitResult, .diagnosticsComplete:
            return .post

        // PATCH endpoints
        case .updateOrderDevice, .updateDeviceStatus, .updateDeviceBankDetails,
             .updateDeviceEngineer, .updateDeviceSubLocation,
             .updateOrder, .updateOrderItem,
             .updateClient,
             .updateTicket,
             .pauseMacroExecution, .resumeMacroExecution,
             .boardUpdateColumn, .boardReorderColumns,
             .boardUpdatePinnedPreference, .updateScheduleItem:
            return .patch

        // PUT endpoints
        case .togglePasscodeEnabled, .passcodeTimeout,
             .updatePushPreferences:
            return .put

        // DELETE endpoints
        case .deleteOrderDevice, .deleteOrderItem, .deleteOrderPayment,
             .deleteClient,
             .unregisterDeviceToken, .customerUnregisterDeviceToken,
             .cancelMacroExecution,
             .boardDeleteColumn, .boardDeleteAction:
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

        case .commissionEstimate(let scope, let period):
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
            return [URLQueryItem(name: "email", value: query)]

        case .deviceSearch(let query):
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

        case .productTypes(let search):
            return [
                URLQueryItem(name: "search", value: search),
                URLQueryItem(name: "limit", value: "10"),
                URLQueryItem(name: "is_active", value: "true"),
                URLQueryItem(name: "product_kind", value: "product,service")
            ]

        case .posTerminals(let locationId):
            if let locationId {
                return [URLQueryItem(name: "location_id", value: locationId)]
            }
            return nil

        case .paymentLinks(let orderId):
            return [URLQueryItem(name: "order_id", value: orderId)]

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

        case .boardColumns(let scope):
            return [URLQueryItem(name: "scope", value: scope)]

        case .boardCardPositions(let scope):
            return [URLQueryItem(name: "scope", value: scope)]

        case .schedule(let date):
            return [URLQueryItem(name: "date", value: date)]

        case .teamSchedule(let date):
            return [URLQueryItem(name: "date", value: date)]

        case .buybackList(let page, let limit, let status, let search, let locationId, let engineerId):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            if let status = status {
                items.append(URLQueryItem(name: "status", value: status))
            }
            if let search = search, !search.isEmpty {
                items.append(URLQueryItem(name: "search", value: search))
            }
            if let locationId = locationId {
                items.append(URLQueryItem(name: "location_id", value: locationId))
            }
            if let engineerId = engineerId {
                items.append(URLQueryItem(name: "engineer_id", value: engineerId))
            }
            return items

        case .buybackImageFile(_, let width, let height):
            var items: [URLQueryItem] = []
            if let width = width {
                items.append(URLQueryItem(name: "w", value: String(width)))
            }
            if let height = height {
                items.append(URLQueryItem(name: "h", value: String(height)))
            }
            items.append(URLQueryItem(name: "format", value: "auto"))
            return items

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
             .createEnquiry,
             .diagnosticsPublicCreate, .diagnosticsSubmitResult, .diagnosticsComplete:
            return false
        default:
            return true
        }
    }
}
