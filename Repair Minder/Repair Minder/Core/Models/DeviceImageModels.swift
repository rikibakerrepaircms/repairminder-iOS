//
//  DeviceImageModels.swift
//  Repair Minder
//
//  Response shapes for the device image list/upload endpoints.
//  Field names are snake_case in the API and mapped via the client's
//  .convertFromSnakeCase strategy — do NOT add explicit CodingKeys.
//

import Foundation

/// One image from GET /api/orders/:orderId/devices/:deviceId/images
struct DeviceImageListItem: Decodable, Identifiable, Sendable {
    let id: String
    let imageType: String
    let url: String
    let filename: String?
    let sizeBytes: Int?
    let caption: String?
    let sortOrder: Int
    let uploadedAt: String
    let uploadedBy: Uploader?

    struct Uploader: Decodable, Sendable {
        let id: String
        let name: String?
    }

    var isPreRepair: Bool { imageType == "pre_repair" }
    var isPostRepair: Bool { imageType == "post_repair" }
}

/// The `data` payload from POST .../images (201).
struct DeviceImageUploadResult: Decodable, Sendable {
    let id: String
    let url: String
    let filename: String?
    let contentType: String?
    let sizeBytes: Int?
    let imageType: String
    let caption: String?
}
