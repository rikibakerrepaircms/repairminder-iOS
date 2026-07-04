//
//  DeviceCompletionInfoModels.swift
//  Repair Minder
//

import Foundation

/// Response body for `GET /api/devices/:id/completion-data`
struct DeviceCompletionData: Decodable, Sendable {
    let lineItems: [CompletionLineItem]?
    let imageCounts: ImageCounts?

    struct CompletionLineItem: Decodable, Identifiable, Sendable {
        let id: String
        let description: String?
        let quantity: Int?
        let lineTotalIncVat: Double?
        let authorizationStatus: String?
    }

    struct ImageCounts: Decodable, Sendable {
        let preRepair: Int?
        let postRepair: Int?
        let total: Int?
    }
}

/// Response body for `GET /api/devices/:id/pending-items-count`
struct PendingItemsCount: Decodable, Sendable {
    let count: Int?
}

/// Response body (`data`) for `GET /api/orders/:orderId/devices/:deviceId/report`.
/// The `report` structured object is intentionally ignored for v1 — only the
/// server-rendered, print-ready `html` document is consumed by the app.
struct DeviceReportResponse: Decodable, Sendable {
    let html: String?
}
