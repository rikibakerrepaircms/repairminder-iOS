# Stage 02: Foundation - Models & Networking

## Objective

Create all Swift models and networking layer that match EXACTLY the backend API response formats documented in [See: Stage 01].

## Dependencies

- **Requires**: Stage 01 complete (API documentation)
- **Backend Reference**: `/Volumes/Riki Repos/repairminder/worker/`

## Complexity

**High** - Core foundation that all features depend on

## Files to Modify

| File | Changes |
|------|---------|
| `Core/Networking/APIClient.swift` | Complete rewrite with proper response handling |
| `Core/Networking/APIEndpoints.swift` | Complete rewrite with all endpoints |
| `Core/Networking/APIResponse.swift` | Update response wrapper |

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Models/Device.swift` | Device model with all 18 statuses |
| `Core/Models/Order.swift` | Order model with nested types |
| `Core/Models/Ticket.swift` | Ticket/Enquiry model |
| `Core/Models/TicketMessage.swift` | Message model with types |
| `Core/Models/Client.swift` | Client model |
| `Core/Models/DashboardStats.swift` | Dashboard statistics model |
| `Core/Models/User.swift` | User and auth response models |
| `Core/Models/Pagination.swift` | Pagination model |
| `Core/Models/CustomerModels.swift` | Customer-specific models for customer portal |
| `App/UserRole.swift` | Staff vs Customer role enum |

---

## Implementation Details

### APIResponse.swift

```swift
// Core/Networking/APIResponse.swift

import Foundation

/// Standard API response wrapper
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
    let errors: [ValidationError]?
    let pagination: Pagination?
}

struct ValidationError: Decodable {
    let field: String
    let message: String
}

struct Pagination: Decodable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page, limit, total
        case totalPages = "total_pages"
    }
}

/// Empty response for void endpoints
struct EmptyResponse: Decodable {}
```

---

### APIClient.swift

```swift
// Core/Networking/APIClient.swift

import Foundation
import os.log

actor APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "API")

    private init() {
        // Configure from environment or default
        self.baseURL = URL(string: "https://api.repairminder.com")!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // Try ISO8601 without fractional seconds
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // Try date-only format
            let dateOnlyFormatter = DateFormatter()
            dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateOnlyFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Request Methods

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        let request = try buildRequest(for: endpoint)

        logger.debug("Request: \(endpoint.method.rawValue) \(endpoint.path)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        logger.debug("Response: \(httpResponse.statusCode)")

        // Handle 401 - Token expired
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        // Handle other errors
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder.decode(APIResponse<EmptyResponse>.self, from: data) {
                throw APIError.serverError(errorResponse.error ?? "Unknown error")
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        // Decode response
        do {
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)

            guard apiResponse.success, let responseData = apiResponse.data else {
                throw APIError.serverError(apiResponse.error ?? "Request failed")
            }

            return responseData
        } catch let decodingError as DecodingError {
            logger.error("Decode error: \(String(describing: decodingError))")

            // Log the raw JSON for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.debug("Raw response: \(jsonString.prefix(1000))")
            }

            throw APIError.decodingError(decodingError)
        }
    }

    func requestVoid(_ endpoint: APIEndpoint) async throws {
        let _: EmptyResponse = try await request(endpoint, responseType: EmptyResponse.self)
    }

    func requestWithPagination<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> (data: T, pagination: Pagination?) {
        let request = try buildRequest(for: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)

        guard apiResponse.success, let responseData = apiResponse.data else {
            throw APIError.serverError(apiResponse.error ?? "Request failed")
        }

        return (responseData, apiResponse.pagination)
    }

    // MARK: - Request Building

    private func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)!

        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token if available
        if let token = await AuthManager.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(body)
        }

        return request
    }
}

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int)
    case serverError(String)
    case decodingError(DecodingError)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .unauthorized:
            return "Session expired. Please login again."
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return message
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
```

---

### APIEndpoints.swift

```swift
// Core/Networking/APIEndpoints.swift

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
    case delete = "DELETE"
}

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let body: Encodable?
    let queryItems: [URLQueryItem]?

    init(
        path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil
    ) {
        self.path = path
        self.method = method
        self.body = body
        self.queryItems = queryItems
    }
}

// MARK: - Authentication Endpoints

