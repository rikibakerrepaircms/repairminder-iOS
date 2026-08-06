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
    case returnDeviceAccessory(orderId: String, deviceId: String, accessoryId: String)
    case cancelDeviceWork(deviceId: String)
    case deviceChecklistTemplates(orderId: String, deviceId: String, checklistType: String)
    case completeDeviceChecklist(orderId: String, deviceId: String)
    case deviceQCRequirements(deviceId: String)
    case deviceQC(deviceId: String)
    case staffAuthorizeDevice(deviceId: String)
    case collectDevice(deviceId: String)
    case despatchDevice(deviceId: String)
    case deviceReadyForCollection(deviceId: String)
    case addDeviceAccessory(orderId: String, deviceId: String)
    case deviceCompletionData(deviceId: String)
    case devicePendingItemsCount(deviceId: String)
    case deviceReport(orderId: String, deviceId: String)

    // Device Images
    case deviceImages(orderId: String, deviceId: String)
    case uploadDeviceImage(orderId: String, deviceId: String)
    case deleteDeviceImage(orderId: String, deviceId: String, imageId: String)
    case deviceImageFile(orderId: String, deviceId: String, imageId: String, width: Int?, height: Int?)

    // MARK: - Orders

    case orders(page: Int, limit: Int, status: String?, paymentStatus: String?, locationId: String?, assignedUserId: String?, search: String?)
    case createOrder
    case order(id: String)
    case updateOrder(id: String)
    case setOrderDiscount(orderId: String)
    case orderItems(orderId: String)
    case createOrderItem(orderId: String)
    case rmcheckLookup
    case rmcheckFmi
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
    case orderRefunds(orderId: String)
    case createOrderRefund(orderId: String)
    case deleteOrderRefund(orderId: String, refundId: String)
    case createTicketNote(ticketId: String)
    case orderDocument(orderId: String, type: DocumentType)

    // Orders — admin extras (Package G)
    case updatePurchaseOrder(orderId: String)
    case setOrderBillingGroup(orderId: String)
    case recreateOrder(orderId: String)

    // MARK: - Clients

    case clients(page: Int, limit: Int, search: String?)
    case createClient
    case client(id: String)
    case updateClient(id: String)
    case deleteClient(id: String)
    case clientSearch(query: String)
    case clientsExport
    case clientsImport
    case clientGroupsForClient(clientId: String)

    // MARK: - Tickets/Enquiries

    case tickets(page: Int, limit: Int, status: String?, ticketType: String?, locationId: String?, assignedUserId: String?, workflowStatus: String?, sortBy: String?, sortOrder: String?, search: String?)
    case createTicket
    case ticket(id: String)
    case updateTicket(id: String)
    case ticketReply(id: String)
    /// Staff offer a two-hour doorstep collection window. POST { date, start_time }.
    case ticketOfferCollectionSlot(id: String)
    case ticketNote(id: String)
    case ticketGenerateResponse(id: String)
    case ticketRewriteResponse(id: String)
    case ticketGenerateResponseStatus(id: String)
    case ticketRewriteResponseStatus(id: String)
    case ticketMacroExecutions(id: String)
    case ticketExecuteMacro(id: String)
    case ticketPreviewMacro(id: String)
    case ticketSuggestQuote(id: String)
    case ticketSuggestQuoteStatus(id: String)
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
    case pushPreferences
    case updatePushPreferences
    case customerRegisterDeviceToken
    case customerUnregisterDeviceToken

    // MARK: - Product Types

    case productTypes(search: String)
    /// Product-type search scoped for the asset filter picker (inventory-kind aware).
    /// Unlike `.productTypes`, this does NOT restrict `product_kind` — assets commonly
    /// reference `inventory_item`-kind product types via `product_type_id`.
    case assetFilterProductTypes(search: String?)
    case productComponents(productTypeId: String)
    case quickCreateProductType

    // MARK: - Kiosk POS

    case createKioskOrder
    case cancelKioskOrder(id: String)
    case kioskAvailableAssets(productTypeId: String?, groupId: String?, search: String?)
    case productTypeBySku(sku: String)
    case kioskProductList(page: Int, limit: Int, category: String?, search: String?)
    case kioskProductCategories
    case productTypeImage(id: String)

    // MARK: - Booking / Lookup

    case locations
    case locationSubLocations(locationId: String)
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
    case updateBuyback(buybackId: String)
    case buybackImageFile(imageId: String, width: Int?, height: Int?)
    // Phase 3 — Buyback lifecycle (write actions)
    case updateBuybackStatus(id: String)
    case buybackNotes(id: String)
    case addBuybackNote(id: String)
    case sellBuyback(id: String)
    case sellBuybackBulk
    case addDeviceToBuyback(deviceId: String)
    // Refurbishment items
    case addRefurbishmentItem(id: String)
    case updateRefurbishmentItem(id: String, itemId: String)
    case deleteRefurbishmentItem(id: String, itemId: String)
    // AI listing generation (job-poll)
    case generateBuybackListing(id: String)
    case buybackListingStatus(id: String)
    // Image management (Package D)
    case buybackImages(id: String, imageType: String?)
    case uploadBuybackSourceImage(id: String)
    case generateBuybackProductPhotos(id: String)
    case setBuybackImageFinal(imageId: String)
    case deleteBuybackImage(imageId: String)

    // MARK: - Inventory / Assets

    case inventoryList(page: Int, limit: Int, status: String?, category: String?, locationId: String?, subLocationId: String?, productTypeId: String?, groupId: String?, hasGroups: Bool?, hasProducts: Bool?, search: String?)
    case inventoryDetail(id: String)
    case inventoryByTag(tag: String)
    case inventoryActivity(id: String, limit: Int?)
    case inventoryAssetGroups(id: String)
    case inventoryExternalDeployment(id: String)
    case productTypeCategories
    case assetGroupsList(page: Int, limit: Int, search: String?, category: String?, hasProducts: Bool?, unlinkedOnly: Bool?, sortBy: String?, sortOrder: String?)
    // Phase 3 — Inventory Groups
    case assetGroup(id: String)
    case assetGroupAssets(id: String, page: Int, limit: Int)
    case assetGroupProducts(id: String)
    case addMembership
    case removeMembership(id: String)
    case bulkAssignGroups(assetId: String)
    case promoteGroup
    case createProductType
    case updateProductType(id: String)

    // Inventory / Assets — write actions (Phase 2)
    case updateAsset(id: String)
    case moveAsset(id: String)
    case allocateAsset(id: String)
    case deployExternalAsset(id: String)
    case returnExternalAsset(id: String)
    case returnToSupplierAsset(id: String)
    case resolveSupplierReturn(id: String)
    case deleteAsset(id: String)

    // Inventory / Assets — Phase 4 (bulk, analytics, book-in, salvage)
    case bulkReturnToSupplier
    case stockSummary
    case assetHierarchy(status: String?)
    case lowStock
    case importAssets
    case supplierOrders(page: Int, limit: Int, supplier: String?, status: String?)
    case supplierOrder(id: String)
    case createSupplierOrder
    case updateSupplierOrder(id: String)
    case deleteSupplierOrder(id: String)
    case addSupplierOrderLine(orderId: String)
    case updateSupplierOrderLine(orderId: String, lineId: String)
    case deleteSupplierOrderLine(orderId: String, lineId: String)
    case receiveSupplierOrder(id: String)
    case extractInvoice
    case supplierMappingsSuppliers
    case salvageBuyback(id: String)
    case deleteSalvageItem(buybackId: String, assetId: String)

    // MARK: - Buyback Marketplace

    case marketplaceSearches
    case createMarketplaceSearch
    case updateMarketplaceSearch(id: Int)
    case deleteMarketplaceSearch(id: Int)
    case marketplaceListings(limit: Int, before: String?, beforeId: String?, searchId: Int?, status: String?)
    case setMarketplaceListingStatus(id: String)
    case marketplaceBlockedSellers
    case blockMarketplaceSeller
    case unblockMarketplaceSeller(sellerFbId: String)

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
    case customerCompetitionEntries
    case customerMarketingPreferences
    case customerRequestWithdrawal(campaignId: String)

    // MARK: - Diagnostics

    case diagnosticsPublicCreate
    case diagnosticsSubmitResult
    case diagnosticsComplete(sessionId: String)
    case diagnosticsResume(sessionId: String)
    /// Server-rendered HTML report for a session (single source for the PDF report — see
    /// `DiagnosticReportShare`). Raw text, not JSON — fetched via `APIClient.requestRawText`.
    case diagnosticsReport(sessionId: String, token: String)
    /// Session status + results (dual-auth: session token here, or staff JWT elsewhere) — used to
    /// check whether a session persisted by `DiagnosticsResumeStore` is still resumable after an
    /// app relaunch. JSON envelope (not raw text, unlike `diagnosticsReport`).
    case diagnosticsGetSession(sessionId: String, token: String)

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
        case .diagnosticsResume(let sessionId):
            return "/api/diagnostics/session/\(sessionId)/resume"
        case .diagnosticsReport(let sessionId, let token):
            let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
            return "/api/diagnostics/session/\(sessionId)/report?token=\(encodedToken)"
        case .diagnosticsGetSession(let sessionId, let token):
            let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
            return "/api/diagnostics/session/\(sessionId)?token=\(encodedToken)"
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
        case .returnDeviceAccessory(let orderId, let deviceId, let accessoryId):
            return "/api/orders/\(orderId)/devices/\(deviceId)/accessories/\(accessoryId)/return"
        case .cancelDeviceWork(let deviceId):
            return "/api/devices/\(deviceId)/cancel-work"
        case .deviceChecklistTemplates(let orderId, let deviceId, _):
            return "/api/orders/\(orderId)/devices/\(deviceId)/checklists/templates"
        case .completeDeviceChecklist(let orderId, let deviceId):
            return "/api/orders/\(orderId)/devices/\(deviceId)/checklists"
        case .deviceQCRequirements(let deviceId):
            return "/api/devices/\(deviceId)/qc-requirements"
        case .deviceQC(let deviceId):
            return "/api/devices/\(deviceId)/qc"
        case .staffAuthorizeDevice(let deviceId):
            return "/api/devices/\(deviceId)/staff-authorize"
        case .collectDevice(let deviceId):
            return "/api/devices/\(deviceId)/collect"
        case .despatchDevice(let deviceId):
            return "/api/devices/\(deviceId)/despatch"
        case .deviceReadyForCollection(let deviceId):
            return "/api/devices/\(deviceId)/ready-for-collection"
        case .addDeviceAccessory(let orderId, let deviceId):
            return "/api/orders/\(orderId)/devices/\(deviceId)/accessories"
        case .deviceCompletionData(let deviceId):
            return "/api/devices/\(deviceId)/completion-data"
        case .devicePendingItemsCount(let deviceId):
            return "/api/devices/\(deviceId)/pending-items-count"
        case .deviceReport(let orderId, let deviceId):
            return "/api/orders/\(orderId)/devices/\(deviceId)/report"
        case .deviceImages(let orderId, let deviceId),
             .uploadDeviceImage(let orderId, let deviceId):
            return "/api/orders/\(orderId)/devices/\(deviceId)/images"
        case .deleteDeviceImage(let orderId, let deviceId, let imageId):
            return "/api/orders/\(orderId)/devices/\(deviceId)/images/\(imageId)"
        case .deviceImageFile(let orderId, let deviceId, let imageId, _, _):
            return "/api/orders/\(orderId)/devices/\(deviceId)/images/\(imageId)/file"

        // Orders
        case .orders, .createOrder:
            return "/api/orders"
        case .order(let id), .updateOrder(let id):
            return "/api/orders/\(id)"
        case .setOrderDiscount(let orderId):
            return "/api/orders/\(orderId)/discount"
        case .orderItems(let orderId), .createOrderItem(let orderId):
            return "/api/orders/\(orderId)/items"
        case .rmcheckLookup:
            return "/api/rmcheck/lookup"
        case .rmcheckFmi:
            return "/api/rmcheck/fmi"
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
        case .orderRefunds(let orderId), .createOrderRefund(let orderId):
            return "/api/orders/\(orderId)/refunds"
        case .deleteOrderRefund(let orderId, let refundId):
            return "/api/orders/\(orderId)/refunds/\(refundId)"
        case .createTicketNote(let ticketId):
            return "/api/tickets/\(ticketId)/note"
        case .orderDocument(let orderId, let type):
            return "/api/orders/\(orderId)/documents/\(type.rawValue)"
        case .updatePurchaseOrder(let orderId):
            return "/api/orders/\(orderId)/purchase-order"
        case .setOrderBillingGroup(let orderId):
            return "/api/orders/\(orderId)/billing-group"
        case .recreateOrder(let orderId):
            return "/api/orders/\(orderId)/recreate"

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
        case .clientGroupsForClient(let clientId):
            return "/api/clients/\(clientId)/groups"

        // Tickets
        case .tickets, .createTicket:
            return "/api/tickets"
        case .ticket(let id), .updateTicket(let id):
            return "/api/tickets/\(id)"
        case .ticketReply(let id):
            return "/api/tickets/\(id)/reply"
        case .ticketOfferCollectionSlot(let id):
            return "/api/tickets/\(id)/collection-slot/offer"
        case .ticketNote(let id):
            return "/api/tickets/\(id)/note"
        case .ticketGenerateResponse(let id):
            return "/api/tickets/\(id)/generate-response"
        case .ticketRewriteResponse(let id):
            return "/api/tickets/\(id)/rewrite-response"
        case .ticketGenerateResponseStatus(let id):
            return "/api/tickets/\(id)/generate-response"
        case .ticketRewriteResponseStatus(let id):
            return "/api/tickets/\(id)/rewrite-response"
        case .ticketMacroExecutions(let id):
            return "/api/tickets/\(id)/macro-executions"
        case .ticketExecuteMacro(let id):
            return "/api/tickets/\(id)/macro"
        case .ticketPreviewMacro(let id):
            return "/api/tickets/\(id)/macro/preview"
        case .ticketSuggestQuote(let id):
            return "/api/tickets/\(id)/macro/suggest-quote"
        case .ticketSuggestQuoteStatus(let id):
            return "/api/tickets/\(id)/macro/suggest-quote"
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
        case .productTypes, .assetFilterProductTypes:
            return "/api/product-types"
        case .productComponents(let productTypeId):
            return "/api/product-types/\(productTypeId)/components"
        case .quickCreateProductType:
            return "/api/product-types/quick-create"

        // Kiosk POS
        case .createKioskOrder:
            return "/api/orders/kiosk"
        case .cancelKioskOrder(let id):
            return "/api/orders/\(id)/kiosk-cancel"
        case .kioskAvailableAssets:
            return "/api/kiosk/available-assets"
        case .productTypeBySku(let sku):
            return "/api/product-types/by-sku/\(sku)"
        case .kioskProductList:
            return "/api/product-types"
        case .kioskProductCategories:
            return "/api/product-types/categories"
        case .productTypeImage(let id):
            return "/api/product-types/\(id)/image"

        // Booking / Lookup
        case .locations:
            return "/api/locations"
        case .locationSubLocations(let locationId):
            return "/api/locations/\(locationId)/sub-locations"
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
        case .updateBuyback(let buybackId):
            return "/api/buyback/\(buybackId)"
        case .buybackImageFile(let imageId, _, _):
            return "/api/buyback/images/\(imageId)/file"
        case .updateBuybackStatus(let id):
            return "/api/buyback/\(id)/status"
        case .buybackNotes(let id), .addBuybackNote(let id):
            return "/api/buyback/\(id)/notes"
        case .sellBuyback(let id):
            return "/api/buyback/\(id)/sell"
        case .sellBuybackBulk:
            return "/api/buyback/sell-bulk"
        case .addDeviceToBuyback(let deviceId):
            return "/api/devices/\(deviceId)/add-to-buyback"
        case .addRefurbishmentItem(let id):
            return "/api/buyback/\(id)/refurbishment"
        case .updateRefurbishmentItem(let id, let itemId), .deleteRefurbishmentItem(let id, let itemId):
            return "/api/buyback/\(id)/refurbishment/\(itemId)"
        case .generateBuybackListing(let id), .buybackListingStatus(let id):
            return "/api/buyback/\(id)/generate-listing"
        case .buybackImages(let id, _):
            return "/api/buyback/\(id)/images"
        case .uploadBuybackSourceImage(let id):
            return "/api/buyback/\(id)/source-images"
        case .generateBuybackProductPhotos(let id):
            return "/api/buyback/\(id)/product-photos"
        case .setBuybackImageFinal(let imageId):
            return "/api/buyback/images/\(imageId)/final"
        case .deleteBuybackImage(let imageId):
            return "/api/buyback/images/\(imageId)"

        // Inventory / Assets
        case .inventoryList: return "/api/assets"
        case .inventoryDetail(let id): return "/api/assets/\(id)"
        case .inventoryByTag(let tag): return "/api/assets/tag/\(tag)"
        case .inventoryActivity(let id, _): return "/api/assets/\(id)/activity"
        case .inventoryAssetGroups(let id): return "/api/assets/\(id)/groups"
        case .inventoryExternalDeployment(let id): return "/api/assets/\(id)/external-deployment"
        case .productTypeCategories: return "/api/product-types/categories"
        case .assetGroupsList: return "/api/asset-groups"
        case .assetGroup(let id): return "/api/asset-groups/\(id)"
        case .assetGroupAssets(let id, _, _): return "/api/asset-groups/\(id)/assets"
        case .assetGroupProducts(let id): return "/api/asset-groups/\(id)/products"
        case .addMembership: return "/api/asset-groups/memberships"
        case .removeMembership(let id): return "/api/asset-groups/memberships/\(id)"
        case .bulkAssignGroups(let assetId): return "/api/assets/\(assetId)/groups"
        case .promoteGroup: return "/api/asset-groups/promote"
        case .createProductType: return "/api/product-types"
        case .updateProductType(let id): return "/api/product-types/\(id)"
        case .updateAsset(let id): return "/api/assets/\(id)"
        case .moveAsset(let id): return "/api/assets/\(id)/move"
        case .allocateAsset(let id): return "/api/assets/\(id)/allocate"
        case .deployExternalAsset(let id): return "/api/assets/\(id)/deploy-external"
        case .returnExternalAsset(let id): return "/api/assets/\(id)/return-external"
        case .returnToSupplierAsset(let id): return "/api/assets/\(id)/return-to-supplier"
        case .resolveSupplierReturn(let id): return "/api/assets/\(id)/resolve-supplier-return"
        case .deleteAsset(let id): return "/api/assets/\(id)"
        case .bulkReturnToSupplier: return "/api/assets/bulk-return-to-supplier"
        case .stockSummary: return "/api/assets/stock-summary"
        case .assetHierarchy: return "/api/assets/hierarchy"
        case .lowStock: return "/api/assets/low-stock"
        case .importAssets: return "/api/assets/import"
        case .supplierOrders: return "/api/supplier-orders"
        case .supplierOrder(let id): return "/api/supplier-orders/\(id)"
        case .createSupplierOrder: return "/api/supplier-orders"
        case .updateSupplierOrder(let id): return "/api/supplier-orders/\(id)"
        case .deleteSupplierOrder(let id): return "/api/supplier-orders/\(id)"
        case .addSupplierOrderLine(let orderId): return "/api/supplier-orders/\(orderId)/lines"
        case .updateSupplierOrderLine(let orderId, let lineId): return "/api/supplier-orders/\(orderId)/lines/\(lineId)"
        case .deleteSupplierOrderLine(let orderId, let lineId): return "/api/supplier-orders/\(orderId)/lines/\(lineId)"
        case .receiveSupplierOrder(let id): return "/api/supplier-orders/\(id)/receive"
        case .extractInvoice: return "/api/supplier-orders/extract-invoice"
        case .supplierMappingsSuppliers: return "/api/supplier-mappings/suppliers"
        case .salvageBuyback(let id): return "/api/buyback/\(id)/salvage"
        case .deleteSalvageItem(let buybackId, let assetId): return "/api/buyback/\(buybackId)/salvage/\(assetId)"

        // Buyback Marketplace
        case .marketplaceSearches, .createMarketplaceSearch:
            return "/api/buyback/marketplace/searches"
        case .updateMarketplaceSearch(let id), .deleteMarketplaceSearch(let id):
            return "/api/buyback/marketplace/searches/\(id)"
        case .marketplaceListings:
            return "/api/buyback/marketplace/listings"
        case .setMarketplaceListingStatus(let id):
            return "/api/buyback/marketplace/listings/\(id)/status"
        case .marketplaceBlockedSellers, .blockMarketplaceSeller:
            return "/api/buyback/marketplace/blocked-sellers"
        case .unblockMarketplaceSeller(let sellerFbId):
            return "/api/buyback/marketplace/blocked-sellers/\(sellerFbId)"

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
        case .customerCompetitionEntries:
            return "/api/customer/marketing/entries"
        case .customerMarketingPreferences:
            return "/api/customer/marketing/preferences"
        case .customerRequestWithdrawal(let campaignId):
            return "/api/customer/marketing/entries/\(campaignId)/withdraw-request"
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
             .deviceChecklistTemplates, .deviceQCRequirements,
             .deviceCompletionData, .devicePendingItemsCount, .deviceReport,
             .deviceImages, .deviceImageFile(_, _, _, _, _),
             .orders, .order, .orderItems, .orderPayments, .orderSignatures, .orderRefunds, .orderDocument,
             .clients, .client, .clientSearch, .clientsExport, .clientGroupsForClient,
             .tickets, .ticket, .ticketMacroExecutions,
             .ticketGenerateResponseStatus, .ticketRewriteResponseStatus, .ticketSuggestQuoteStatus,
             .macros, .macro, .macroExecutions, .macroExecution,
             .productTypes, .assetFilterProductTypes, .productComponents, .productTypeBySku,
             .kioskProductList, .kioskProductCategories, .productTypeImage,
             .kioskAvailableAssets,
             .locations, .locationSubLocations, .deviceSearch, .deviceTypes, .companyPublicInfo, .aiReadiness,
             .pushPreferences,
             .posIntegrations, .posTerminals, .pollTerminalPayment, .paymentLinks,
             .boardColumns, .boardCardPositions,
             .schedule, .teamSchedule, .boardPinnedPreferences,
             .buybackList, .buybackDetail, .buybackImageFile, .buybackNotes, .buybackListingStatus,
             .buybackImages,
             .inventoryList, .inventoryDetail, .inventoryByTag, .inventoryActivity,
             .inventoryAssetGroups, .inventoryExternalDeployment, .productTypeCategories, .assetGroupsList,
             .assetGroup, .assetGroupAssets, .assetGroupProducts,
             .stockSummary, .assetHierarchy, .lowStock,
             .supplierOrders, .supplierOrder, .supplierMappingsSuppliers,
             .customerOrders, .customerOrder, .customerOrderInvoice, .customerDeviceImage,
             .customerCompetitionEntries, .customerMarketingPreferences,
             .marketplaceSearches, .marketplaceListings, .marketplaceBlockedSellers,
             .diagnosticsReport, .diagnosticsGetSession:
            return .get

        // POST endpoints
        case .login, .twoFactorRequest, .twoFactorVerify,
             .magicLinkRequest, .magicLinkVerifyCode, .refreshToken, .logout,
             .totpSetup, .totpVerifySetup, .totpDisable,
             .customerMagicLinkRequest, .customerVerifyCode, .customerLogout,
             .setPasscode, .verifyPasscode, .changePasscode,
             .resetPasscodeRequest, .resetPasscode,
             .createOrderDevice, .executeDeviceAction, .uploadDeviceImage,
             .createOrder, .createOrderItem, .createOrderPayment, .createOrderSignature,
             .rmcheckLookup,
             .rmcheckFmi,
             .sendQuote, .authorizeOrder, .despatchOrder, .collectOrder,
             .createOrderRefund, .createTicketNote, .recreateOrder,
             .createClient, .clientsImport,
             .createTicket, .ticketReply, .ticketOfferCollectionSlot, .ticketNote, .ticketGenerateResponse, .ticketRewriteResponse, .ticketExecuteMacro, .ticketPreviewMacro, .ticketSuggestQuote,
             .ticketResolve, .ticketReassign, .createEnquiry,
             .registerDeviceToken, .customerRegisterDeviceToken,
             .initiateTerminalPayment, .cancelTerminalPayment, .refundTerminalPayment,
             .boardSeedDefaults, .boardPlaceCard,
             .boardCreateColumn, .boardCreateAction,
             .createPaymentLink, .cancelPaymentLink, .resendPaymentLinkEmail,
             .customerApproveQuote, .customerOrderReply,
             .quickCreateProductType,
             .diagnosticsPublicCreate, .diagnosticsSubmitResult, .diagnosticsComplete, .diagnosticsResume,
             .moveAsset, .allocateAsset, .deployExternalAsset,
             .returnExternalAsset, .returnToSupplierAsset, .resolveSupplierReturn,
             .addMembership, .bulkAssignGroups, .promoteGroup, .createProductType,
             .bulkReturnToSupplier, .importAssets, .createSupplierOrder,
             .addSupplierOrderLine, .receiveSupplierOrder, .extractInvoice,
             .salvageBuyback, .cancelDeviceWork, .completeDeviceChecklist, .deviceQC,
             .addBuybackNote, .sellBuyback, .sellBuybackBulk, .addDeviceToBuyback,
             .createKioskOrder, .staffAuthorizeDevice,
             .addRefurbishmentItem, .generateBuybackListing,
             .uploadBuybackSourceImage, .generateBuybackProductPhotos, .setBuybackImageFinal,
             .collectDevice, .despatchDevice, .deviceReadyForCollection, .addDeviceAccessory,
             .customerRequestWithdrawal,
             .createMarketplaceSearch, .blockMarketplaceSeller:
            return .post

        // PATCH endpoints
        case .updateOrderDevice, .updateDeviceStatus, .updateDeviceBankDetails,
             .updateDeviceEngineer, .updateDeviceSubLocation, .updateBuyback, .updateBuybackStatus,
             .returnDeviceAccessory,
             .updateOrder, .setOrderDiscount, .updateOrderItem, .setOrderBillingGroup,
             .updateClient,
             .updateTicket,
             .pauseMacroExecution, .resumeMacroExecution,
             .boardUpdateColumn, .boardReorderColumns,
             .boardUpdatePinnedPreference, .updateScheduleItem,
             .updateSupplierOrder, .updateRefurbishmentItem,
             .updateMarketplaceSearch, .setMarketplaceListingStatus:
            return .patch

        // PUT endpoints
        case .togglePasscodeEnabled, .passcodeTimeout,
             .updatePushPreferences, .updateAsset, .updateProductType,
             .updateSupplierOrderLine, .updatePurchaseOrder:
            return .put

        // DELETE endpoints
        case .deleteOrderDevice, .deleteOrderItem, .deleteOrderPayment,
             .deleteClient,
             .unregisterDeviceToken, .customerUnregisterDeviceToken,
             .cancelMacroExecution,
             .boardDeleteColumn, .boardDeleteAction,
             .deleteDeviceImage, .deleteAsset, .removeMembership,
             .deleteSupplierOrderLine, .deleteSalvageItem, .deleteSupplierOrder,
             .deleteOrderRefund, .cancelKioskOrder,
             .deleteRefurbishmentItem, .deleteBuybackImage,
             .deleteMarketplaceSearch, .unblockMarketplaceSeller:
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

        case .deviceChecklistTemplates(_, _, let checklistType):
            return [URLQueryItem(name: "checklist_type", value: checklistType)]

        case .orders(let page, let limit, let status, let paymentStatus, let locationId, let assignedUserId, let search):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            if let status = status, !status.isEmpty {
                items.append(URLQueryItem(name: "status", value: status))
            }
            if let paymentStatus = paymentStatus, !paymentStatus.isEmpty {
                items.append(URLQueryItem(name: "payment_status", value: paymentStatus))
            }
            if let locationId = locationId, !locationId.isEmpty {
                items.append(URLQueryItem(name: "location_id", value: locationId))
            }
            if let assignedUserId = assignedUserId, !assignedUserId.isEmpty {
                items.append(URLQueryItem(name: "assigned_user_id", value: assignedUserId))
            }
            if let search = search, !search.isEmpty {
                items.append(URLQueryItem(name: "search", value: search))
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

        case .assetFilterProductTypes(let search):
            var items: [URLQueryItem] = []
            if let search = search, !search.isEmpty {
                items.append(URLQueryItem(name: "search", value: search))
            }
            items.append(URLQueryItem(name: "is_active", value: "true"))
            items.append(URLQueryItem(name: "limit", value: "50"))
            return items

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

        case .inventoryList(let page, let limit, let status, let category, let locationId, let subLocationId, let productTypeId, let groupId, let hasGroups, let hasProducts, let search):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            if let status = status { items.append(URLQueryItem(name: "status", value: status)) }
            if let category = category { items.append(URLQueryItem(name: "category", value: category)) }
            if let locationId = locationId { items.append(URLQueryItem(name: "location_id", value: locationId)) }
            if let subLocationId = subLocationId { items.append(URLQueryItem(name: "sub_location_id", value: subLocationId)) }
            if let productTypeId = productTypeId { items.append(URLQueryItem(name: "product_type_id", value: productTypeId)) }
            if let groupId = groupId { items.append(URLQueryItem(name: "group_id", value: groupId)) }
            if let hasGroups = hasGroups { items.append(URLQueryItem(name: "has_groups", value: hasGroups ? "true" : "false")) }
            if let hasProducts = hasProducts { items.append(URLQueryItem(name: "has_products", value: hasProducts ? "true" : "false")) }
            if let search = search, !search.isEmpty { items.append(URLQueryItem(name: "search", value: search)) }
            return items

        case .inventoryActivity(_, let limit):
            if let limit = limit { return [URLQueryItem(name: "limit", value: String(limit))] }
            return nil

        case .inventoryExternalDeployment:
            return [URLQueryItem(name: "include_history", value: "true")]

        case .assetGroupsList(let page, let limit, let search, let category, let hasProducts, let unlinkedOnly, let sortBy, let sortOrder):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            if let search = search, !search.isEmpty { items.append(URLQueryItem(name: "search", value: search)) }
            if let category = category, !category.isEmpty { items.append(URLQueryItem(name: "category", value: category)) }
            if let hasProducts = hasProducts, hasProducts { items.append(URLQueryItem(name: "has_products", value: "true")) }
            if let unlinkedOnly = unlinkedOnly, unlinkedOnly { items.append(URLQueryItem(name: "unlinked_only", value: "true")) }
            if let sortBy = sortBy { items.append(URLQueryItem(name: "sort_by", value: sortBy)) }
            if let sortOrder = sortOrder { items.append(URLQueryItem(name: "sort_order", value: sortOrder)) }
            return items

        case .assetGroupAssets(_, let page, let limit):
            return [URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "limit", value: String(limit))]

        case .supplierOrders(let page, let limit, let supplier, let status):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            if let supplier = supplier, !supplier.isEmpty { items.append(URLQueryItem(name: "supplier", value: supplier)) }
            if let status = status, !status.isEmpty { items.append(URLQueryItem(name: "status", value: status)) }
            return items

        case .assetHierarchy(let status):
            guard let status = status, !status.isEmpty else { return nil }
            return [URLQueryItem(name: "status", value: status)]

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

        case .deviceImageFile(_, _, _, let width, let height):
            var items: [URLQueryItem] = []
            if let width = width { items.append(URLQueryItem(name: "w", value: String(width))) }
            if let height = height { items.append(URLQueryItem(name: "h", value: String(height))) }
            guard !items.isEmpty else { return nil }
            items.append(URLQueryItem(name: "format", value: "auto"))
            return items

        case .kioskProductList(let page, let limit, let category, let search):
            var items: [URLQueryItem] = [
                URLQueryItem(name: "product_kind", value: "product"),
                URLQueryItem(name: "is_active", value: "true"),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "sort_by", value: "name"),
                URLQueryItem(name: "sort_order", value: "asc"),
            ]
            if let category, !category.isEmpty { items.append(URLQueryItem(name: "category", value: category)) }
            if let search, !search.isEmpty { items.append(URLQueryItem(name: "search", value: search)) }
            return items

        case .kioskProductCategories:
            return [URLQueryItem(name: "product_kind", value: "product")]

        case .buybackImages(_, let imageType):
            guard let imageType = imageType, !imageType.isEmpty else { return nil }
            return [URLQueryItem(name: "image_type", value: imageType)]

        case .kioskAvailableAssets(let productTypeId, let groupId, let search):
            var items: [URLQueryItem] = []
            if let productTypeId { items.append(URLQueryItem(name: "product_type_id", value: productTypeId)) }
            if let groupId { items.append(URLQueryItem(name: "group_id", value: groupId)) }
            if let search, !search.isEmpty { items.append(URLQueryItem(name: "search", value: search)) }
            return items

        case .marketplaceListings(let limit, let before, let beforeId, let searchId, let status):
            var items = [URLQueryItem(name: "limit", value: String(limit))]
            if let before, !before.isEmpty { items.append(URLQueryItem(name: "before", value: before)) }
            if let beforeId, !beforeId.isEmpty { items.append(URLQueryItem(name: "before_id", value: beforeId)) }
            if let searchId { items.append(URLQueryItem(name: "search_id", value: String(searchId))) }
            if let status, !status.isEmpty { items.append(URLQueryItem(name: "status", value: status)) }
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
             .diagnosticsPublicCreate, .diagnosticsSubmitResult, .diagnosticsComplete, .diagnosticsResume,
             .diagnosticsReport, .diagnosticsGetSession:
            return false
        default:
            return true
        }
    }

    // MARK: - Masked-proxy routing

    /// Whether this endpoint is routed through the masked `api.kimrelay.com` proxy (`/w/<path>`,
    /// leading `/api/` stripped) instead of hitting `api.repairminder.com` directly — Bridge
    /// secrecy Layer 1 (spec 2026-07-10). Only the diagnostics session endpoints are proxy-routed
    /// today; everything else is unaffected. The relay-edge `/w/` route + `webproxy.ts`
    /// allow-list already cover `/api/public/diagnostics/session` and the `/api/diagnostics/*`
    /// family (deployed — see `docs/superpowers/plans/2026-07-10-live-diagnostics-progress.md`
    /// Task 5), so no backend change is required alongside this iOS change.
    var isDiagnosticsProxyRouted: Bool {
        switch self {
        case .diagnosticsPublicCreate, .diagnosticsSubmitResult, .diagnosticsComplete, .diagnosticsResume,
             .diagnosticsReport, .diagnosticsGetSession:
            return true
        default:
            return false
        }
    }
}
