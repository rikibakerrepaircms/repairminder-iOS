//
//  APIClient.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Token Provider Protocol

/// Protocol for providing authentication tokens
/// Implemented by AuthManager in Stage 02
@MainActor
protocol TokenProvider: AnyObject {
    var accessToken: String? { get }
    var refreshToken: String? { get }
    func updateTokens(accessToken: String, refreshToken: String)
    func clearTokens()
}

// MARK: - API Client

/// Main HTTP client for all API requests
/// Handles authentication, token refresh, and response decoding
@MainActor
final class APIClient {

    // MARK: - Shared Instance

    static let shared = APIClient()

    // MARK: - Configuration

    private let baseURL = URL(string: "https://api.repairminder.com")!
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Token provider for authentication - set by AuthManager
    weak var tokenProvider: TokenProvider?

    /// Flag to prevent multiple simultaneous token refresh attempts
    private var isRefreshingToken = false

    /// Pending requests waiting for token refresh
    private var pendingRequests: [CheckedContinuation<Void, Error>] = []

    // MARK: - Initialization

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Public API

    /// Perform a request that expects a typed response
    /// - Parameters:
    ///   - endpoint: The API endpoint to call
    ///   - body: Optional request body (will be JSON encoded)
    /// - Returns: The decoded response data
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil
    ) async throws -> T {
        let response: APIResponse<T> = try await performRequest(endpoint, body: body)

        guard response.success, let data = response.data else {
            throw APIError.serverError(
                message: response.error ?? "Unknown error",
                code: response.code
            )
        }

        return data
    }

    /// Perform a request that returns a response with pagination
    /// - Parameters:
    ///   - endpoint: The API endpoint to call
    ///   - body: Optional request body (will be JSON encoded)
    /// - Returns: Tuple containing the decoded data and pagination info
    func requestWithPagination<T: Decodable>(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil
    ) async throws -> (data: T, pagination: Pagination?) {
        let response: APIResponse<T> = try await performRequest(endpoint, body: body)

        guard response.success, let data = response.data else {
            throw APIError.serverError(
                message: response.error ?? "Unknown error",
                code: response.code
            )
        }

        return (data, response.pagination)
    }

    /// Perform a request that returns a response with pagination and filters
    /// Used by list endpoints like devices and my-queue that include filter options
    /// - Parameters:
    ///   - endpoint: The API endpoint to call
    ///   - body: Optional request body (will be JSON encoded)
    /// - Returns: Tuple containing the decoded data, pagination, and filters
    func requestWithFilters<T: Decodable, F: Decodable>(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil
    ) async throws -> (data: T, pagination: Pagination?, filters: F?) {
        let response: APIResponseWithFilters<T, F> = try await performRequestWithFilters(endpoint, body: body)

        guard response.success, let data = response.data else {
            throw APIError.serverError(
                message: response.error ?? "Unknown error",
                code: response.code
            )
        }

        return (data, response.pagination, response.filters)
    }

    /// Perform a request that expects no response data
    /// - Parameters:
    ///   - endpoint: The API endpoint to call
    ///   - body: Optional request body (will be JSON encoded)
    func requestVoid(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil
    ) async throws {
        let response: APIResponse<EmptyResponse> = try await performRequest(endpoint, body: body)

        guard response.success else {
            throw APIError.serverError(
                message: response.error ?? "Unknown error",
                code: response.code
            )
        }
    }

    /// Perform a request that returns raw Data (e.g. HTML documents)
    /// - Parameters:
    ///   - endpoint: The API endpoint to call
    /// - Returns: The raw response data
    func requestRawData(
        _ endpoint: APIEndpoint
    ) async throws -> Data {
        let request = try buildRequest(endpoint)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(URLError(.badServerResponse))
            }

            switch httpResponse.statusCode {
            case 200...299:
                return data

            case 401:
                if endpoint.requiresAuth {
                    try await handleTokenRefresh()
                    // Retry after refresh
                    let retryRequest = try buildRequest(endpoint)
                    let (retryData, retryResponse) = try await session.data(for: retryRequest)
                    guard let retryHttp = retryResponse as? HTTPURLResponse,
                          (200...299).contains(retryHttp.statusCode) else {
                        throw APIError.unauthorized
                    }
                    return retryData
                }
                throw APIError.unauthorized

            case 404:
                throw APIError.notFound

            default:
                throw APIError.httpError(
                    statusCode: httpResponse.statusCode,
                    message: nil
                )
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError where error.code == .cancelled {
            throw APIError.cancelled
        } catch {
            throw APIError.networkError(error)
        }
    }

    /// Perform the raw token refresh request
    /// This is used by AuthManager and should not be called directly
    func refreshAccessToken() async throws -> TokenRefreshResponse {
        guard let refreshToken = tokenProvider?.refreshToken else {
            throw APIError.unauthorized
        }

        let body = ["refreshToken": refreshToken]
        let response: APIResponse<TokenRefreshResponse> = try await performRequest(
            .refreshToken,
            body: body,
            skipAuthRefresh: true
        )

        guard response.success, let data = response.data else {
            throw APIError.serverError(
                message: response.error ?? "Token refresh failed",
                code: response.code
            )
        }

        return data
    }

    // MARK: - Private Implementation

    private func performRequest<T: Decodable>(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil,
        skipAuthRefresh: Bool = false
    ) async throws -> APIResponse<T> {
        let request = try buildRequest(endpoint, body: body)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(URLError(.badServerResponse))
            }

            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Debug: print first 1000 chars of response for dashboard stats
                if endpoint.path.contains("dashboard") {
                    let responseString = String(data: data, encoding: .utf8) ?? "N/A"
                    #if DEBUG
                    print("🔍 [API] Response preview: \(responseString.prefix(1000))")
                    #endif
                }
                return try decodeResponse(data)

            case 401:
                // Unauthorized - try to refresh token if not already refreshing
                if !skipAuthRefresh && endpoint.requiresAuth {
                    try await handleTokenRefresh()
                    // Retry the original request
                    return try await performRequest(endpoint, body: body, skipAuthRefresh: true)
                }
                throw APIError.unauthorized

            case 403:
                let errorResponse = try? decodeResponse(data) as APIResponse<EmptyResponse>
                if errorResponse?.code == "CONSENT_REQUIRED" {
                    NotificationCenter.default.post(name: .consentRequired, object: nil)
                }
                throw APIError.forbidden(
                    message: errorResponse?.error,
                    code: errorResponse?.code
                )

            case 404:
                throw APIError.notFound

            case 429:
                throw APIError.rateLimited

            default:
                let errorResponse = try? decodeResponse(data) as APIResponse<EmptyResponse>
                throw APIError.httpError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse?.error
                )
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError where error.code == .cancelled {
            throw APIError.cancelled
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func buildRequest(_ endpoint: APIEndpoint, body: Encodable? = nil) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)!
        components.queryItems = endpoint.queryItems

        guard let url = components.url else {
            throw APIError.invalidRequest("Invalid URL")
        }

        #if DEBUG
        print("🌐 [API] \(endpoint.method.rawValue) \(url.absoluteString)")
        #endif

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        // Add headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        // Add authorization header if required
        if endpoint.requiresAuth, let token = tokenProvider?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add body if provided
        if let body = body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        return request
    }

    private func decodeResponse<T: Decodable>(_ data: Data) throws -> APIResponse<T> {
        do {
            return try decoder.decode(APIResponse<T>.self, from: data)
        } catch {
            #if DEBUG
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ DECODE ERROR - Key not found: '\(key.stringValue)' at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                case .typeMismatch(let type, let context):
                    print("❌ DECODE ERROR - Type mismatch: expected \(type) at path: \(context.codingPath.map(\.stringValue).joined(separator: ".")) - \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("❌ DECODE ERROR - Value not found: \(type) at path: \(context.codingPath.map(\.stringValue).joined(separator: ".")) - \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("❌ DECODE ERROR - Data corrupted at path: \(context.codingPath.map(\.stringValue).joined(separator: ".")) - \(context.debugDescription)")
                @unknown default:
                    print("❌ DECODE ERROR - Unknown: \(decodingError)")
                }
            }
            #endif
            throw APIError.decodingError(error)
        }
    }

    private func performRequestWithFilters<T: Decodable, F: Decodable>(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil,
        skipAuthRefresh: Bool = false
    ) async throws -> APIResponseWithFilters<T, F> {
        let request = try buildRequest(endpoint, body: body)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(URLError(.badServerResponse))
            }

            switch httpResponse.statusCode {
            case 200...299:
                // Debug logging for my-queue
                if endpoint.path.contains("my-queue") {
                    let responseString = String(data: data, encoding: .utf8) ?? "N/A"
                    #if DEBUG
                    print("🔍 [API] my-queue response: \(responseString.prefix(2000))")
                    #endif
                }
                do {
                    return try decoder.decode(APIResponseWithFilters<T, F>.self, from: data)
                } catch {
                    #if DEBUG
                    print("❌ [API] Decoding error for \(endpoint.path): \(error)")
                    #endif
                    throw error
                }

            case 401:
                if !skipAuthRefresh && endpoint.requiresAuth {
                    try await handleTokenRefresh()
                    return try await performRequestWithFilters(endpoint, body: body, skipAuthRefresh: true)
                }
                throw APIError.unauthorized

            case 403:
                let errorResponse = try? decodeResponse(data) as APIResponse<EmptyResponse>
                if errorResponse?.code == "CONSENT_REQUIRED" {
                    NotificationCenter.default.post(name: .consentRequired, object: nil)
                }
                throw APIError.forbidden(
                    message: errorResponse?.error,
                    code: errorResponse?.code
                )

            case 404:
                throw APIError.notFound

            case 429:
                throw APIError.rateLimited

            default:
                let errorResponse = try? decodeResponse(data) as APIResponse<EmptyResponse>
                throw APIError.httpError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse?.error
                )
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError where error.code == .cancelled {
            throw APIError.cancelled
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func handleTokenRefresh() async throws {
        // If already refreshing, wait for it to complete
        if isRefreshingToken {
            try await withCheckedThrowingContinuation { continuation in
                pendingRequests.append(continuation)
            }
            return
        }

        isRefreshingToken = true

        do {
            let response = try await refreshAccessToken()
            tokenProvider?.updateTokens(
                accessToken: response.token,
                refreshToken: response.refreshToken
            )

            // Resume pending requests
            for continuation in pendingRequests {
                continuation.resume()
            }
            pendingRequests.removeAll()
            isRefreshingToken = false

        } catch {
            // Clear tokens on refresh failure
            tokenProvider?.clearTokens()

            // Fail pending requests
            for continuation in pendingRequests {
                continuation.resume(throwing: APIError.unauthorized)
            }
            pendingRequests.removeAll()
            isRefreshingToken = false

            throw APIError.unauthorized
        }
    }

    /// User-Agent string that identifies the app as mobile for 90-day refresh tokens
    private var userAgent: String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        return "RepairMinder-iOS/\(appVersion).\(buildNumber) (iPhone; iOS \(osVersion))"
    }
}

// MARK: - AnyEncodable Helper

/// Type-erased Encodable wrapper for encoding request bodies
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        _encode = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