extension APIEndpoint {
    static func login(email: String, password: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/auth/login",
            method: .post,
            body: ["email": email, "password": password]
        )
    }

    static func logout() -> APIEndpoint {
        APIEndpoint(path: "/api/auth/logout", method: .post)
    }

    static func me() -> APIEndpoint {
        APIEndpoint(path: "/api/auth/me")
    }

    static func requestMagicLink(email: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/auth/magic-link/request",
            method: .post,
            body: ["email": email]
        )
    }

    static func verifyMagicCode(email: String, code: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/auth/magic-link/verify-code",
            method: .post,
            body: ["email": email, "code": code]
        )
    }

    static func refreshToken(refreshToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/auth/refresh",
            method: .post,
            body: ["refresh_token": refreshToken]
        )
    }
}

// MARK: - Dashboard Endpoints

extension APIEndpoint {
    static func dashboardStats(
        scope: String = "user",
        period: String = "this_month"
    ) -> APIEndpoint {
        APIEndpoint(
            path: "/api/dashboard/stats",
            queryItems: [
                URLQueryItem(name: "scope", value: scope),
                URLQueryItem(name: "period", value: period)
            ]
        )
    }
}

// MARK: - Device Endpoints

extension APIEndpoint {
    static func devices(
        page: Int = 1,
        limit: Int = 20,
        status: String? = nil,
        assignedUserId: String? = nil
    ) -> APIEndpoint {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let assignedUserId = assignedUserId {
            queryItems.append(URLQueryItem(name: "assigned_user_id", value: assignedUserId))
        }
        return APIEndpoint(path: "/api/devices", queryItems: queryItems)
    }

    static func myQueue(page: Int = 1, limit: Int = 20) -> APIEndpoint {
        APIEndpoint(
            path: "/api/devices/my-queue",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
    }

    static func headerCounts() -> APIEndpoint {
        APIEndpoint(path: "/api/header/counts")
    }

    static func device(orderId: String, deviceId: String) -> APIEndpoint {
        APIEndpoint(path: "/api/orders/\(orderId)/devices/\(deviceId)")
    }

    static func deviceAction(deviceId: String, action: String, notes: String? = nil) -> APIEndpoint {
        var body: [String: Any] = ["action": action]
        if let notes = notes {
            body["notes"] = notes
        }
        return APIEndpoint(
            path: "/api/devices/\(deviceId)/action",
            method: .post,
            body: body as? Encodable
        )
    }

    static func assignEngineer(deviceId: String, engineerId: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/devices/\(deviceId)/engineer",
            method: .patch,
            body: ["engineer_id": engineerId]
        )
    }

    static func updateDeviceStatus(deviceId: String, status: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/devices/\(deviceId)/status",
            method: .patch,
            body: ["status": status]
        )
    }
}

// MARK: - Order Endpoints

extension APIEndpoint {
    static func orders(
        page: Int = 1,
        limit: Int = 20,
        status: String? = nil,
        search: String? = nil
    ) -> APIEndpoint {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let search = search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        return APIEndpoint(path: "/api/orders", queryItems: queryItems)
    }

    static func order(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/orders/\(id)")
    }
}

// MARK: - Ticket Endpoints

extension APIEndpoint {
    static func tickets(
        page: Int = 1,
        limit: Int = 20,
        status: String? = nil
    ) -> APIEndpoint {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        return APIEndpoint(path: "/api/tickets", queryItems: queryItems)
    }

    static func ticket(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/tickets/\(id)")
    }

    static func ticketReply(ticketId: String, body: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/tickets/\(ticketId)/reply",
            method: .post,
            body: ["body": body]
        )
    }

    static func ticketNote(ticketId: String, body: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/tickets/\(ticketId)/note",
            method: .post,
            body: ["body": body]
        )
    }

    static func resolveTicket(ticketId: String, notes: String? = nil) -> APIEndpoint {
        APIEndpoint(
            path: "/api/tickets/\(ticketId)/resolve",
            method: .post,
            body: notes != nil ? ["resolution_notes": notes!] : nil
        )
    }
}

// MARK: - Client Endpoints

extension APIEndpoint {
    static func clients(
        page: Int = 1,
        limit: Int = 50,
        search: String? = nil
    ) -> APIEndpoint {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let search = search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        return APIEndpoint(path: "/api/clients", queryItems: queryItems)
    }

    static func client(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/clients/\(id)")
    }
}

// MARK: - Push Notification Endpoints

extension APIEndpoint {
    static func registerDeviceToken(token: String, appType: String = "staff") -> APIEndpoint {
        APIEndpoint(
            path: "/api/user/device-token",
            method: .post,
            body: ["token": token, "platform": "ios", "app_type": appType]
        )
    }

