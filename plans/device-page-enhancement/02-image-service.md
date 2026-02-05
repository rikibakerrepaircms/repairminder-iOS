# Stage 02: Image Service

## Objective
Create a dedicated service for loading, caching, and uploading device images with progress tracking.

## Dependencies
`[Requires: Stage 01 complete]` - Needs API endpoints and upload method

## Complexity
**Medium** - Involves image processing, caching, and async operations

---

## Files to Create

### 1. `Core/Services/ImageService.swift`
Main service for all image operations.

### 2. `Core/Services/ImageCache.swift`
In-memory and disk caching for images.

---

## Implementation Details

### ImageService.swift

```swift
import UIKit
import SwiftUI

// MARK: - Image Service

/// Service for loading, caching, and uploading device images
@MainActor
final class ImageService {

    // MARK: - Shared Instance

    static let shared = ImageService()

    // MARK: - Dependencies

    private let apiClient = APIClient.shared
    private let cache = ImageCache.shared

    // MARK: - Configuration

    /// Maximum image dimension for upload (will be resized if larger)
    private let maxUploadDimension: CGFloat = 2048

    /// JPEG compression quality for uploads
    private let uploadCompressionQuality: CGFloat = 0.8

    /// Thumbnail size for gallery grid
    let thumbnailSize = CGSize(width: 200, height: 200)

    // MARK: - Image Loading

    /// Load an image from the API with caching
    /// - Parameters:
    ///   - orderId: Order ID
    ///   - deviceId: Device ID
    ///   - imageId: Image ID
    ///   - thumbnail: Whether to load thumbnail size
    /// - Returns: The loaded UIImage
    func loadImage(
        orderId: String,
        deviceId: String,
        imageId: String,
        thumbnail: Bool = false
    ) async throws -> UIImage {
        let cacheKey = "\(orderId)/\(deviceId)/\(imageId)\(thumbnail ? "_thumb" : "")"

        // Check cache first
        if let cached = cache.image(forKey: cacheKey) {
            return cached
        }

        // Load from API
        let data = try await apiClient.downloadImage(
            .deviceImageFile(orderId: orderId, deviceId: deviceId, imageId: imageId)
        )

        guard let image = UIImage(data: data) else {
            throw ImageServiceError.invalidImageData
        }

        // Create thumbnail if requested
        let finalImage: UIImage
        if thumbnail {
            finalImage = image.preparingThumbnail(of: thumbnailSize) ?? image
        } else {
            finalImage = image
        }

        // Cache the result
        cache.setImage(finalImage, forKey: cacheKey)

        return finalImage
    }

    /// Load image as SwiftUI Image
    func loadSwiftUIImage(
        orderId: String,
        deviceId: String,
        imageId: String,
        thumbnail: Bool = false
    ) async throws -> Image {
        let uiImage = try await loadImage(
            orderId: orderId,
            deviceId: deviceId,
            imageId: imageId,
            thumbnail: thumbnail
        )
        return Image(uiImage: uiImage)
    }

    // MARK: - Image Upload

    /// Upload an image to a device
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - orderId: Order ID
    ///   - deviceId: Device ID
    ///   - imageType: Type of image
    ///   - caption: Optional caption
    ///   - progressHandler: Optional progress callback (0.0 to 1.0)
    /// - Returns: The created image info
    func uploadImage(
        _ image: UIImage,
        orderId: String,
        deviceId: String,
        imageType: DeviceImageType,
        caption: String? = nil,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> DeviceImageInfo {
        // Report initial progress
        progressHandler?(0.1)

        // Resize if needed
        let resizedImage = resizeImageIfNeeded(image)
        progressHandler?(0.2)

        // Convert to JPEG data
        guard let imageData = resizedImage.jpegData(compressionQuality: uploadCompressionQuality) else {
            throw ImageServiceError.compressionFailed
        }
        progressHandler?(0.4)

        // Generate filename
        let filename = "\(imageType.rawValue)_\(Int(Date().timeIntervalSince1970)).jpg"

        // Upload
        progressHandler?(0.5)
        let imageInfo = try await apiClient.uploadImage(
            .uploadDeviceImage(orderId: orderId, deviceId: deviceId),
            imageData: imageData,
            filename: filename,
            imageType: imageType.rawValue,
            caption: caption
        )
        progressHandler?(1.0)

        // Cache the uploaded image
        let cacheKey = "\(orderId)/\(deviceId)/\(imageInfo.id)"
        cache.setImage(resizedImage, forKey: cacheKey)

        return imageInfo
    }

    // MARK: - Image List

    /// Fetch list of images for a device
    func listImages(
        orderId: String,
        deviceId: String,
        imageType: DeviceImageType? = nil
    ) async throws -> DeviceImagesResponse {
        try await apiClient.request(
            .deviceImages(orderId: orderId, deviceId: deviceId, imageType: imageType?.rawValue)
        )
    }

    // MARK: - Image Management

    /// Delete an image
    func deleteImage(
        orderId: String,
        deviceId: String,
        imageId: String
    ) async throws {
        try await apiClient.requestVoid(
            .deleteDeviceImage(orderId: orderId, deviceId: deviceId, imageId: imageId)
        )

        // Clear from cache
        let cacheKey = "\(orderId)/\(deviceId)/\(imageId)"
        cache.removeImage(forKey: cacheKey)
        cache.removeImage(forKey: "\(cacheKey)_thumb")
    }

    /// Update image caption or type
    func updateImage(
        orderId: String,
        deviceId: String,
        imageId: String,
        caption: String? = nil,
        imageType: DeviceImageType? = nil
    ) async throws -> DeviceImageInfo {
        let request = UpdateDeviceImageRequest(
            caption: caption,
            imageType: imageType?.rawValue,
            sortOrder: nil
        )

        return try await apiClient.request(
            .updateDeviceImage(orderId: orderId, deviceId: deviceId, imageId: imageId),
            body: request
        )
    }

    // MARK: - Helpers

    private func resizeImageIfNeeded(_ image: UIImage) -> UIImage {
        let maxDimension = max(image.size.width, image.size.height)

        guard maxDimension > maxUploadDimension else {
            return image
        }

        let scale = maxUploadDimension / maxDimension
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Cache Management

    /// Clear all cached images
    func clearCache() {
        cache.clearAll()
    }

    /// Clear cached images for a specific device
    func clearCache(orderId: String, deviceId: String) {
        cache.clearMatching(prefix: "\(orderId)/\(deviceId)")
    }
}

// MARK: - Errors

enum ImageServiceError: LocalizedError {
    case invalidImageData
    case compressionFailed
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "The image data could not be read"
        case .compressionFailed:
            return "Failed to compress image for upload"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        }
    }
}
```

