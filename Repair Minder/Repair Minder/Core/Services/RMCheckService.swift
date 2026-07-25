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
    func lookup(identifier: String) async throws -> RMCheckLookupResult {
        try await client.request(.rmcheckLookup, body: RMCheckLookupRequest(
            imeiOrSerial: identifier,
            contextType: "order",
            useCached: true
        ))
    }
}

private struct RMCheckLookupRequest: Encodable {
    let imeiOrSerial: String
    let contextType: String
    let useCached: Bool
}