    static func unregisterDeviceToken(token: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/user/device-token",
            method: .delete,
            body: ["token": token]
        )
    }

    static func pushPreferences() -> APIEndpoint {
        APIEndpoint(path: "/api/user/push-preferences")
    }

    static func updatePushPreferences(_ preferences: PushPreferences) -> APIEndpoint {
        APIEndpoint(
            path: "/api/user/push-preferences",
            method: .put,
            body: preferences
        )
    }
}
```

---

### Device.swift

```swift
// Core/Models/Device.swift

import Foundation

struct Device: Identifiable, Codable {
    let id: String
    let orderId: String
    let orderNumber: Int?
    let displayName: String
    let brand: DeviceBrand?
    let model: DeviceModel?
    let customBrand: String?
    let customModel: String?
    let serialNumber: String?
    let imei: String?
    let colour: String?
    let storageCapacity: String?
    let passcode: String?
    let passcodeType: String?
    let findMyStatus: String?
    let conditionGrade: String?
    let customerReportedIssues: String?
    let technicianFoundIssues: String?
    let status: DeviceStatus
    let workflowType: WorkflowType?
    let priority: String?
    let dueDate: Date?
    let assignedEngineer: AssignedEngineer?
    let subLocation: SubLocation?
    let deviceType: DeviceTypeInfo?
    let diagnosisNotes: String?
    let repairNotes: String?
    let authorization: DeviceAuthorization?
    let timestamps: DeviceTimestamps?
    let images: [DeviceImage]?
    let accessories: [DeviceAccessory]?
    let lineItems: [DeviceLineItem]?
    let client: DeviceClient?
    let createdAt: Date
    let updatedAt: Date?
}

// MARK: - Device Status (18 statuses)

enum DeviceStatus: String, Codable, CaseIterable {
    // Repair workflow
    case deviceReceived = "device_received"
    case diagnosing = "diagnosing"
    case readyToQuote = "ready_to_quote"
    case companyRejected = "company_rejected"
    case awaitingAuthorisation = "awaiting_authorisation"
    case authorisedSourceParts = "authorised_source_parts"
    case authorisedAwaitingParts = "authorised_awaiting_parts"
    case readyToRepair = "ready_to_repair"
    case repairing = "repairing"
    case awaitingRevisedQuote = "awaiting_revised_quote"
    case repairedQc = "repaired_qc"
    case repairedReady = "repaired_ready"
    case rejected = "rejected"
    case rejectionQc = "rejection_qc"
    case rejectionReady = "rejection_ready"
    case collected = "collected"
    case despatched = "despatched"

    // Buyback workflow
    case readyToPay = "ready_to_pay"
    case paymentMade = "payment_made"
    case addedToBuyback = "added_to_buyback"

    // Unknown fallback
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = DeviceStatus(rawValue: rawValue) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .deviceReceived: return "Device Received"
        case .diagnosing: return "Diagnosing"
        case .readyToQuote: return "Ready to Quote"
        case .companyRejected: return "Company Rejected"
        case .awaitingAuthorisation: return "Awaiting Authorisation"
        case .authorisedSourceParts: return "Authorised - Source Parts"
        case .authorisedAwaitingParts: return "Awaiting Parts"
        case .readyToRepair: return "Ready to Repair"
        case .repairing: return "Repairing"
        case .awaitingRevisedQuote: return "Awaiting Revised Quote"
        case .repairedQc: return "Repaired - QC"
        case .repairedReady: return "Repaired - Ready"
        case .rejected: return "Rejected"
        case .rejectionQc: return "Rejection - QC"
        case .rejectionReady: return "Rejection - Ready"
        case .collected: return "Collected"
        case .despatched: return "Despatched"
        case .readyToPay: return "Ready to Pay"
        case .paymentMade: return "Payment Made"
        case .addedToBuyback: return "Added to Buyback"
        case .unknown: return "Unknown"
        }
    }
}

enum WorkflowType: String, Codable {
    case repair = "repair"
    case tradeIn = "trade_in"
    case buyback = "buyback"
    case deviceSale = "device_sale"
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = WorkflowType(rawValue: rawValue) ?? .unknown
    }
}

// MARK: - Nested Types

struct DeviceBrand: Codable {
    let id: String
    let name: String
    let category: String?
}

struct DeviceModel: Codable {
    let id: String
    let name: String
}

struct AssignedEngineer: Codable {
    let id: String
    let name: String
}

struct SubLocation: Codable {
    let id: String
    let code: String
    let description: String?
    let type: String?
}

