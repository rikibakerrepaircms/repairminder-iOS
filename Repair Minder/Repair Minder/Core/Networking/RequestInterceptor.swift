//
//  RequestInterceptor.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

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
    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "API")

    func intercept(_ request: inout URLRequest) async throws {
        #if DEBUG
        let method = request.httpMethod ?? "?"
        let urlString = request.url?.absoluteString ?? "nil"
        logger.debug("[\(method)] \(urlString)")
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
