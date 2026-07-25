//
//  RMCheckService.swift
//  Repair Minder
//
//  Thin wrapper over APIClient for the device identity lookup.
//

import Foundation

@MainActor
struct RMCheckService {
    let client: APIClient

    init(client: APIClient? = nil) {
        self.client = client ?? APIClient.shared
    }

    /// Look up a device by IMEI or serial. The backend detects the brand and
    /// picks the lookup service, checks its own cache and the provider's
    /// history for free first, and only then pays for a fresh lookup.
    ///
    /// `forBuyback` asks the backend to run the blacklist check as well and
    /// merge it into the same device object. It is the expensive call ($0.10
    /// against $0.037 for the Apple identity pair) and cached for 5 days, but it
    /// is the only thing that can tell us a device we are about to pay cash for
    /// is reported lost or stolen.
    func lookup(identifier: String, forBuyback: Bool = false) async throws -> RMCheckLookupResult {
        try await client.request(.rmcheckLookup, body: RMCheckLookupRequest(
            imeiOrSerial: identifier,
            contextType: forBuyback ? "buyback" : "order",
            useCached: true,
            checkBlacklist: forBuyback
        ))
    }

    /// Re-read the activation lock on its own.
    ///
    /// Service 3 is the one check a customer can fix while standing at the
    /// counter - they sign out of iCloud and we ask again. Uncached server-side,
    /// because the whole point is to see whether the answer changed, and $0.015
    /// rather than re-running the $0.037 identity pair.
    func recheckFindMy(identifier: String) async throws -> FmiRecheckResult {
        try await client.request(.rmcheckFmi, body: FmiRecheckRequest(imeiOrSerial: identifier))
    }
}

/// Outcome of a standalone Find My re-read. `findMyStatus` is nil when the
/// provider could not give a definitive ON or OFF - which must never be written
/// to the device as "off".
struct FmiRecheckResult: Decodable, Sendable {
    let findMyStatus: String?
    let resolved: Bool?
    let rmcheckLookupId: String?
}

private struct FmiRecheckRequest: Encodable {
    let imeiOrSerial: String
}

private struct RMCheckLookupRequest: Encodable {
    let imeiOrSerial: String
    let contextType: String
    let useCached: Bool
    let checkBlacklist: Bool
}