struct DeviceTypeInfo: Codable {
    let id: String
    let name: String
    let slug: String?
}

struct DeviceAuthorization: Codable {
    let status: String?
    let method: String?
    let authorizedAt: Date?
    let authorizedByName: String?
}

struct DeviceTimestamps: Codable {
    let receivedAt: Date?
    let checkedInAt: Date?
    let diagnosisStartedAt: Date?
    let diagnosisCompletedAt: Date?
    let repairStartedAt: Date?
    let repairCompletedAt: Date?
    let qualityCheckedAt: Date?
    let readyForCollectionAt: Date?
    let collectedAt: Date?
    let despatchedAt: Date?
}

struct DeviceImage: Identifiable, Codable {
    let id: String
    let imageType: String?
    let filename: String?
    let caption: String?
    let sortOrder: Int?
}

struct DeviceAccessory: Identifiable, Codable {
    let id: String
    let accessoryType: String?
    let description: String?
    let returnedAt: Date?
}

struct DeviceLineItem: Identifiable, Codable {
    let id: String
    let description: String
    let quantity: Int
    let unitPrice: Double
    let vatRate: Double?
    let lineTotalIncVat: Double?
}

struct DeviceClient: Codable {
    let id: String
    let name: String?
    let email: String?
}
```

---

### Order.swift

```swift
// Core/Models/Order.swift

import Foundation

struct Order: Identifiable, Codable {
    let id: String
    let ticketId: String?
    let orderNumber: Int
    let client: OrderClient
    let location: OrderLocation?
    let assignedUser: OrderAssignedUser?
    let intakeMethod: String?
    let status: OrderStatus
    let paymentStatus: PaymentStatus?
    let orderTotal: Double?
    let amountPaid: Double?
    let balanceDue: Double?
    let deviceCount: Int?
    let devices: [OrderDevice]?
    let items: [OrderItem]?
    let payments: [OrderPayment]?
    let totals: OrderTotals?
    let dates: OrderDates?
    let notes: [OrderNote]?
    let createdAt: Date
    let updatedAt: Date?

    var displayRef: String { "#\(orderNumber)" }
}

// MARK: - Order Status

enum OrderStatus: String, Codable, CaseIterable {
    case awaitingDevice = "awaiting_device"
    case inProgress = "in_progress"
    case serviceComplete = "service_complete"
    case awaitingCollection = "awaiting_collection"
    case collectedDespatched = "collected_despatched"
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = OrderStatus(rawValue: rawValue) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .awaitingDevice: return "Awaiting Device"
        case .inProgress: return "In Progress"
        case .serviceComplete: return "Service Complete"
        case .awaitingCollection: return "Awaiting Collection"
        case .collectedDespatched: return "Collected/Despatched"
        case .unknown: return "Unknown"
        }
    }
}

enum PaymentStatus: String, Codable {
    case unpaid = "unpaid"
    case partial = "partial"
    case paid = "paid"
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = PaymentStatus(rawValue: rawValue) ?? .unknown
    }
}

// MARK: - Nested Types

struct OrderClient: Codable {
    let id: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let phone: String?
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let postcode: String?

    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}

struct OrderLocation: Codable {
    let id: String
    let name: String
    let phone: String?
}

struct OrderAssignedUser: Codable {
    let id: String
    let name: String
}

struct OrderDevice: Identifiable, Codable {
    let id: String
    let displayName: String?
    let status: DeviceStatus?
    let workflowType: WorkflowType?
}

struct OrderItem: Identifiable, Codable {
    let id: String
    let description: String
    let quantity: Int
    let unitPrice: Double
    let vatRate: Double?
    let lineTotal: Double?
    let lineTotalIncVat: Double?
}

struct OrderPayment: Identifiable, Codable {
    let id: String
    let amount: Double
    let paymentMethod: String?
    let paymentDate: String?
    let isDeposit: Int?
    let notes: String?
}

struct OrderTotals: Codable {
    let subtotal: Double
    let vatTotal: Double
    let grandTotal: Double
    let amountPaid: Double?
    let balanceDue: Double?
    let depositsPaid: Double?
}

struct OrderDates: Codable {
    let createdAt: Date?
    let updatedAt: Date?
    let quoteSentAt: Date?
    let authorisedAt: Date?
    let collectedAt: Date?
    let despatchedAt: Date?
    let readyByDate: Date?
}

