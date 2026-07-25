//
//  RMCheckDevice.swift
//  Repair Minder
//

import Foundation

/// Device identity and status returned by POST /api/rmcheck/lookup.
/// Field names match the object assembled in worker/src/services/rmcheck.js -
/// decoding uses .convertFromSnakeCase, so no CodingKeys are needed. Every
/// field is optional because which ones come back depends on the brand and on
/// which lookup service answered.
struct RMCheckDevice: Decodable, Sendable {
    let brand: String?
    let model: String?
    let modelNumber: String?
    let serialNumber: String?
    let imei: String?
    let colour: String?
    let storageCapacity: String?
    let findMyStatus: String?
    let icloudStatus: String?
    let blacklistStatus: String?
    /// Parsed server-side. More reliable than matching the display string, which
    /// arrives wrapped in markup and in several spellings.
    let isBlacklistedFlag: Bool?
    let simLockStatus: String?
    let warrantyStatus: String?

    enum CodingKeys: String, CodingKey {
        case brand, model, modelNumber, serialNumber, imei, colour, storageCapacity
        case findMyStatus, icloudStatus, blacklistStatus, simLockStatus, warrantyStatus
        // The API field is `is_blacklisted`, which .convertFromSnakeCase maps to
        // `isBlacklisted` - already taken by the computed property below.
        case isBlacklistedFlag = "isBlacklisted"
    }

    /// Lock states come back as "ON" / "OFF".
    private func isOn(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespaces).uppercased() == "ON"
    }

    private func hasValue(_ value: String?) -> Bool {
        !(value?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
    }

    var isBlacklisted: Bool {
        if let flag = isBlacklistedFlag { return flag }
        guard let value = blacklistStatus?.lowercased() else { return false }
        return value.contains("blacklist") || value.contains("lost") || value.contains("stolen")
    }

    /// Short human summary of anything that should stop a purchase, or nil when
    /// the device is clean. This is what gates handing over cash at the door.
    ///
    /// Only CONFIRMED problems appear here. See `unconfirmedChecks` for the
    /// things we could not establish either way.
    var warningSummary: String? {
        var problems: [String] = []
        if isOn(findMyStatus) || isOn(icloudStatus) { problems.append("Find My is still on") }
        if isBlacklisted { problems.append("reported lost or stolen") }
        guard !problems.isEmpty else { return nil }
        return problems.joined(separator: " and ")
    }

    /// What we could NOT confirm.
    ///
    /// Absence is not innocence. SICKW withdrew the Apple lookup service on
    /// 2026-07-16 and the lock field simply stopped arriving, so every iPhone
    /// showed a clean check for nine days. The blacklist field was never
    /// populated by anything at all. A buyer handing over cash has to be able to
    /// tell "checked and clean" from "never asked".
    var unconfirmedChecks: [String] {
        var unknown: [String] = []
        if !hasValue(findMyStatus) && !hasValue(icloudStatus) {
            unknown.append("Find My / activation lock")
        }
        if isBlacklistedFlag == nil && !hasValue(blacklistStatus) {
            unknown.append("blacklist (lost or stolen)")
        }
        return unknown
    }
}

/// Envelope for the lookup. APIClient unwraps `data`, so this is the inner object.
struct RMCheckLookupResult: Decodable, Sendable {
    let device: RMCheckDevice
    let cached: Bool?
    /// Present when the blacklist provider could not be reached, in which case
    /// the device object carries no status rather than a misleading clean one.
    let blacklistError: String?
}
