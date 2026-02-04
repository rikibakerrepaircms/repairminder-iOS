//
//  AuthResponse.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import Foundation

/// Response from magic link verification
struct MagicLinkVerifyResponse: Decodable {
    let token: String
    let refreshToken: String
    let expiresIn: Int
    let user: User
    let company: Company
}

/// Response from token refresh endpoint
struct RefreshResponse: Decodable {
    let token: String
    let refreshToken: String
    let expiresIn: Int
}

/// Response from /api/auth/me endpoint
struct MeResponse: Decodable {
    let user: User
    let company: Company
}

/// Response from magic link request
struct MagicLinkRequestResponse: Decodable {
    let message: String
}