struct OrderNote: Codable {
    let body: String
    let createdAt: Date?
    let createdBy: String?
    let deviceId: String?
    let deviceName: String?
}
```

---

### Ticket.swift

```swift
// Core/Models/Ticket.swift

import Foundation

struct Ticket: Identifiable, Codable {
    let id: String
    let ticketNumber: Int
    let subject: String
    let status: TicketStatus
    let ticketType: TicketType?
    let assignedUser: TicketAssignedUser?
    let client: TicketClient
    let location: TicketLocation?
    let order: TicketOrder?
    let messages: [TicketMessage]?
    let createdAt: Date
    let updatedAt: Date?
    let lastClientUpdate: Date?

    var displayRef: String { "#\(ticketNumber)" }
}

enum TicketStatus: String, Codable, CaseIterable {
    case open = "open"
    case pending = "pending"
    case resolved = "resolved"
    case closed = "closed"
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = TicketStatus(rawValue: rawValue) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .pending: return "Pending"
        case .resolved: return "Resolved"
        case .closed: return "Closed"
        case .unknown: return "Unknown"
        }
    }
}

enum TicketType: String, Codable {
    case lead = "lead"
    case order = "order"
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = TicketType(rawValue: rawValue) ?? .unknown
    }
}

struct TicketAssignedUser: Codable {
    let firstName: String?
    let lastName: String?

    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}

struct TicketClient: Codable {
    let id: String
    let email: String?
    let name: String?
    let phone: String?
}

struct TicketLocation: Codable {
    let id: String
    let name: String
}

struct TicketOrder: Codable {
    let id: String
    let orderNumber: Int?
    let status: OrderStatus?
    let deviceCount: Int?
}

struct TicketStatusCounts: Codable {
    let open: Int
    let pending: Int
    let resolved: Int
    let closed: Int
}

struct TicketListResponse: Codable {
    let tickets: [Ticket]
    let statusCounts: TicketStatusCounts?
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
}
```

---

### TicketMessage.swift

```swift
// Core/Models/TicketMessage.swift

import Foundation

struct TicketMessage: Identifiable, Codable {
    let id: String
    let type: MessageType
    let fromEmail: String?
    let fromName: String?
    let toEmail: String?
    let subject: String?
    let bodyText: String?
    let bodyHtml: String?
    let deviceId: String?
    let deviceName: String?
    let createdAt: Date
    let createdBy: MessageCreatedBy?
    let attachments: [MessageAttachment]?
}

enum MessageType: String, Codable {
    case inbound = "inbound"
    case outbound = "outbound"
    case outboundSms = "outbound_sms"
    case note = "note"
    case internalNote = "internal_note"
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = MessageType(rawValue: rawValue) ?? .unknown
    }

    var isInternal: Bool {
        self == .note || self == .internalNote
    }
}

struct MessageCreatedBy: Codable {
    let id: String
    let firstName: String?
    let lastName: String?

    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}

struct MessageAttachment: Identifiable, Codable {
    let id: String
    let filename: String?
    let contentType: String?
    let sizeBytes: Int?
}
```

---

### DashboardStats.swift

```swift
// Core/Models/DashboardStats.swift

import Foundation

struct DashboardStats: Codable {
    let period: String
    let devices: StatMetric?
    let revenue: RevenueMetric?
    let clients: StatMetric?
    let newClients: StatMetric?
    let returningClients: StatMetric?
    let refunds: RefundMetric?
}

struct StatMetric: Codable {
    let current: StatCurrent
    let comparisons: [StatComparison]?
}

struct StatCurrent: Codable {
    let count: Int?
    let total: Double?
}

struct StatComparison: Codable {
    let period: String
    let count: Int?
    let total: Double?
    let change: Double?
    let changePercent: Double?
}

struct RevenueMetric: Codable {
    let current: RevenueCurrent
    let comparisons: [StatComparison]?
}

struct RevenueCurrent: Codable {
    let total: Double
}

struct RefundMetric: Codable {
    let current: RefundCurrent
    let comparisons: [StatComparison]?
}

struct RefundCurrent: Codable {
    let total: Double
    let count: Int
}

struct HeaderCounts: Codable {
    let myQueue: Int
    let activeWork: Int?
    let openEnquiries: Int?
}
```

---

### User.swift

```swift
// Core/Models/User.swift

import Foundation

struct User: Identifiable, Codable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let role: String?
    let companyId: String?
    let company: UserCompany?
    let permissions: [String]?

    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}

struct UserCompany: Codable {
    let id: String
    let name: String
    let currencyCode: String?
    let logoUrl: String?
}

