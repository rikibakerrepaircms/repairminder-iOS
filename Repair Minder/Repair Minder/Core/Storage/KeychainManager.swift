//
//  KeychainManager.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import Foundation
import Security

final class KeychainManager: Sendable {
    static let shared = KeychainManager()

    private let service = "com.mendmyi.Repair-Minder"

    enum KeychainKey: String, CaseIterable {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenExpiresAt = "token_expires_at"
        case userId = "user_id"
        case deviceToken = "device_token"
    }

    private init() {}

    // MARK: - Public API

    func save(_ value: String, for key: KeychainKey) throws {
        let data = Data(value.utf8)
        try save(data, for: key.rawValue)
    }

    func save(_ value: Date, for key: KeychainKey) throws {
        let timestamp = String(value.timeIntervalSince1970)
        try save(timestamp, for: key)
    }

    func getString(for key: KeychainKey) -> String? {
        guard let data = getData(for: key.rawValue) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func getDate(for key: KeychainKey) -> Date? {
        guard let string = getString(for: key),
              let timestamp = Double(string) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func delete(key: KeychainKey) {
        delete(key: key.rawValue)
    }

    func delete(for key: KeychainKey) {
        delete(key: key.rawValue)
    }

    func deleteAll() {
        KeychainKey.allCases.forEach { delete(key: $0) }
    }

    // MARK: - Private

    private func save(_ data: Data, for key: String) throws {
        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func getData(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .readFailed(let status):
            return "Failed to read from Keychain: \(status)"
        }
    }
}
