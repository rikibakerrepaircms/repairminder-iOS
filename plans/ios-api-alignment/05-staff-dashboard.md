# Stage 05: Staff Dashboard & My Queue

## Objective

Fix dashboard view model to use correct endpoints and updated DashboardStats model.

## Dependencies

- **Requires**: Stage 03 complete (DashboardStats model verified)
- **Requires**: Stage 04 complete (API client working)

## Complexity

**Low** - Mostly wiring up existing endpoints with fixed models

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Features/Dashboard/DashboardViewModel.swift` | Use updated model, fix API calls |
| `Repair Minder/Features/Dashboard/DashboardView.swift` | Update bindings if model properties changed |
| `Repair Minder/Features/Dashboard/Components/MyQueueSection.swift` | Verify device display works |
| `Repair Minder/Features/Dashboard/Components/StatCard.swift` | Update for new stats structure |

## Files to Create

None

## Backend Reference

### Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /api/dashboard/stats` | Main dashboard statistics |
| `GET /api/dashboard/enquiry-stats` | Enquiry/ticket statistics |
| `GET /api/devices/my-queue` | User's assigned devices |

### Query Parameters

- `scope`: "user" or "location" or "company"
- `period`: "today", "this_week", "this_month", "this_year"

## Implementation Details

### 1. Update DashboardViewModel

```swift
@MainActor
@Observable
final class DashboardViewModel {
    private(set) var stats: DashboardStats?
    private(set) var myQueue: [Device] = []
    private(set) var isLoading = false
    var error: String?

    func loadDashboard() async {
        isLoading = true
        error = nil

        do {
            // Load stats - verify endpoint matches
            stats = try await APIClient.shared.request(
                .dashboardStats(scope: "user", period: "this_month"),
                responseType: DashboardStats.self
            )

            // Load my queue - uses updated Device model from Stage 01
            let queueResponse: PaginatedResponse<Device> = try await APIClient.shared.request(
                .myQueue(),
                responseType: PaginatedResponse<Device>.self
            )
            myQueue = queueResponse.data
        } catch {
            self.error = "Failed to load dashboard"
        }

        isLoading = false
    }
}
```

### 2. Verify Endpoint Definitions

In `APIEndpoints.swift`:

```swift
static func dashboardStats(scope: String = "user", period: String = "this_month") -> APIEndpoint {
    APIEndpoint(
        path: "/api/dashboard/stats",
        queryParameters: ["scope": scope, "period": period]
    )
}

static func myQueue(page: Int = 1, limit: Int = 20) -> APIEndpoint {
    APIEndpoint(
        path: "/api/devices/my-queue",
        queryParameters: ["page": String(page), "limit": String(limit)]
    )
}
```

### 3. Update View Bindings

If DashboardStats properties changed in Stage 03, update view to use new property names:

```swift
// Example: if changed from stats.devicesCount to stats.devicesRepaired
StatCard(
    title: "Devices Repaired",
    value: "\(stats.devicesRepaired ?? 0)",
    // ...
)
```

### 4. My Queue Device Display

My Queue uses Device model - should work after Stage 01 fix. Verify:

```swift
ForEach(viewModel.myQueue) { device in
    DeviceQueueRow(device: device)
}
```

`DeviceQueueRow` should use:
- `device.displayName` (not old `device.brand + device.model`)
- `device.status`
- `device.orderNumber`

## Database Changes

None

## Test Cases

| Test | Expected |
|------|----------|
| Dashboard loads | Stats displayed, no decode errors |
| My Queue loads | List of assigned devices shown |
| Empty queue | "No devices in queue" message |
| Period selector | Stats update when period changes |
| Pull to refresh | Data reloads |

## Acceptance Checklist

- [ ] Dashboard stats load without decode errors
- [ ] Stats display correct values
- [ ] My Queue loads device list
- [ ] Device rows display `displayName` correctly
- [ ] No references to removed model properties
- [ ] Period selector works (if implemented)

## Deployment

1. Build and run app
2. Login and navigate to Dashboard
3. Verify stats cards show data
4. Verify My Queue section shows devices
5. Check Xcode console for any errors

## Handoff Notes

- If stats response structure differs from expected, document for model update
- My Queue depends on Device model from Stage 01
- Note any UI components that need property name updates