struct LoginResponse: Codable {
    let token: String?
    let refreshToken: String?
    let user: User?
    let requires2fa: Bool?
    let method: String?
    let tempToken: String?
}

struct RefreshResponse: Codable {
    let token: String
    let refreshToken: String
}

struct PushPreferences: Codable {
    var enabled: Bool
    var orderCreated: Bool
    var orderStatusChanged: Bool
    var orderCollected: Bool
    var deviceStatusChanged: Bool
    var quoteApproved: Bool
    var quoteRejected: Bool
    var paymentReceived: Bool
    var newEnquiry: Bool
    var enquiryReply: Bool
    var deviceAssigned: Bool
}
```

---

### Client.swift

```swift
// Core/Models/Client.swift

import Foundation

struct Client: Identifiable, Codable {
    let id: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let phone: String?
    let notes: String?
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let county: String?
    let postcode: String?
    let country: String?
    let marketingConsent: Bool?
    let orderCount: Int?
    let deviceCount: Int?
    let totalSpend: Double?
    let createdAt: Date?
    let updatedAt: Date?

    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}

struct ClientListResponse: Codable {
    let clients: [Client]
    let pagination: Pagination?
}
```

---

### UserRole.swift

```swift
// App/UserRole.swift

import Foundation

/// Role selection for unified app - Staff or Customer
enum UserRole: String, Codable {
    case staff
    case customer

    var displayName: String {
        switch self {
        case .staff: return "Staff"
        case .customer: return "Customer"
        }
    }
}
```

---

### CustomerModels.swift

```swift
// Core/Models/CustomerModels.swift

import Foundation

// MARK: - Customer Authentication

/// Customer client info from auth response (different from Staff's User model)
struct CustomerClient: Codable {
    let id: String
    let firstName: String?
    let lastName: String?
    let email: String
    let name: String?

    var displayName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        }
        return name ?? email
    }
}

/// Company info in customer auth response
struct CustomerCompany: Codable {
    let id: String
    let name: String
    let logoUrl: String?
}

/// Customer login response
struct CustomerLoginResponse: Codable {
    // Direct login success
    let token: String?
    let client: CustomerClient?
    let company: CustomerCompany?

    // Multi-company selection required
    let requiresCompanySelection: Bool?
    let companies: [CustomerCompany]?
    let email: String?
    let code: String?
}

// MARK: - Customer Orders

/// Customer order in list view
struct CustomerOrder: Identifiable, Codable {
    let id: String
    let ticketNumber: Int
    let status: String
    let createdAt: Date
    let quoteSentAt: Date?
    let quoteApprovedAt: Date?
    let rejectedAt: Date?
    let updatedAt: Date?
    let devices: [CustomerOrderDevice]
    let totals: CustomerOrderTotals

    var displayRef: String { "#\(ticketNumber)" }
}

struct CustomerOrderDevice: Identifiable, Codable {
    let id: String
    let status: DeviceStatus
    let displayName: String
}

struct CustomerOrderTotals: Codable {
    let subtotal: Double
    let vatTotal: Double
    let grandTotal: Double
}

/// Full customer order detail
struct CustomerOrderDetail: Codable {
    let id: String
    let ticketNumber: Int
    let status: String
    let createdAt: Date
    let collectedAt: Date?
    let quoteSentAt: Date?
    let quoteApprovedAt: Date?
    let quoteApprovedMethod: String?
    let rejectedAt: Date?
    let preAuthorization: PreAuthorization?
    let reviewLinks: ReviewLinks?
    let devices: [CustomerDeviceDetail]
    let items: [CustomerOrderItem]
    let totals: CustomerOrderDetailTotals
    let messages: [CustomerMessage]
    let company: CustomerOrderCompany?
}

struct PreAuthorization: Codable {
    let amount: Double
    let notes: String?
    let authorisedAt: Date?
    let authorisedBy: PreAuthUser?
    let signature: PreAuthSignature?
}

struct PreAuthUser: Codable {
    let firstName: String?
    let lastName: String?
}

struct PreAuthSignature: Codable {
    let id: String
    let type: String
    let data: String?
    let typedName: String?
    let capturedAt: Date?
}

struct ReviewLinks: Codable {
    let google: String?
    let facebook: String?
    let trustpilot: String?
    let yelp: String?
    let apple: String?
}

