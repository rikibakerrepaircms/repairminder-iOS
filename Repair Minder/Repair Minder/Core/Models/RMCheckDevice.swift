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
    let simLockStatus: String?
    let warrantyStatus: String?

    /// Lock states come back as "ON" / "OFF".
    private func isOn(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespaces).uppercased() == "ON"
    }

    var isBlacklisted: Bool {
        guard let value = blacklistStatus?.lowercased() else { return false }
        return value.contains("blacklist") || value.contains("lost") || value.contains("stolen")
    }

    /// Short human summary of anything that should stop a purchase, or nil when
    /// the device is clean. This is what gates handing over cash at the door.
    var warningSummary: String? {
        var problems: [String] = []
        if isOn(findMyStatus) || isOn(icloudStatus) { problems.append("Find My is still on") }
        if isBlacklisted { problems.append("reported lost or stolen") }
        guard !problems.isEmpty else { return nil }
        return problems.joined(separator: " and ")
    }
}

/// Envelope for the lookup. APIClient unwraps `data`, so this is the inner object.
struct RMCheckLookupResult: Decodable, Sendable {
    let device: RMCheckDevice
    let cached: Bool?
}
