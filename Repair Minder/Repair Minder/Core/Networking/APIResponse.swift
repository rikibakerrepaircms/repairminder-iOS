//
//  APIResponse.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

/// Standard API response wrapper
/// All backend endpoints return this envelope structure:
/// ```json
/// {
///   "success": true | false,
///   "data": T,
///   "pagination": { ... },  // Optional, only on list endpoints
///   "error": "..."          // Optional, only when success=false
/// }
/// ```
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let pagination: Pagination?
    let error: String?

    /// Additional error code for specific scenarios (e.g., "ACCOUNT_PENDING_APPROVAL")
    let code: String?
}

/// API response wrapper for endpoints that include filters (e.g., device list, my-queue)
struct APIResponseWithFilters<T: Decodable, F: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let pagination: Pagination?
    let filters: F?
    let error: String?
    let code: String?
}

/// Empty response for endpoints that return no data in the response body
struct EmptyResponse: Decodable {}

/// API error types
enum APIError: Error, LocalizedError {
    /// Network connectivity issues
    case networkError(Error)

    /// Server returned an error in the response envelope
    case serverError(message: String, code: String?)

    /// HTTP status code indicates failure (non-2xx)
    case httpError(statusCode: Int, message: String?)

    /// Failed to decode the response
    case decodingError(Error)

    /// Authentication required - token missing or invalid
    case unauthorized

    /// Access denied - insufficient permissions
    case forbidden(message: String?, code: String?)

    /// Resource not found
    case notFound

    /// Rate limited - too many requests
    case rateLimited

    /// Request was cancelled
    case cancelled

    /// Invalid request (client-side error)
    case invalidRequest(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message, _):
            return message
        case .httpError(let statusCode, let message):
            if let message = message {
                return message
            }
            return "HTTP error \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unauthorized:
            return "Authentication required"
        case .forbidden(let message, _):
            return message ?? "Access denied"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .cancelled:
            return "Request was cancelled"
        case .invalidRequest(let message):
            return message
        }
    }

    /// Whether this error should trigger a logout
    var requiresLogout: Bool {
        if case .unauthorized = self {
            return true
        }
        return false
    }

    /// Error code from server (e.g., "ACCOUNT_PENDING_APPROVAL")
    var serverCode: String? {
        switch self {
        case .serverError(_, let code):
            return code
        case .forbidden(_, let code):
            return code
        default:
            return nil
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the API returns a 403 with code CONSENT_REQUIRED
    /// Observed by AppState to transition to the terms-required blocking screen
    static let consentRequired = Notification.Name("consentRequired")
}

/// Token refresh response from `/api/auth/refresh`
struct TokenRefreshResponse: Decodable {
    let token: String
    let refreshToken: String
    let expiresIn: Int
}