struct CustomerDeviceDetail: Identifiable, Codable {
    let id: String
    let displayName: String
    let status: DeviceStatus
    let workflowType: WorkflowType?
    let customerReportedIssues: String?
    let diagnosisNotes: String?
    let serialNumber: String?
    let imei: String?
    let authorizationStatus: String?
    let authorizationMethod: String?
    let authorizedAt: Date?
    let authorizationNotes: String?
    let collectionLocation: CollectionLocation?
    let depositPaid: Double?
    let images: [CustomerDeviceImage]?
    let preRepairChecklist: PreRepairChecklist?
}

struct CollectionLocation: Codable {
    let id: String
    let name: String
    let address: String?
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let county: String?
    let postcode: String?
    let phone: String?
    let email: String?
    let googleMapsUrl: String?
    let appleMapsUrl: String?
    let openingHours: [String: String]?
}

struct CustomerDeviceImage: Identifiable, Codable {
    let id: String
    let imageType: String
    let url: String
    let filename: String?
    let caption: String?
    let uploadedAt: Date?
}

struct PreRepairChecklist: Codable {
    let id: String
    let templateName: String?
    let results: [ChecklistResult]?
    let completedAt: Date?
    let completedByName: String?
}

struct ChecklistResult: Codable {
    let name: String?
    let result: String?
    let notes: String?
}

struct CustomerOrderItem: Identifiable, Codable {
    let id: String
    let description: String
    let quantity: Int
    let unitPrice: Double
    let vatRate: Double?
    let lineTotal: Double?
    let vatAmount: Double?
    let lineTotalIncVat: Double?
    let deviceId: String?
    let authorizationStatus: String?
    let signatureId: String?
    let authorizedPrice: Double?
}

struct CustomerOrderDetailTotals: Codable {
    let subtotal: Double
    let vatTotal: Double
    let grandTotal: Double
    let depositsPaid: Double?
    let finalPaymentsPaid: Double?
    let amountPaid: Double?
    let balanceDue: Double?
}

struct CustomerMessage: Identifiable, Codable {
    let id: String
    let type: String
    let subject: String?
    let bodyText: String?
    let createdAt: Date
}

struct CustomerOrderCompany: Codable {
    let name: String
    let phone: String?
    let email: String?
    let logoUrl: String?
    let currencyCode: String
    let termsConditions: String?
    let collectionStorageFeeEnabled: Bool?
    let collectionRecyclingEnabled: Bool?
    let collectionStorageFeeDaily: Double?
    let collectionStorageFeeCap: Double?
}

// MARK: - Customer Actions

/// Quote approval request
struct QuoteApprovalRequest: Encodable {
    let action: String // "approve" or "reject"
    let signatureType: String // "typed" or "drawn"
    let signatureData: String
    let amountAcknowledged: Double?
    let rejectionReason: String?
}

/// Quote approval response
struct QuoteApprovalResponse: Codable {
    let message: String
    let approvedAt: Date?
    let rejectedAt: Date?
    let signatureId: String?
}

/// Customer reply request
struct CustomerReplyRequest: Encodable {
    let message: String
    let deviceId: String?
}

/// Customer reply response
struct CustomerReplyResponse: Codable {
    let messageId: String
    let createdAt: Date
}

/// Per-device authorization request
struct DeviceAuthorizationRequest: Encodable {
    let action: String // "approve", "reject", or "proceed_original"
    let signatureType: String?
    let signatureData: String?
    let bankDetails: BankDetails?
}

struct BankDetails: Encodable {
    let accountName: String
    let sortCode: String
    let accountNumber: String
}

/// Device authorization response
struct DeviceAuthorizationResponse: Codable {
    let message: String
    let newStatus: String?
    let signatureId: String?
}
```

---

### Customer Endpoints (add to APIEndpoints.swift)

```swift
// MARK: - Customer Authentication Endpoints

extension APIEndpoint {
    static func customerRequestMagicLink(email: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/customer/auth/request-magic-link",
            method: .post,
            body: ["email": email]
        )
    }

    static func customerVerifyCode(email: String, code: String, companyId: String? = nil) -> APIEndpoint {
        var body: [String: String] = ["email": email, "code": code]
        if let companyId = companyId {
            body["companyId"] = companyId
        }
        return APIEndpoint(
            path: "/api/customer/auth/verify-code",
            method: .post,
            body: body
        )
    }

    static func customerMe() -> APIEndpoint {
        APIEndpoint(path: "/api/customer/auth/me")
    }

    static func customerLogout() -> APIEndpoint {
        APIEndpoint(path: "/api/customer/auth/logout", method: .post)
    }
}

