# Stage 02: Networking Layer

## Objective

Create a robust API client that handles all HTTP communication with `api.repairminder.com`, including request/response serialization, error handling, and request interceptors.

---

## Dependencies

**Requires:** [See: Stage 01] complete - Environment configuration exists

---

## Complexity

**High** - Core infrastructure, must handle many edge cases

---

## Files to Modify

| File | Changes |
|------|---------|
| `Core/Config/Environment.swift` | Add request timeout configuration |

---

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Networking/APIClient.swift` | Main HTTP client with async/await |
| `Core/Networking/APIEndpoints.swift` | All API endpoint definitions |
| `Core/Networking/APIError.swift` | Error types and handling |
| `Core/Networking/APIResponse.swift` | Response wrapper types |
| `Core/Networking/RequestInterceptor.swift` | Auth token injection, logging |
| `Core/Networking/HTTPMethod.swift` | HTTP method enum |
| `Core/Networking/NetworkMonitor.swift` | Connectivity monitoring |

---

## Implementation Details

### 1. HTTP Method Enum

```swift
// Core/Networking/HTTPMethod.swift
import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
```

### 2. API Error Types

```swift
// Core/Networking/APIError.swift
import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidRequest
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case encodingError(Error)
    case httpError(statusCode: Int, message: String?)
    case unauthorized
    case forbidden
    case notFound
    case serverError(String?)
    case rateLimited(retryAfter: Int?)
    case noData
    case offline

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidRequest:
            return "Invalid request"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .httpError(let statusCode, let message):
            return message ?? "HTTP Error \(statusCode)"
        case .unauthorized:
            return "Your session has expired. Please log in again."
        case .forbidden:
            return "You don't have permission to access this resource"
        case .notFound:
            return "The requested resource was not found"
        case .serverError(let message):
            return message ?? "Server error. Please try again later."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Too many requests. Please wait \(seconds) seconds."
            }
            return "Too many requests. Please try again later."
        case .noData:
            return "No data received"
        case .offline:
            return "You appear to be offline"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError, .rateLimited:
            return true
        default:
            return false
        }
    }

    var requiresReauth: Bool {
        switch self {
        case .unauthorized:
            return true
        default:
            return false
        }
    }
}
```

### 3. API Response Types

```swift
// Core/Networking/APIResponse.swift
import Foundation

/// Standard API response wrapper matching backend format
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
}

/// Empty response for endpoints that return no data
struct EmptyResponse: Decodable {}

/// Pagination metadata
struct PaginationMeta: Decodable {
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case total, limit, offset
        case hasMore = "has_more"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = try container.decode(Int.self, forKey: .total)
        limit = try container.decode(Int.self, forKey: .limit)
        offset = try container.decode(Int.self, forKey: .offset)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore)
            ?? (offset + limit < total)
    }
}

/// Paginated response wrapper
struct PaginatedResponse<T: Decodable>: Decodable {
    let items: T
    let pagination: PaginationMeta
}
```

### 4. Network Monitor

```swift
// Core/Networking/NetworkMonitor.swift
import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown
    }

    private init() {
        startMonitoring()
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied

                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .wired
                } else {
                    self?.connectionType = .unknown
                }
            }
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }
}
```

### 5. Request Interceptor

```swift
// Core/Networking/RequestInterceptor.swift
import Foundation
import os.log

protocol RequestInterceptor {
    func intercept(_ request: inout URLRequest) async throws
}

/// Adds authentication token to requests
final class AuthInterceptor: RequestInterceptor {
    private let tokenProvider: () -> String?

    init(tokenProvider: @escaping () -> String?) {
        self.tokenProvider = tokenProvider
    }

    func intercept(_ request: inout URLRequest) async throws {
        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}

/// Logs requests and responses for debugging
final class LoggingInterceptor: RequestInterceptor {
    private let logger = Logger(subsystem: "com.mendmyi.repairminder", category: "API")

    func intercept(_ request: inout URLRequest) async throws {
        #if DEBUG
        logger.debug("[\(request.httpMethod ?? "?")] \(request.url?.absoluteString ?? "nil")")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.debug("Body: \(bodyString)")
        }
        #endif
    }
}

