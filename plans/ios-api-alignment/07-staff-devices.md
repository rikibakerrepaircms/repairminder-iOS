# Stage 07: Staff Devices

## Objective

Fix device list and detail view models to work with the completely rewritten Device model.

## Dependencies

- **Requires**: Stage 01 complete (Device model rewritten)
- **Requires**: Stage 04 complete (API client working)

## Complexity

**Medium** - Device model changed significantly, many UI updates needed

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Features/Devices/DeviceListViewModel.swift` | Update for new model |
| `Repair Minder/Features/Devices/DeviceListView.swift` | Update bindings |
| `Repair Minder/Features/Devices/DeviceDetailViewModel.swift` | Update for new model |
| `Repair Minder/Features/Devices/DeviceDetailView.swift` | Update bindings |
| `Repair Minder/Features/Devices/Components/DeviceHeaderCard.swift` | Update property access |
| `Repair Minder/Features/Devices/Components/DeviceInfoCard.swift` | Update property access |
| `Repair Minder/Features/Devices/Components/DeviceStatusActions.swift` | Update status handling |
| `Repair Minder/Shared/Components/DeviceStatusBadge.swift` | Verify status enum |

## Backend Reference

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `GET /api/devices` | GET | List devices with pagination |
| `GET /api/devices/:id` | GET | Single device detail |
| `GET /api/devices/my-queue` | GET | User's assigned devices |
| `PATCH /api/devices/:id` | PATCH | Update device status |

## Implementation Details

### 1. Property Mapping Changes

| Old Property | New Property | Notes |
|--------------|--------------|-------|
| `device.type` | `device.deviceType?.name` | Nested object |
| `device.brand` | Use `device.displayName` | Combined in displayName |
| `device.model` | Use `device.displayName` | Combined in displayName |
| `device.serial` | `device.serialNumber` | Renamed |
| `device.assignedUserId` | `device.assignedEngineer?.id` | Nested object |
| `device.assignedUserName` | `device.assignedEngineer?.name` | Nested object |
| `device.issue` | Use notes or removed | Not in backend |
| `device.diagnosis` | Use notes or removed | Not in backend |
| `device.resolution` | Use notes or removed | Not in backend |
| `device.price` | Removed | Not in device response |

### 2. DeviceListViewModel

```swift
@MainActor
@Observable
final class DeviceListViewModel {
    private(set) var devices: [Device] = []
    private(set) var isLoading = false
    var error: String?
    var statusFilter: DeviceStatus?

    func loadDevices() async {
        isLoading = true

        do {
            let response: PaginatedResponse<Device> = try await APIClient.shared.request(
                .devices(status: statusFilter?.rawValue),
                responseType: PaginatedResponse<Device>.self
            )
            devices = response.data
        } catch {
            self.error = "Failed to load devices"
        }

        isLoading = false
    }
}
```

### 3. DeviceDetailViewModel

```swift
@MainActor
@Observable
final class DeviceDetailViewModel {
    let deviceId: String
    private(set) var device: Device?
    private(set) var isLoading = false
    var error: String?

    func loadDevice() async {
        isLoading = true

        do {
            device = try await APIClient.shared.request(
                .device(id: deviceId),
                responseType: Device.self
            )
        } catch {
            self.error = "Failed to load device"
        }

        isLoading = false
    }

    func updateStatus(to newStatus: DeviceStatus) async {
        guard let device = device else { return }

        do {
            struct StatusUpdate: Encodable {
                let status: String
            }
            try await APIClient.shared.requestVoid(
                .updateDevice(id: device.id, body: StatusUpdate(status: newStatus.rawValue))
            )
            // Reload to get updated device
            await loadDevice()
        } catch {
            self.error = "Failed to update status"
        }
    }
}
```

### 4. UI Component Updates

**DeviceHeaderCard.swift**:
```swift
// OLD
Text(device.brand ?? "")
Text(device.model ?? "")

// NEW
Text(device.displayName)
if let type = device.deviceType?.name {
    Text(type)
}
```

**DeviceInfoCard.swift**:
```swift
// OLD
if let serial = device.serial { ... }

// NEW
if let serial = device.serialNumber { ... }

// OLD
if let assignee = device.assignedUserName { ... }

// NEW
if let assignee = device.assignedEngineer?.name { ... }

// NEW - additional info available
if let colour = device.colour { ... }
if let location = device.subLocation?.description { ... }
if let dueDate = device.dueDate { ... }
```

**DeviceStatusBadge.swift**:
```swift
// Verify DeviceStatus enum values match
// Should already be correct from Stage 01
```

### 5. Remove References to Removed Properties

Search for and remove/update any references to:
- `device.issue`
- `device.diagnosis`
- `device.resolution`
- `device.price`
- `device.passcode`

These fields don't exist in the backend device response.

## Database Changes

None

## Test Cases

| Test | Expected |
|------|----------|
| Device list loads | Devices shown with displayName |
| Device status filter | Filtered list displayed |
| Device detail loads | All device info displayed |
| Update device status | Status changes and updates |
| Assigned engineer shown | Engineer name from nested object |
| Location shown | SubLocation description displayed |

## Acceptance Checklist

- [ ] Device list compiles and loads
- [ ] Device list rows show `displayName`
- [ ] Device detail compiles and loads
- [ ] DeviceHeaderCard uses `displayName`
- [ ] DeviceInfoCard uses `serialNumber` not `serial`
- [ ] Assigned engineer shows from nested object
- [ ] No references to removed properties (`issue`, `diagnosis`, etc.)
- [ ] Status update works
- [ ] DeviceStatusBadge shows correct colors

## Deployment

1. Build and run app
2. Navigate to Devices tab
3. Verify list loads with device names
4. Tap a device to view detail
5. Test status update
6. Check Xcode console for errors

## Handoff Notes

- Device model changed significantly - many components updated
- Properties like `issue`, `diagnosis`, `resolution` are removed
- If these features are needed, they may require backend changes
- SubLocation provides storage location info
