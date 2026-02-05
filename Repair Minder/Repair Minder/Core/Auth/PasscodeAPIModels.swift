//
//  PasscodeAPIModels.swift
//  Repair Minder
//
//  Created on 05/02/2026.
//

import Foundation

// MARK: - Set Passcode

struct SetPasscodeRequest: Encodable {
    let passcode: String
}

struct SetPasscodeResponse: Decodable {
    let message: String
}

// MARK: - Verify Passcode

struct VerifyPasscodeRequest: Encodable {
    let passcode: String
}

struct VerifyPasscodeResponse: Decodable {
    let valid: Bool
    let passcodeHash: String?
    let passcodeSalt: String?
}

// MARK: - Change Passcode

struct ChangePasscodeRequest: Encodable {
    let currentPasscode: String
    let newPasscode: String
}

struct ChangePasscodeResponse: Decodable {
    let message: String
    let passcodeHash: String?
    let passcodeSalt: String?
}

// MARK: - Reset Passcode Request

struct ResetPasscodeRequestBody: Encodable {}

struct ResetPasscodeRequestResponse: Decodable {
    let message: String
}

// MARK: - Reset Passcode

struct ResetPasscodeRequest: Encodable {
    let code: String
    let newPasscode: String
}

struct ResetPasscodeResponse: Decodable {
    let message: String
    let passcodeHash: String?
    let passcodeSalt: String?
}

// MARK: - Toggle Passcode Enabled

struct TogglePasscodeEnabledRequest: Encodable {
    let enabled: Bool
}

struct TogglePasscodeEnabledResponse: Decodable {
    let passcodeEnabled: Bool
}

// MARK: - Passcode Timeout

struct PasscodeTimeoutRequest: Encodable {
    let minutes: Int
}

struct PasscodeTimeoutResponse: Decodable {
    let passcodeTimeoutMinutes: Int
}
