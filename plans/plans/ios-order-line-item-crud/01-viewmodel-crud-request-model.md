# Stage 1: ViewModel CRUD + Request Model

## Objective

Add the `OrderItemRequest` Encodable struct to `Order.swift` and extend `OrderDetailViewModel` with create, update, and delete methods using `APIClient`, migrating the existing `fetchOrder()` away from raw `URLRequest`.

## Dependencies

None — this is the foundation stage.

## Complexity

Low-Medium

## Files to Modify

| File | Changes |
|------|---------|
| `Core/Models/Order.swift` | Add `OrderItemRequest` Encodable struct |
| `Features/Staff/Orders/OrderDetailViewModel.swift` | Migrate fetch to `APIClient.request<T>()`, add CRUD methods, add item operation state, add `isOrderEditable` computed property |

## Files to Create

None.

## Implementation Details

### 1. `OrderItemRequest` in `Order.swift`

Add after the `OrderNote` struct (before `CurrencyFormatter`):

```swift
// MARK: - Order Item Request

/// Encodable request body for creating or updating an order line item.
/// Property names are camelCase; APIClient's encoder converts to snake_case.
struct OrderItemRequest: Encodable {
    var itemType: String        // "repair", "device_sale", "accessory", "device_purchase"
    var description: String
    var quantity: Int
    var unitPrice: Double       // Net (ex VAT) — calculated from VAT-inclusive input
    var priceIncVat: Double?    // VAT-inclusive — sent for accurate server-side VAT calc
    var vatRate: Double?        // Omit to use company default
    var deviceId: String?
    var isWarrantyItem: Bool?
    var warrantyNotes: String?
    var productTypeId: String?
}
```

### 2. `OrderDetailViewModel.swift` — Full Rewrite

**Remove:**
- Private `OrderDetailAPIResponse` struct (no longer needed — `APIClient.request<T>()` unwraps `APIResponse<T>` automatically)
- Private `fetchOrder()` method with raw `URLRequest` and manual JSON decoding
- `#if DEBUG` decoding error logging (APIClient already logs decode errors)

**Add published state** (use `private(set)` to match existing properties — these are only mutated by the ViewModel's own methods):
```swift
@Published private(set) var isSavingItem = false
@Published private(set) var isDeletingItem = false
@Published private(set) var itemError: String?
```

**Migrate `loadOrder()` and `refresh()`:**

Replace `let order = try await fetchOrder()` with:
```swift
let fetchedOrder: Order = try await apiClient.request(.order(id: orderId))
```

This works because the order detail endpoint returns `{ success: true, data: { ...order } }` which is the standard `APIResponse<Order>` envelope that `APIClient.request<T>()` expects.

**Add computed property:**
```swift
var isOrderEditable: Bool {
    guard let order else { return false }
    return order.status != .collectedDespatched
}
```

**Add CRUD methods:**

```swift
/// Add a new line item. Returns true on success.
func createItem(_ request: OrderItemRequest) async -> Bool {
    isSavingItem = true
    itemError = nil
    defer { isSavingItem = false }
    do {
        let _: OrderItem = try await apiClient.request(
            .createOrderItem(orderId: orderId),
            body: request
        )
        await refresh()
        return true
    } catch let apiError as APIError {
        itemError = apiError.localizedDescription
        return false
    } catch {
        itemError = error.localizedDescription
        return false
    }
}

/// Update an existing line item. Returns true on success.
func updateItem(itemId: String, request: OrderItemRequest) async -> Bool {
    isSavingItem = true
    itemError = nil
    defer { isSavingItem = false }
    do {
        let _: OrderItem = try await apiClient.request(
            .updateOrderItem(orderId: orderId, itemId: itemId),
            body: request
        )
        await refresh()
        return true
    } catch let apiError as APIError {
        itemError = apiError.localizedDescription
        return false
    } catch {
        itemError = error.localizedDescription
        return false
    }
}

/// Delete a line item. Returns true on success.
func deleteItem(itemId: String) async -> Bool {
    isDeletingItem = true
    itemError = nil
    defer { isDeletingItem = false }
    do {
        try await apiClient.requestVoid(
            .deleteOrderItem(orderId: orderId, itemId: itemId)
        )
        await refresh()
        return true
    } catch let apiError as APIError {
        itemError = apiError.localizedDescription
        return false
    } catch {
        itemError = error.localizedDescription
        return false
    }
}

/// Clear item error (called from view alert dismiss)
func clearItemError() {
    itemError = nil
}
```

**Why `APIError` catch:** `APIClient` throws typed `APIError` with user-friendly `.localizedDescription`. The fallback catch handles unexpected errors.

**Why `refresh()` after each mutation:** The backend recalculates order totals and payment status after every line item change. Refreshing the full order ensures the totals section, payment status badge, and balance due all update correctly.

## Database Changes

None — API already exists.

## Test Cases

| Scenario | Input | Expected Output |
|----------|-------|-----------------|
| Load order detail | Valid order ID | `apiClient.request(.order(id:))` returns `Order`, stored in `self.order` |
| Load order — 401 | Expired token | `APIClient` auto-refreshes token and retries (built-in behaviour) |
| Create item — success | Valid `OrderItemRequest` | Returns `true`, `order` refreshed with new item, `isSavingItem` back to `false` |
| Create item — 400 validation | Empty description | Returns `false`, `itemError` set to "Description is required" |
| Create item — 400 collected | Order is collected | Returns `false`, `itemError` set to "Cannot add items to a collected order" |
| Update item — success | Valid partial update | Returns `true`, order refreshed, totals recalculated |
| Delete item — success | Valid item ID | Returns `true`, item removed from `order.items`, totals updated |
| Delete item — 404 | Invalid item ID | Returns `false`, `itemError` set to "Item not found" |
| `isOrderEditable` — pending | `order.status == .pending` | `true` |
| `isOrderEditable` — collected | `order.status == .collectedDespatched` | `false` |

## Acceptance Checklist

- [ ] `OrderItemRequest` struct added to `Order.swift` with all 10 fields
- [ ] `OrderDetailViewModel` uses `apiClient.request(.order(id:))` instead of raw `URLRequest`
- [ ] Private `OrderDetailAPIResponse` struct removed
- [ ] `#if DEBUG` manual decoding error logging removed
- [ ] `createItem()` calls `.createOrderItem(orderId:)`, refreshes order, returns Bool
- [ ] `updateItem()` calls `.updateOrderItem(orderId:, itemId:)`, refreshes order, returns Bool
- [ ] `deleteItem()` calls `requestVoid(.deleteOrderItem(...))`, refreshes order, returns Bool
- [ ] `isOrderEditable` returns `false` only for `.collectedDespatched`
- [ ] `itemError` set on failure, cleared by `clearItemError()`
- [ ] `isSavingItem` / `isDeletingItem` toggled correctly with `defer`
- [ ] Existing order detail loading still works after migration (test on real order)
- [ ] App builds without warnings

## Deployment

No deployment — iOS code only. Build and run on simulator, open an order detail to verify the fetch migration works.

## Handoff Notes

[See: Stage 2] needs:
- `OrderItemRequest` struct (to build from form data)
- Understanding that the `onSave` closure injected into the form sheet will call `viewModel.createItem()` or `viewModel.updateItem()` depending on add/edit mode
