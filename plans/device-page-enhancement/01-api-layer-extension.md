# Stage 01: API Layer Extension

## Objective
Add missing API endpoints and multipart upload capability to APIClient for device images, parts, accessories, and line items.

## Dependencies
`[Requires: None]` - This is the foundation stage

## Complexity
**Medium** - Requires adding multipart upload support to APIClient

---

## Files to Modify

### 1. `Core/Networking/APIEndpoints.swift`
Add new endpoint cases:
- Device images (list, upload, get, update, delete, reorder, file)
- Device parts (list, add, delete)
- Device accessories (list, add, return, delete)
- Order items already exist but verify completeness

### 2. `Core/Networking/APIClient.swift`
Add multipart form-data upload method for image uploads.

---

## Files to Create

### 1. `Core/Models/DeviceImageModels.swift`
Request/response models for image operations.

### 2. `Core/Models/DevicePartModels.swift`
Request/response models for parts operations.

### 3. `Core/Models/DeviceAccessoryModels.swift`
Request/response models for accessory operations.

---

## Implementation Details

### New Endpoints in APIEndpoints.swift

```swift
// MARK: - Device Images
case deviceImages(orderId: String, deviceId: String, imageType: String?)
case uploadDeviceImage(orderId: String, deviceId: String)
case deviceImage(orderId: String, deviceId: String, imageId: String)
case updateDeviceImage(orderId: String, deviceId: String, imageId: String)
case deleteDeviceImage(orderId: String, deviceId: String, imageId: String)
case reorderDeviceImages(orderId: String, deviceId: String)
case deviceImageFile(orderId: String, deviceId: String, imageId: String)

// MARK: - Device Parts
case deviceParts(orderId: String, deviceId: String)
case addDevicePart(orderId: String, deviceId: String)
case deleteDevicePart(orderId: String, deviceId: String, partId: String)

// MARK: - Device Accessories
case deviceAccessories(orderId: String, deviceId: String)
case addDeviceAccessory(orderId: String, deviceId: String)
case returnDeviceAccessory(orderId: String, deviceId: String, accessoryId: String)
case deleteDeviceAccessory(orderId: String, deviceId: String, accessoryId: String)
```

### Path Implementation

```swift
// Device Images
case .deviceImages(let orderId, let deviceId, _), .uploadDeviceImage(let orderId, let deviceId):
    return "/api/orders/\(orderId)/devices/\(deviceId)/images"
case .deviceImage(let orderId, let deviceId, let imageId),
     .updateDeviceImage(let orderId, let deviceId, let imageId),
     .deleteDeviceImage(let orderId, let deviceId, let imageId):
    return "/api/orders/\(orderId)/devices/\(deviceId)/images/\(imageId)"
case .reorderDeviceImages(let orderId, let deviceId):
    return "/api/orders/\(orderId)/devices/\(deviceId)/images/reorder"
case .deviceImageFile(let orderId, let deviceId, let imageId):
    return "/api/orders/\(orderId)/devices/\(deviceId)/images/\(imageId)/file"

// Device Parts
case .deviceParts(let orderId, let deviceId), .addDevicePart(let orderId, let deviceId):
    return "/api/orders/\(orderId)/devices/\(deviceId)/parts"
case .deleteDevicePart(let orderId, let deviceId, let partId):
    return "/api/orders/\(orderId)/devices/\(deviceId)/parts/\(partId)"

// Device Accessories
case .deviceAccessories(let orderId, let deviceId), .addDeviceAccessory(let orderId, let deviceId):
    return "/api/orders/\(orderId)/devices/\(deviceId)/accessories"
case .returnDeviceAccessory(let orderId, let deviceId, let accessoryId):
    return "/api/orders/\(orderId)/devices/\(deviceId)/accessories/\(accessoryId)/return"
case .deleteDeviceAccessory(let orderId, let deviceId, let accessoryId):
    return "/api/orders/\(orderId)/devices/\(deviceId)/accessories/\(accessoryId)"
```

### Multipart Upload in APIClient.swift

```swift
/// Upload an image using multipart/form-data
/// - Parameters:
///   - endpoint: The upload endpoint
///   - imageData: JPEG image data
///   - imageType: Type of image (pre_repair, post_repair, etc.)
///   - caption: Optional caption
/// - Returns: The created image metadata
func uploadImage(
    _ endpoint: APIEndpoint,
    imageData: Data,
    filename: String,
    imageType: String,
    caption: String?
) async throws -> DeviceImageInfo {
    let boundary = "Boundary-\(UUID().uuidString)"

    var request = try buildRequest(endpoint, body: nil)
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()

    // Add image_type field
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"image_type\"\r\n\r\n".data(using: .utf8)!)
    body.append("\(imageType)\r\n".data(using: .utf8)!)

    // Add caption field if provided
    if let caption = caption {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(caption)\r\n".data(using: .utf8)!)
    }

    // Add file field
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    body.append(imageData)
    body.append("\r\n".data(using: .utf8)!)

    // Close boundary
    body.append("--\(boundary)--\r\n".data(using: .utf8)!)

    request.httpBody = body

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.networkError(URLError(.badServerResponse))
    }

    guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
        throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
    }

    let apiResponse: APIResponse<DeviceImageInfo> = try decoder.decode(APIResponse<DeviceImageInfo>.self, from: data)

    guard apiResponse.success, let imageInfo = apiResponse.data else {
        throw APIError.serverError(message: apiResponse.error ?? "Upload failed", code: apiResponse.code)
    }

    return imageInfo
}

/// Download image data from authenticated endpoint
func downloadImage(_ endpoint: APIEndpoint) async throws -> Data {
    let request = try buildRequest(endpoint, body: nil)

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.networkError(URLError(.badServerResponse))
    }

    guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
        throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
    }

    return data
}
```

