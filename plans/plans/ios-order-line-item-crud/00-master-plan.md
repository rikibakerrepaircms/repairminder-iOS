# iOS Order Line Item CRUD — Master Plan

## Feature Overview

Add full create, edit, and delete capabilities for order line items to the iOS app, matching the web dashboard's functionality. Currently the iOS `OrderDetailView` displays line items read-only. The API endpoints already exist and are already defined in `APIEndpoints.swift` — this is purely an iOS UI + ViewModel feature.

## Success Criteria

- Staff can add a new line item (repair, device sale, accessory, device purchase) with description, quantity, VAT-inclusive price, and optional device link
- Staff can edit any existing line item's description, quantity, price, VAT rate, and device link
- Staff can delete a line item with a confirmation prompt
- Totals section updates after every add/edit/delete (via order refresh)
- All add/edit/delete UI is hidden on collected/despatched orders
- Form sheet works correctly on both iPhone (full sheet) and iPad (popover within the AnimatedSplitView detail pane)
- iPad detail view respects existing `maxWidth: 700` constraint and 2-column responsive patterns
- Price input is VAT-inclusive (matching web UX), converted to net before sending to API

## Dependencies & Prerequisites

- All 4 API endpoints already exist (GET/POST/PATCH/DELETE on `/api/orders/:id/items[/:itemId]`)
- `APIEndpoints.swift` already has `createOrderItem`, `updateOrderItem`, `deleteOrderItem` cases
- `APIClient.request<T>()` and `requestVoid()` handle auth, encoding (`.convertToSnakeCase`), and decoding (`.convertFromSnakeCase`)
- `OrderItem` model already decodes all required fields
- `OrderCompany` already has `vatRateRepair`, `vatRateDeviceSale`, `vatRateAccessory`, `vatRateDevicePurchase`
- `FormTextField` reusable component exists at `Features/Staff/Booking/Components/FormTextField.swift`
- `SectionCard` component exists (defined in `OrderDetailView.swift`)
- `CurrencyFormatter` exists (defined in `Order.swift`)
- `AnimatedSplitView` handles iPad split layout in `OrderListView` — detail pane wraps `OrderDetailView` in its own `NavigationStack`

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Sheet popover sizing on iPad detail pane | Medium | Low | Use `.presentationDetents([.large])` to ensure form has enough space; test in split view |
| Floating-point rounding on price conversion | Low | Low | Send both `unit_price` (net) and `price_inc_vat` — server uses inc-VAT for final calc |
| `OrderDetailViewModel` migration breaks existing fetch | Low | Medium | `APIClient.request<T>()` uses identical `APIResponse<T>` envelope — straightforward swap |
| Sheet re-presentation with stale data when editing different items | Medium | Low | Use `editingItem` + `showItemFormSheet` as separate state; populate form in `.onAppear` |

## Stage Index

1. **[ViewModel CRUD + Request Model](01-viewmodel-crud-request-model.md)** — Add `OrderItemRequest` Encodable struct, migrate ViewModel fetch to `APIClient`, add create/update/delete async methods ✅
2. **[OrderItemFormSheet](02-order-item-form-sheet.md)** — New form view with item type picker, device selector, description, quantity, price (VAT-inc), VAT rate, live totals preview ✅
3. **[OrderDetailView Integration](03-order-detail-view-integration.md)** — Rewrite items section with add/edit/delete UI, wire sheet + delete alert, empty state, iPad responsive layout

## Out of Scope

- **Warranty item toggle** — Edge case (£0 repairs); `isWarrantyItem`/`warrantyNotes` fields included in request model for forward compatibility but no UI in v1
- **Product catalog search** — Web has "Quick Add from Catalog" to search products; iOS v1 uses manual description entry only
- **Inline add (no sheet)** — Web uses a modal; iOS uses a sheet. Not doing inline-in-list editing.
- **Undo delete** — Backend does hard delete with no undo; matches web behaviour
