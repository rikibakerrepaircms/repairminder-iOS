//
//  APIError.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

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
