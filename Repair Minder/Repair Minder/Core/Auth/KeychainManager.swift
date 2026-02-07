//
//  KeychainManager.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import Security

/// Manages secure storage of authentication tokens in the iOS Keychain
/// Uses `.afterFirstUnlock` accessibility for background refresh support
final class KeychainManager {

    // MARK: - Singleton

    static let shared = KeychainManager()

    // MARK: - Keys

    private enum Keys {
        static let accessToken = "com.repairminder.accessToken"
        static let refreshToken = "com.repairminder.refreshToken"
        static let customerAccessToken = "com.repairminder.customer.accessToken"
        static let userData = "com.repairminder.userData"
        static let customerData = "com.repairminder.customerData"
        static let companyData = "com.repairminder.companyData"
        static let passcodeHash = "com.repairminder.passcodeHash"
        static let passcodeSalt = "com.repairminder.passcodeSalt"
        static let biometricEnabled = "com.repairminder.biometricEnabled"
        static let passcodeTimeout = "com.repairminder.passcodeTimeout"
        static let passcodeEnabled = "com.repairminder.passcodeEnabled"
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Staff Token Management

    /// Stores the staff access token
    func setAccessToken(_ token: String) {
        set(token, forKey: Keys.accessToken)
    }

    /// Retrieves the staff access token
    func getAccessToken() -> String? {
        get(forKey: Keys.accessToken)
    }

    /// Stores the staff refresh token
    func setRefreshToken(_ token: String) {
        set(token, forKey: Keys.refreshToken)
    }

    /// Retrieves the staff refresh token
    func getRefreshToken() -> String? {
        get(forKey: Keys.refreshToken)
    }

    /// Clears all staff tokens
    func clearStaffTokens() {
        delete(forKey: Keys.accessToken)
        delete(forKey: Keys.refreshToken)
        delete(forKey: Keys.userData)
        delete(forKey: Keys.companyData)
    }

    // MARK: - Customer Token Management

    /// Stores the customer access token
    func setCustomerAccessToken(_ token: String) {
        set(token, forKey: Keys.customerAccessToken)
    }

    /// Retrieves the customer access token
    func getCustomerAccessToken() -> String? {
        get(forKey: Keys.customerAccessToken)
    }

    /// Clears customer tokens
    func clearCustomerTokens() {
        delete(forKey: Keys.customerAccessToken)
        delete(forKey: Keys.customerData)
        delete(forKey: Keys.companyData)
    }

    // MARK: - User/Client Data Storage

    /// Stores the staff user data
    func setUser(_ user: User) {
        setEncodable(user, forKey: Keys.userData)
    }

    /// Retrieves the staff user data
    func getUser() -> User? {
        getDecodable(forKey: Keys.userData)
    }

    /// Stores the customer client data
    func setCustomerClient(_ client: CustomerClient) {
        setEncodable(client, forKey: Keys.customerData)
    }

    /// Retrieves the customer client data
    func getCustomerClient() -> CustomerClient? {
        getDecodable(forKey: Keys.customerData)
    }

    /// Stores the company data
    func setCompany(_ company: Company) {
        setEncodable(company, forKey: Keys.companyData)
    }

    /// Retrieves the company data
    func getCompany() -> Company? {
        getDecodable(forKey: Keys.companyData)
    }

    // MARK: - Passcode Cache

    func setPasscodeHash(_ hash: String) { set(hash, forKey: Keys.passcodeHash) }
    func getPasscodeHash() -> String? { get(forKey: Keys.passcodeHash) }

    func setPasscodeSalt(_ salt: String) { set(salt, forKey: Keys.passcodeSalt) }
    func getPasscodeSalt() -> String? { get(forKey: Keys.passcodeSalt) }

    func setBiometricEnabled(_ enabled: Bool) { set(enabled ? "1" : "0", forKey: Keys.biometricEnabled) }
    func isBiometricEnabled() -> Bool { get(forKey: Keys.biometricEnabled) == "1" }

    func setPasscodeEnabled(_ enabled: Bool) { set(enabled ? "1" : "0", forKey: Keys.passcodeEnabled) }
    func isPasscodeEnabled() -> Bool { get(forKey: Keys.passcodeEnabled) == "1" }

    func setPasscodeTimeout(_ minutes: Int) { set(String(minutes), forKey: Keys.passcodeTimeout) }
    func getPasscodeTimeout() -> Int? {
        guard let str = get(forKey: Keys.passcodeTimeout) else { return nil }
        return Int(str)
    }

    func clearPasscodeData() {
        delete(forKey: Keys.passcodeHash)
        delete(forKey: Keys.passcodeSalt)
        delete(forKey: Keys.biometricEnabled)
        delete(forKey: Keys.passcodeTimeout)
        delete(forKey: Keys.passcodeEnabled)
    }

    // MARK: - Clear All

    /// Clears all stored data (full logout)
    func clearAll() {
        clearStaffTokens()
        clearCustomerTokens()
        clearPasscodeData()
    }

    // MARK: - Private Keychain Operations

    private func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            #if DEBUG
            print("[Keychain] Failed to set value for key \(key): \(status)")
            #endif
        }
    }

    private func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return string
    }

    private func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    private func setEncodable<T: Encodable>(_ value: T, forKey key: String) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8)
        else {
            return
        }

        set(string, forKey: key)
    }

    private func getDecodable<T: Decodable>(forKey key: String) -> T? {
        guard let string = get(forKey: key),
              let data = string.data(using: .utf8)
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try? decoder.decode(T.self, from: data)
    }
}
