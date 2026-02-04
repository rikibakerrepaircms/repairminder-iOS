# Stage 08: Staff Clients

## Objective

Fix client list and detail view models to work with updated Client model.

## Dependencies

- **Requires**: Stage 02 complete (Client model fixed)
- **Requires**: Stage 04 complete (API client working)

## Complexity

**Low** - Client model changes are straightforward

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Features/Clients/ClientListViewModel.swift` | Update for new model |
| `Repair Minder/Features/Clients/ClientDetailViewModel.swift` | Update for new model |
| `Repair Minder/Features/Clients/Components/ClientListRow.swift` | Update property access |
| `Repair Minder/Features/Clients/Components/ClientHeader.swift` | Update property access |
| `Repair Minder/Features/Clients/Components/ClientStatsCard.swift` | Fix totalSpend |
| `Repair Minder/Features/Clients/Components/ContactActionsView.swift` | Verify phone/email access |

## Backend Reference

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `GET /api/clients` | GET | List clients with pagination |
| `GET /api/clients/:id` | GET | Single client detail |
| `GET /api/clients/:id/orders` | GET | Client's orders |

## Implementation Details

### 1. Property Mapping Changes

| Old Property | New Property | Notes |
|--------------|--------------|-------|
| `client.totalSpent` | `client.totalSpend` | Renamed |
| `client.company` | Removed | Not in backend |
| `client.address` | Removed | Not in backend |
| `client.city` | Removed | Not in backend |
| `client.postcode` | Removed | Not in backend |
| `client.notes` | Removed | Not in backend |
| `client.updatedAt` | Removed | Not in backend |

### 2. New Properties Available

- `client.countryCode`
- `client.groups` (array of ClientGroup)
- `client.clientGroupName`
- `client.deviceCount`
- `client.ticketCount`
- `client.averageSpend`
- `client.lastContactReceived`
- `client.lastContactSent`
- `client.marketingConsent`

### 3. ClientListViewModel

```swift
@MainActor
@Observable
final class ClientListViewModel {
    private(set) var clients: [Client] = []
    private(set) var isLoading = false
    var error: String?
    var searchQuery: String = ""

    func loadClients() async {
        isLoading = true

        do {
            let response: PaginatedResponse<Client> = try await APIClient.shared.request(
                .clients(search: searchQuery.isEmpty ? nil : searchQuery),
                responseType: PaginatedResponse<Client>.self
            )
            clients = response.data
        } catch {
            self.error = "Failed to load clients"
        }

        isLoading = false
    }
}
```

### 4. ClientDetailViewModel

```swift
@MainActor
@Observable
final class ClientDetailViewModel {
    let clientId: String
    private(set) var client: Client?
    private(set) var orders: [Order] = []
    private(set) var isLoading = false
    var error: String?

    func loadClient() async {
        isLoading = true

        do {
            // Load client detail
            client = try await APIClient.shared.request(
                .client(id: clientId),
                responseType: Client.self
            )

            // Load client's orders
            let orderResponse: PaginatedResponse<Order> = try await APIClient.shared.request(
                .clientOrders(id: clientId),
                responseType: PaginatedResponse<Order>.self
            )
            orders = orderResponse.data
        } catch {
            self.error = "Failed to load client"
        }

        isLoading = false
    }
}
```

### 5. UI Component Updates

**ClientStatsCard.swift**:
```swift
// OLD
Text(formatCurrency(client.totalSpent))

// NEW
Text(formatCurrency(client.totalSpend))

// NEW - additional stats available
Text("\(client.deviceCount) devices")
Text("\(client.ticketCount) tickets")
if let avg = client.averageSpend {
    Text("Avg: \(formatCurrency(avg))")
}
```

**ClientHeader.swift**:
```swift
// Use computed fullName
Text(client.fullName)

// Use initials for avatar
Text(client.initials)

// Show group if available
if let groupName = client.clientGroupName {
    Badge(groupName)
}
```

**ClientListRow.swift**:
```swift
// OLD
Text(client.totalSpent.formatted())

// NEW
Text(client.totalSpend.formatted())
Text("\(client.orderCount) orders")
```

### 6. Remove References to Removed Properties

Search and remove/handle:
- `client.company`
- `client.address`
- `client.city`
- `client.postcode`
- `client.notes`
- `client.updatedAt`

If address display is needed, it would require backend changes.

## Database Changes

None

## Test Cases

| Test | Expected |
|------|----------|
| Client list loads | Clients shown with name, stats |
| Client search | Filtered results displayed |
| Client detail loads | Full client info displayed |
| Client orders load | Orders list shown |
| Total spend displays | Currency formatted correctly |
| Client groups shown | Group badges displayed |

## Acceptance Checklist

- [ ] Client list compiles and loads
- [ ] Client list rows show `totalSpend` not `totalSpent`
- [ ] Client detail compiles and loads
- [ ] ClientStatsCard uses `totalSpend`
- [ ] ClientHeader shows `fullName` and `initials`
- [ ] Client groups displayed if available
- [ ] No references to removed properties
- [ ] Client orders load correctly

## Deployment

1. Build and run app
2. Navigate to Clients tab
3. Verify list loads with client names
4. Search for a client
5. Tap a client to view detail
6. Verify orders section shows

## Handoff Notes

- `totalSpent` renamed to `totalSpend` - simple find/replace
- Address fields removed - if needed, backend must add
- New stats available (deviceCount, ticketCount, averageSpend)
