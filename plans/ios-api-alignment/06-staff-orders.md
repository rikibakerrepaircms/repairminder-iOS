# Stage 06: Staff Orders

## Objective

Fix order list and detail view models to work with updated Order model and correct endpoints.

## Dependencies

- **Requires**: Stage 03 complete (Order model verified)
- **Requires**: Stage 04 complete (API client working)

## Complexity

**Medium** - Need to update view models and UI components

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Features/Orders/OrderListViewModel.swift` | Verify API calls, update model usage |
| `Repair Minder/Features/Orders/OrderDetailViewModel.swift` | Verify detail endpoint |
| `Repair Minder/Features/Orders/Components/OrderListRow.swift` | Update for Order model changes |
| `Repair Minder/Features/Orders/Components/OrderHeader.swift` | Update property access |
| `Repair Minder/Features/Orders/Components/DevicesSection.swift` | Uses Device model from Stage 01 |
| `Repair Minder/Features/Orders/Components/DeviceListItem.swift` | Update device property access |

## Backend Reference

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `GET /api/orders` | GET | List orders with pagination |
| `GET /api/orders/:id` | GET | Single order detail |
| `POST /api/orders` | POST | Create order |
| `PATCH /api/orders/:id` | PATCH | Update order |

### Query Parameters for List

- `page`: Page number (default 1)
- `limit`: Items per page (default 20)
- `status`: Filter by status
- `search`: Search term

## Implementation Details

### 1. OrderListViewModel

```swift
@MainActor
@Observable
final class OrderListViewModel {
    private(set) var orders: [Order] = []
    private(set) var isLoading = false
    private(set) var hasMore = true
    private var currentPage = 1
    var error: String?
    var statusFilter: OrderStatus?
    var searchQuery: String = ""

    func loadOrders(reset: Bool = false) async {
        if reset {
            currentPage = 1
            orders = []
            hasMore = true
        }

        guard hasMore, !isLoading else { return }
        isLoading = true

        do {
            let response: PaginatedResponse<Order> = try await APIClient.shared.request(
                .orders(
                    page: currentPage,
                    limit: 20,
                    status: statusFilter?.rawValue,
                    search: searchQuery.isEmpty ? nil : searchQuery
                ),
                responseType: PaginatedResponse<Order>.self
            )

            orders.append(contentsOf: response.data)
            hasMore = response.data.count == 20
            currentPage += 1
        } catch {
            self.error = "Failed to load orders"
        }

        isLoading = false
    }
}
```

### 2. OrderDetailViewModel

```swift
@MainActor
@Observable
final class OrderDetailViewModel {
    let orderId: String
    private(set) var order: Order?
    private(set) var devices: [Device] = []
    private(set) var isLoading = false
    var error: String?

    func loadOrder() async {
        isLoading = true

        do {
            // Get order detail
            order = try await APIClient.shared.request(
                .order(id: orderId),
                responseType: Order.self
            )

            // Get devices for this order
            let deviceResponse: PaginatedResponse<Device> = try await APIClient.shared.request(
                .devices(orderId: orderId),
                responseType: PaginatedResponse<Device>.self
            )
            devices = deviceResponse.data
        } catch {
            self.error = "Failed to load order"
        }

        isLoading = false
    }
}
```

### 3. Update UI Components

**OrderListRow.swift**:
```swift
// Use Order model properties
Text(order.displayRef)  // "#12345"
Text(order.clientName ?? "Unknown")  // Computed property
Text(order.status.displayName)
```

**OrderHeader.swift**:
```swift
// Access nested client object
if let client = order.client {
    Text(client.email)
    if let phone = client.phone {
        Text(phone)
    }
}

// Access nested location
if let location = order.location {
    Text(location.name)
}
```

**DevicesSection.swift** and **DeviceListItem.swift**:
```swift
// Uses Device model - updated in Stage 01
Text(device.displayName)  // Not device.brand + device.model
Text(device.status.displayName)
```

### 4. Verify Endpoint Definition

```swift
static func orders(
    page: Int = 1,
    limit: Int = 20,
    status: String? = nil,
    search: String? = nil
) -> APIEndpoint {
    var params: [String: String] = [
        "page": String(page),
        "limit": String(limit)
    ]
    if let status = status { params["status"] = status }
    if let search = search { params["search"] = search }

    return APIEndpoint(path: "/api/orders", queryParameters: params)
}

static func order(id: String) -> APIEndpoint {
    APIEndpoint(path: "/api/orders/\(id)")
}
```

## Database Changes

None

## Test Cases

| Test | Expected |
|------|----------|
| Order list loads | Orders displayed with client name, status |
| Order list pagination | Load more when scrolling |
| Order status filter | Only filtered orders shown |
| Order search | Search results displayed |
| Order detail loads | Full order with devices shown |
| Device list in order | Devices displayed with displayName |

## Acceptance Checklist

- [ ] Order list loads without decode errors
- [ ] Order list rows display correctly (client name, status, ref)
- [ ] Order detail loads
- [ ] Order detail shows client info from nested object
- [ ] Order detail shows devices
- [ ] Device items use `displayName` not old properties
- [ ] Status filter works
- [ ] Search works
- [ ] Pagination works

## Deployment

1. Build and run app
2. Navigate to Orders tab
3. Verify list loads
4. Tap an order to view detail
5. Check Xcode console for errors

## Handoff Notes

- Order model uses nested objects (`client`, `location`, `assignedUser`)
- Views must access properties via nested objects
- DevicesSection depends on Stage 01 Device model
