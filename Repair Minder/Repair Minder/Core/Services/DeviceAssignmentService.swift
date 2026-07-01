//
//  DeviceAssignmentService.swift
//  Repair Minder
//
//  Inline engineer / sub-location reassignment for device rows, mirroring the
//  web /devices inline assignment column. Routes order devices to the device
//  endpoints and buyback-inventory rows to the buyback endpoint.
//

import Foundation

/// One sub-location option for the grouped sub-location dropdown.
/// Field names are snake_case in the API (`location_id`) and mapped via
/// `.convertFromSnakeCase` — do not add explicit CodingKeys.
struct SubLocationChoice: Decodable, Identifiable, Sendable, Equatable {
    let id: String
    let locationId: String
    let code: String
    let description: String?
    let type: String?
}

@MainActor
enum DeviceAssignmentService {

    /// Sub-locations for a location (`GET /api/locations/:id/sub-locations`).
    static func subLocations(locationId: String) async throws -> [SubLocationChoice] {
        try await APIClient.shared.request(.locationSubLocations(locationId: locationId))
    }

    /// Reassign the engineer (nil clears it). Buyback rows use the buyback endpoint.
    static func updateEngineer(device: DeviceListItem, engineerId: String?) async throws {
        let body: [String: AnyEncodable] = ["assigned_engineer_id": AnyEncodable(engineerId)]
        if device.source == "buyback" {
            try await APIClient.shared.requestVoid(.updateBuyback(buybackId: device.id), body: body)
        } else {
            try await APIClient.shared.requestVoid(.updateDeviceEngineer(deviceId: device.id), body: body)
        }
    }

    /// Reassign the sub-location (nil clears it). Buyback rows use the buyback endpoint.
    static func updateSubLocation(device: DeviceListItem, subLocationId: String?) async throws {
        let body: [String: AnyEncodable] = ["sub_location_id": AnyEncodable(subLocationId)]
        if device.source == "buyback" {
            try await APIClient.shared.requestVoid(.updateBuyback(buybackId: device.id), body: body)
        } else {
            try await APIClient.shared.requestVoid(.updateDeviceSubLocation(deviceId: device.id), body: body)
        }
    }
}
