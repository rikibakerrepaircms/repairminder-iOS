//
//  DeviceImageService.swift
//  Repair Minder
//
//  Thin wrapper over APIClient for device image list/upload/delete.
//

import Foundation

@MainActor
struct DeviceImageService {
    let client: APIClient

    init(client: APIClient? = nil) {
        self.client = client ?? APIClient.shared
    }

    /// Device statuses that are pre-authorisation → photos tagged pre_repair.
    /// Mirrors PRE_AUTHORISED_STATUSES in the web DeviceImageGallery.
    static let preAuthorisedStatuses: Set<String> = [
        "device_received", "diagnosing", "ready_to_quote", "awaiting_authorisation"
    ]

    static func imageType(forDeviceStatus status: String) -> String {
        preAuthorisedStatuses.contains(status) ? "pre_repair" : "post_repair"
    }

    func fetchImages(orderId: String, deviceId: String) async throws -> [DeviceImageListItem] {
        try await client.request(.deviceImages(orderId: orderId, deviceId: deviceId))
    }

    /// Compress + upload. Returns the created image metadata.
    func upload(
        image: PlatformImageData,
        imageType: String,
        orderId: String,
        deviceId: String
    ) async throws -> DeviceImageUploadResult {
        try await client.uploadMultipart(
            .uploadDeviceImage(orderId: orderId, deviceId: deviceId),
            fileData: image.jpegData,
            fileName: image.fileName,
            mimeType: "image/jpeg",
            fields: ["image_type": imageType]
        )
    }

    func delete(orderId: String, deviceId: String, imageId: String) async throws {
        try await client.requestVoid(.deleteDeviceImage(orderId: orderId, deviceId: deviceId, imageId: imageId))
    }
}

/// A ready-to-upload JPEG. Constructed on iOS from a UIImage via ImageCompressor.
struct PlatformImageData: Sendable {
    let jpegData: Data
    let fileName: String
}