### DeviceImageModels.swift

```swift
import Foundation

// MARK: - Image Type

enum DeviceImageType: String, Codable, CaseIterable, Sendable {
    case preRepair = "pre_repair"
    case postRepair = "post_repair"
    case damage = "damage"
    case diagnostic = "diagnostic"
    case part = "part"

    var displayName: String {
        switch self {
        case .preRepair: return "Pre-Repair"
        case .postRepair: return "Post-Repair"
        case .damage: return "Damage"
        case .diagnostic: return "Diagnostic"
        case .part: return "Part"
        }
    }

    var icon: String {
        switch self {
        case .preRepair: return "camera"
        case .postRepair: return "checkmark.circle"
        case .damage: return "exclamationmark.triangle"
        case .diagnostic: return "magnifyingglass"
        case .part: return "gearshape"
        }
    }
}

// MARK: - Image List Response

struct DeviceImagesResponse: Decodable, Sendable {
    let images: [DeviceImageInfo]
    let counts: ImageTypeCounts
}

struct ImageTypeCounts: Decodable, Sendable {
    let preRepair: Int?
    let postRepair: Int?
    let damage: Int?
    let diagnostic: Int?
    let part: Int?

    var total: Int {
        (preRepair ?? 0) + (postRepair ?? 0) + (damage ?? 0) + (diagnostic ?? 0) + (part ?? 0)
    }
}

// MARK: - Update Image Request

struct UpdateDeviceImageRequest: Encodable, Sendable {
    let caption: String?
    let imageType: String?
    let sortOrder: Int?
}

// MARK: - Reorder Images Request

struct ReorderDeviceImagesRequest: Encodable, Sendable {
    let imageType: String
    let order: [String]  // Array of image IDs
}
```

### DevicePartModels.swift

```swift
import Foundation

// MARK: - Add Part Request

struct AddDevicePartRequest: Encodable, Sendable {
    let partName: String
    let partSku: String?
    let partCost: Double?
    let supplier: String?
    let isOem: Bool?
    let warrantyDays: Int?
}

// MARK: - Parts List Response

struct DevicePartsResponse: Decodable, Sendable {
    let parts: [DevicePart]
}
```

### DeviceAccessoryModels.swift

```swift
import Foundation

// MARK: - Accessory Type

enum AccessoryType: String, Codable, CaseIterable, Sendable {
    case charger
    case cable
    case case_ = "case"
    case simCard = "sim_card"
    case stylus
    case box
    case sdCard = "sd_card"
    case other

    var displayName: String {
        switch self {
        case .charger: return "Charger"
        case .cable: return "Cable"
        case .case_: return "Case"
        case .simCard: return "SIM Card"
        case .stylus: return "Stylus"
        case .box: return "Box"
        case .sdCard: return "SD Card"
        case .other: return "Other"
        }
    }
}

// MARK: - Add Accessory Request

struct AddDeviceAccessoryRequest: Encodable, Sendable {
    let accessoryType: String
    let description: String?
}

// MARK: - Accessories List Response

struct DeviceAccessoriesResponse: Decodable, Sendable {
    let accessories: [DeviceAccessory]
}
```

---

## Database Changes
None - iOS only (backend already has schema)

---

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| List images endpoint builds correct URL | orderId="123", deviceId="456" | `/api/orders/123/devices/456/images` |
| Upload endpoint uses POST | uploadDeviceImage | method == .post |
| Multipart body contains boundary | imageData, imageType | Body starts with `--Boundary-` |
| Image type query param added | imageType="pre_repair" | URL contains `?image_type=pre_repair` |
| Parts endpoint correct | orderId, deviceId, partId | `/api/orders/.../devices/.../parts/...` |

---

## Acceptance Checklist

- [ ] All new endpoint cases added to APIEndpoint enum
- [ ] Path property returns correct URLs for all new endpoints
- [ ] Method property returns correct HTTP method for each
- [ ] Query items added for image type filter
- [ ] Multipart upload method added to APIClient
- [ ] Image download method added to APIClient
- [ ] All request/response models created
- [ ] Build passes with no errors
- [ ] Endpoints work with existing authentication

---

## Deployment
```bash
# Build to verify no compile errors
xcodebuild -scheme "Repair Minder" -destination "generic/platform=iOS Simulator" build
```

---

## Handoff Notes
- The `uploadImage` method returns `DeviceImageInfo` which already exists in `DeviceDetail.swift`
- Stage 02 will use these endpoints via a new `ImageService`
- The multipart boundary uses UUID for uniqueness
- Image data should be JPEG compressed before calling `uploadImage`