/// Adds common headers to all requests
final class CommonHeadersInterceptor: RequestInterceptor {
    func intercept(_ request: inout URLRequest) async throws {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("RepairMinder-iOS/1.0", forHTTPHeaderField: "User-Agent")
    }
}
```

### 6. API Client

```swift
// Core/Networking/APIClient.swift
import Foundation
import os.log

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let logger = Logger(subsystem: "com.mendmyi.repairminder", category: "APIClient")

    private var interceptors: [RequestInterceptor] = []

    init(
        baseURL: URL = AppEnvironment.current.apiBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        // Add default interceptors
        interceptors.append(CommonHeadersInterceptor())
        interceptors.append(LoggingInterceptor())
    }

    func addInterceptor(_ interceptor: RequestInterceptor) {
        interceptors.append(interceptor)
    }

    func setAuthTokenProvider(_ provider: @escaping () -> String?) {
        interceptors.insert(AuthInterceptor(tokenProvider: provider), at: 0)
    }

    // MARK: - Request Methods

    /// Perform a request expecting a typed response
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        let response: APIResponse<T> = try await performRequest(endpoint)

        guard response.success, let data = response.data else {
            throw APIError.httpError(
                statusCode: 400,
                message: response.error ?? response.message ?? "Request failed"
            )
        }

        return data
    }

    /// Perform a request expecting the raw APIResponse wrapper
    func requestRaw<T: Decodable>(
        _ endpoint: APIEndpoint
    ) async throws -> APIResponse<T> {
        return try await performRequest(endpoint)
    }

    /// Perform a request with no expected response data
    func requestVoid(_ endpoint: APIEndpoint) async throws {
        let _: APIResponse<EmptyResponse> = try await performRequest(endpoint)
    }

    // MARK: - Private

    private func performRequest<T: Decodable>(
        _ endpoint: APIEndpoint
    ) async throws -> T {
        // Check network connectivity
        let isConnected = await NetworkMonitor.shared.isConnected
        guard isConnected else {
            throw APIError.offline
        }

        // Build URL
        guard let url = URL(string: endpoint.path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)

        // Add query parameters
        if let queryParams = endpoint.queryParameters, !queryParams.isEmpty {
            urlComponents?.queryItems = queryParams.map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }

        guard let finalURL = urlComponents?.url else {
            throw APIError.invalidURL
        }

        // Build request
        var request = URLRequest(url: finalURL)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 30

        // Add body if present
        if let body = endpoint.body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw APIError.encodingError(error)
            }
        }

        // Apply interceptors
        for interceptor in interceptors {
            try await interceptor.intercept(&request)
        }

        // Perform request
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            logger.error("Network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        } catch {
            logger.error("Unknown error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        #if DEBUG
        logger.debug("Response [\(httpResponse.statusCode)]: \(String(data: data, encoding: .utf8) ?? "nil")")
        #endif

        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200...299:
            break // Success
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Int($0) }
            throw APIError.rateLimited(retryAfter: retryAfter)
        case 500...599:
            let errorMessage = try? decoder.decode(APIResponse<EmptyResponse>.self, from: data).error
            throw APIError.serverError(errorMessage)
        default:
            let errorMessage = try? decoder.decode(APIResponse<EmptyResponse>.self, from: data).error
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Decode response
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Decoding error: \(error)")
            throw APIError.decodingError(error)
        }
    }
}
```

### 7. API Endpoints

```swift
// Core/Networking/APIEndpoints.swift
import Foundation

/// Represents an API endpoint with all necessary request information
struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let body: Encodable?
    let queryParameters: [String: String]?

    init(
        path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        queryParameters: [String: String]? = nil
    ) {
        self.path = path
        self.method = method
        self.body = body
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

    static func createOrder(body: Encodable) -> APIEndpoint {
        APIEndpoint(path: "/api/orders", method: .post, body: body)
    }

    static func updateOrder(id: String, body: Encodable) -> APIEndpoint {
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

    static func updateDevice(id: String, body: Encodable) -> APIEndpoint {
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

    static func sendTicketMessage(id: String, body: Encodable) -> APIEndpoint {
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

    static func updateUserSettings(body: Encodable) -> APIEndpoint {
        APIEndpoint(path: "/api/user/settings", method: .patch, body: body)
    }
}
```

---

## Database Changes

None in this stage.

---

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| APIClient initializes | Create instance | No crash, baseURL set correctly |
| GET request succeeds | Mock 200 response | Decoded data returned |
| POST request encodes body | Send login request | Request body is JSON encoded |
| 401 throws unauthorized | Mock 401 response | `APIError.unauthorized` thrown |
| 404 throws notFound | Mock 404 response | `APIError.notFound` thrown |
| 500 throws serverError | Mock 500 response | `APIError.serverError` thrown |
| Network error handled | No network | `APIError.offline` thrown |
| Decoding error handled | Invalid JSON | `APIError.decodingError` thrown |
| Auth interceptor adds token | Set token provider | Authorization header present |
| Rate limit includes retry-after | Mock 429 with header | `retryAfter` value captured |

---

## Acceptance Checklist

- [ ] APIClient compiles without errors
- [ ] All endpoint definitions compile
- [ ] Error types have appropriate messages
- [ ] Network monitor detects connectivity changes
- [ ] Interceptors can be added and execute in order
- [ ] JSON encoding uses snake_case
- [ ] JSON decoding uses camelCase conversion
- [ ] Logging works in DEBUG builds
- [ ] Request timeout is configured (30s)
- [ ] All HTTP methods supported (GET, POST, PUT, PATCH, DELETE)

---

## Deployment

### Build Commands

```bash
# Build to verify compilation
xcodebuild -project "Repair Minder.xcodeproj" \
  -scheme "Repair Minder" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build
```

### Verification

1. Build project successfully
2. Add temporary test in ContentView to verify APIClient:

```swift
// Temporary test - remove after verification
Task {
    do {
        let stats: DashboardStats = try await APIClient.shared.request(
            .dashboardStats(),
            responseType: DashboardStats.self
        )
        print("API works: \(stats)")
    } catch {
        print("API error (expected without auth): \(error)")
    }
}
```

---

## Handoff Notes

**For Stage 03:**
- Use `APIClient.shared.setAuthTokenProvider()` to inject auth token
- Use `APIEndpoint.login()` for authentication
- Use `APIEndpoint.refreshToken()` for token refresh
- Error `APIError.unauthorized` indicates need to refresh or re-login
- `NetworkMonitor.shared.isConnected` can be observed for offline UI
