//
//  APIClient.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import Foundation
import os.log

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "APIClient")

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

    /// Perform a request expecting a custom response type (not wrapped in APIResponse)
    func requestDirect<T: Decodable>(
        _ endpoint: APIEndpoint
    ) async throws -> T {
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

    /// Perform a request expecting a custom response type (not wrapped in APIResponse)
    private func performRequestDirect<T: Decodable>(
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
            throw APIError.serverError(nil)
        default:
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }

        // Decode response directly (no APIResponse wrapper)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Decoding error: \(error)")
            throw APIError.decodingError(error)
        }
    }
}