// MARK: - Customer Order Endpoints

extension APIEndpoint {
    static func customerOrders() -> APIEndpoint {
        APIEndpoint(path: "/api/customer/orders")
    }

    static func customerOrder(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/customer/orders/\(id)")
    }

    static func customerApproveOrder(orderId: String, request: QuoteApprovalRequest) -> APIEndpoint {
        APIEndpoint(
            path: "/api/customer/orders/\(orderId)/approve",
            method: .post,
            body: request
        )
    }

    static func customerDeviceAuthorization(deviceId: String, request: DeviceAuthorizationRequest) -> APIEndpoint {
        APIEndpoint(
            path: "/api/customer/devices/\(deviceId)/authorize",
            method: .post,
            body: request
        )
    }

    static func customerReply(orderId: String, message: String, deviceId: String? = nil) -> APIEndpoint {
        var body: [String: String] = ["message": message]
        if let deviceId = deviceId {
            body["device_id"] = deviceId
        }
        return APIEndpoint(
            path: "/api/customer/orders/\(orderId)/reply",
            method: .post,
            body: body
        )
    }

    static func customerInvoice(orderId: String) -> APIEndpoint {
        APIEndpoint(path: "/api/customer/orders/\(orderId)/invoice")
    }
}

// MARK: - Customer Push Notification (uses same endpoint with different app_type)

extension APIEndpoint {
    static func registerCustomerDeviceToken(token: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/user/device-token",
            method: .post,
            body: ["token": token, "platform": "ios", "app_type": "customer"]
        )
    }
}
```

---

## Database Changes

None (iOS models only)

## Test Cases

| Test | Expected |
|------|----------|
| **Staff Models** | |
| Device decodes all 18 statuses | No decode errors for any status |
| Order decodes with all nested types | Client, devices, totals all decode |
| Ticket decodes with messages | Messages array decodes correctly |
| DashboardStats decodes comparisons | Comparison arrays work |
| Date parsing works | ISO8601 and date-only formats parse |
| Unknown enum values don't crash | Fallback to .unknown |
| APIClient handles 401 | Throws unauthorized error |
| APIClient handles decode errors | Logs and throws meaningful error |
| **Customer Models** | |
| CustomerLoginResponse decodes single company | Token and client returned |
| CustomerLoginResponse decodes multi-company | requiresCompanySelection true with companies array |
| CustomerOrder decodes from list endpoint | Devices and totals included |
| CustomerOrderDetail decodes full response | All nested objects decode correctly |
| QuoteApprovalRequest encodes correctly | snake_case keys in JSON |

## Acceptance Checklist

### Staff Models
- [ ] All models compile without errors
- [ ] All CodingKeys use snake_case matching backend
- [ ] All optional fields properly marked as optional
- [ ] Date parsing handles multiple formats
- [ ] All enums have init(from:) with fallback for unknown values
- [ ] Device has all 18 statuses with display names
- [ ] Order has all 5 statuses with display names
- [ ] Ticket has all 4 statuses with display names
- [ ] APIClient decodes wrapped responses correctly
- [ ] APIClient handles errors gracefully
- [ ] All staff endpoints defined in APIEndpoints.swift

### Customer Models
- [ ] UserRole enum defined with staff/customer cases
- [ ] CustomerClient and CustomerCompany models defined
- [ ] CustomerLoginResponse handles both single and multi-company flows
- [ ] CustomerOrder model for list view defined
- [ ] CustomerOrderDetail model for detail view defined
- [ ] QuoteApprovalRequest/Response models defined
- [ ] DeviceAuthorizationRequest/Response models defined
- [ ] CustomerReplyRequest/Response models defined
- [ ] All customer endpoints defined in APIEndpoints.swift

## Deployment

```bash
# Build to verify compilation
xcodebuild -workspace "Repair Minder/Repair Minder.xcworkspace" \
  -scheme "Repair Minder" \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
  build
```

## Handoff Notes

- All models use `Codable` for automatic encoding/decoding
- Decoder is configured with `.convertFromSnakeCase`
- Unknown enum values fallback to `.unknown` to prevent crashes
- Date parsing supports ISO8601 with/without fractional seconds and date-only
- `UserRole` enum distinguishes between Staff and Customer modes
- Customer models are separate from Staff models due to different API response structures
- Customer auth uses magic link only (no password auth)
- [See: Stage 03] for authentication implementation using these models (both staff and customer flows)
- [See: Stage 04-07] for staff feature implementations
- [See: Stage 08] for customer feature implementations