### ImageCache.swift

```swift
import UIKit

// MARK: - Image Cache

/// Thread-safe in-memory image cache with size limits
final class ImageCache: @unchecked Sendable {

    // MARK: - Shared Instance

    static let shared = ImageCache()

    // MARK: - Storage

    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()

    // MARK: - Configuration

    init() {
        // Limit cache size
        cache.countLimit = 100
        cache.totalCostLimit = 100 * 1024 * 1024  // 100MB

        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    // MARK: - Cache Operations

    func image(forKey key: String) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        // Use image size as cost
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func removeImage(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeObject(forKey: key as NSString)
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAllObjects()
    }

    func clearMatching(prefix: String) {
        // NSCache doesn't support enumeration, so we can't selectively clear
        // For now, just log - a more sophisticated implementation would track keys
        print("ImageCache: clearMatching not fully implemented, clearing all")
        clearAll()
    }

    // MARK: - Memory Management

    @objc private func handleMemoryWarning() {
        clearAll()
    }
}
```

---

## Database Changes
None

---

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Load image caches result | Load same image twice | Second load returns cached |
| Upload resizes large image | 4000x3000 image | Resized to max 2048 dimension |
| Upload generates JPEG | Any UIImage | Returns valid DeviceImageInfo |
| Delete clears cache | Delete image | Cache miss on next load |
| Thumbnail uses smaller size | thumbnail=true | Returns 200x200 image |

---

## Acceptance Checklist

- [ ] ImageService.swift created with all methods
- [ ] ImageCache.swift created with thread-safe operations
- [ ] loadImage returns cached images when available
- [ ] uploadImage resizes and compresses correctly
- [ ] Progress handler receives updates during upload
- [ ] Memory warning clears cache
- [ ] Build passes with no errors

---

## Deployment
```bash
xcodebuild -scheme "Repair Minder" -destination "generic/platform=iOS Simulator" build
```

---

## Handoff Notes
- Stage 03 will use `ImageService.shared` for loading images in the gallery
- Stage 04 will use `uploadImage` for camera captures
- The cache key format is `{orderId}/{deviceId}/{imageId}[_thumb]`
- Thumbnail size is 200x200, configurable via `thumbnailSize` property
