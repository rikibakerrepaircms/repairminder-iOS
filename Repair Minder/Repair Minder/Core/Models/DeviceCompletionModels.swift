//
//  DeviceCompletionModels.swift
//  Repair Minder
//
//  Created on 04/07/2026.
//

import Foundation

// MARK: - Collect

/// Request body for `POST /api/devices/:id/collect`.
/// Gate: device status must be `repaired_ready` or `rejection_ready`.
/// At least one of `signatureData`/`typedName` is required by the server (else 400).
struct DeviceCollectRequest: Encodable, Sendable {
    var signatureData: String?
    var typedName: String?
    var termsAgreed: Bool?
}

/// Response `data` payload from a successful device collect.
struct DeviceCollectResponse: Decodable, Sendable {
    let deviceId: String               // <- device_id
    let newStatus: String              // <- new_status
    let signatureId: String?           // <- signature_id
    let orderCompleted: Bool?          // <- order_completed
    let orderStatus: String?           // <- order_status
}

// MARK: - Despatch

/// Response `data` payload from a successful device despatch.
/// (Request body reuses `DespatchOrderRequest` from `Order.swift`.)
struct DeviceDespatchResponse: Decodable, Sendable {
    let deviceId: String                // <- device_id
    let newStatus: String               // <- new_status
    let carrier: String?
    let trackingNumber: String?         // <- tracking_number
    let emailSent: Bool?                // <- email_sent
    let orderCompleted: Bool?           // <- order_completed
    let orderStatus: String?            // <- order_status
}

// MARK: - Ready for Collection

/// Request body for `POST /api/devices/:id/ready-for-collection`.
/// Gate: device status must be `repaired_ready`. Body is optional — empty is fine.
struct DeviceReadyRequest: Encodable, Sendable {
    var collectionLocationId: String?
}

/// Response `data` payload from a successful ready-for-collection call.
struct DeviceReadyResponse: Decodable, Sendable {
    let message: String?
}

// MARK: - Accessories

/// Request body for `POST /api/orders/:orderId/devices/:deviceId/accessories`.
struct AddAccessoryRequest: Encodable, Sendable {
    var accessoryType: String
    var description: String?
}

/// Response `data` payload from a successful add-accessory call.
struct AddAccessoryResponse: Decodable, Sendable {
    let id: String
}
