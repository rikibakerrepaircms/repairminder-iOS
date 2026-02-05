//
//  AuthModels.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Staff Login Request/Response

/// Staff login request body
struct StaffLoginRequest: Encodable {
    let email: String
    let password: String
}

/// Staff login response - always requires 2FA
struct StaffLoginResponse: Decodable {
    let requiresTwoFactor: Bool
    let userId: String
    let email: String
    let user: StaffLoginUser

    /// Partial user info returned from initial login
    struct StaffLoginUser: Decodable {
        let id: String
        let email: String
        let firstName: String?
        let lastName: String?
        let companyId: String
    }
}

// MARK: - 2FA Request/Response

/// Request body for 2FA code request
struct TwoFactorRequestBody: Encodable {
    let userId: String
    let email: String
}

/// Response from 2FA code request
struct TwoFactorRequestResponse: Decodable {
    let message: String
}

/// Request body for 2FA code verification
struct TwoFactorVerifyRequest: Encodable {
    let userId: String
    let code: String
}

/// Response from 2FA verification - contains full auth tokens
struct StaffAuthResponse: Decodable {
    let token: String
    let refreshToken: String
    let expiresIn: Int
    let user: User
    let company: Company
}

// MARK: - Magic Link Request/Response

/// Staff magic link request
struct MagicLinkRequest: Encodable {
    let email: String
}

/// Staff magic link request response
struct MagicLinkRequestResponse: Decodable {
    let message: String
}

/// Staff magic link code verification request
struct MagicLinkVerifyRequest: Encodable {
    let email: String
    let code: String
}

// MARK: - Customer Auth Request/Response

/// Customer magic link request
struct CustomerMagicLinkRequest: Encodable {
    let email: String
    let companyId: String?

    enum CodingKeys: String, CodingKey {
        case email
        case companyId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(email, forKey: .email)
        if let companyId = companyId {
            try container.encode(companyId, forKey: .companyId)
        }
    }
}

/// Customer magic link request response
struct CustomerMagicLinkResponse: Decodable {
    let message: String
}

/// Customer code verification request
struct CustomerVerifyCodeRequest: Encodable {
    let email: String
    let code: String
    let companyId: String?

    enum CodingKeys: String, CodingKey {
        case email
        case code
        case companyId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(email, forKey: .email)
        try container.encode(code, forKey: .code)
        if let companyId = companyId {
            try container.encode(companyId, forKey: .companyId)
        }
    }
}

/// Customer verify code response - either login or company selection
struct CustomerVerifyCodeResponse: Decodable {
    // Success case (single company)
    let token: String?
    let client: CustomerClient?
    let company: Company?

    // Multi-company case
    let requiresCompanySelection: Bool?
    let companies: [CompanySelectionItem]?
    let email: String?
    let code: String?

    /// Whether this response requires company selection
    var needsCompanySelection: Bool {
        requiresCompanySelection == true
    }
}

/// Customer auth success response (after company selection if needed)
struct CustomerAuthResponse: Decodable {
    let token: String
    let client: CustomerClient
    let company: Company
}

// MARK: - Get Current User Response

/// Response from /api/auth/me endpoint
struct GetCurrentUserResponse: Decodable {
    let user: User
    let company: Company
    let hasPassword: Bool
    let hasPasscode: Bool
    let passcodeEnabled: Bool
    let passcodeTimeoutMinutes: Int?
}

// MARK: - Customer Get Current User Response

/// Response from /api/customer/auth/me endpoint
struct CustomerGetCurrentUserResponse: Decodable {
    let client: CustomerClient
    let company: Company
}

// MARK: - Logout Response

/// Response from logout endpoint
struct LogoutResponse: Decodable {
    let success: Bool?
    let message: String?
}
