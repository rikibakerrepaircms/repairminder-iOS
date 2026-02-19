# Stage 3: OrderDetailView Integration

## Objective

Rewrite the `itemsSection()` in `OrderDetailView` to support add, edit, and delete actions — wiring the `OrderItemFormSheet` as a `.sheet()` and adding delete confirmation and error alerts.

## Dependencies

[Requires: Stage 1 complete] — needs ViewModel CRUD methods and `isOrderEditable`.
[Requires: Stage 2 complete] — needs `OrderItemFormSheet` view.

## Complexity

Medium

## Files to Modify

| File | Changes |
|------|---------|
| `Features/Staff/Orders/OrderDetailView.swift` | Add sheet/alert state, rewrite `itemsSection()`, add empty state, add `authorizationColor()` helper, add `.sheet()` + `.alert()` modifiers |

## Files to Create

None.

## Implementation Details

### 1. Add State Variables

Add to `OrderDetailView` alongside existing `@State` properties:

```swift
@State private var showItemFormSheet = false
@State private var editingItem: OrderItem?           // nil = add mode, non-nil = edit mode
@State private var itemToDelete: OrderItem?
@State private var showDeleteConfirmation = false
```

### 2. Update `orderContent(_:)` — Items Section Call

**Current** (line ~62):
```swift
if let items = order.items, !items.isEmpty {
    itemsSection(items)
}
```

**Replace with:**
```swift
// Items section — always show when order is editable (even when empty)
if let items = order.items, !items.isEmpty {
    itemsSection(items, order: order)
} else if viewModel.isOrderEditable {
    emptyItemsSection()
}
```

This ensures:
- Orders with items → full items section with add/edit/delete
- Editable orders with no items → empty state with "Add First Item" button
- Collected orders with no items → nothing shown (same as before)

### 3. Rewrite `itemsSection(_:order:)`

**Delete** the existing `itemsSection(_ items: [OrderItem])` method (lines 284-320).

**Replace with** new version that accepts `order` parameter and adds CRUD UI:

```swift
private func itemsSection(_ items: [OrderItem], order: Order) -> some View {
    SectionCard(title: "Items", icon: "list.bullet") {
        VStack(spacing: 0) {
            // "Add Item" button — top right, only when editable
            if viewModel.isOrderEditable {
                HStack {
                    Spacer()
                    Button {
                        editingItem = nil
                        showItemFormSheet = true
                    } label: {
                        Label("Add Item", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.bottom, 8)
            }

            // Item rows
            ForEach(items) { item in
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        // Left column: description + type badge + auth status
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.description)
                                .font(.subheadline)

                            HStack(spacing: 6) {
                                if let type = item.itemType {
                                    Label(type.label, systemImage: type.icon)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let status = item.authorizationStatus {
                                    Text(status.capitalized)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(authorizationColor(status).opacity(0.15))
                                        .foregroundStyle(authorizationColor(status))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        Spacer(minLength: 12)

                        // Right column: total + qty breakdown
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.formattedLineTotal)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("x\(item.quantity) @ \(item.formattedUnitPrice)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Context menu (edit/delete) — only when editable
                        if viewModel.isOrderEditable {
                            Menu {
                                Button {
                                    editingItem = item
                                    showItemFormSheet = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    itemToDelete = item
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, height: 32)
                            }
                        }
                    }
                    .padding(.vertical, 8)

                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}
```

### 4. Add Empty Items Section

```swift
private func emptyItemsSection() -> some View {
    SectionCard(title: "Items", icon: "list.bullet") {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No items added yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                editingItem = nil
                showItemFormSheet = true
            } label: {
                Label("Add First Item", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
```

### 5. Add Authorization Color Helper

```swift
private func authorizationColor(_ status: String) -> Color {
    switch status.lowercased() {
    case "approved": .green
    case "pending": .orange
    case "declined", "rejected": .red
    default: .secondary
    }
}
```

### 6. Add Sheet + Alert Modifiers

Add to the `orderContent` ScrollView's modifier chain, after the existing `.refreshable`:

```swift
.sheet(isPresented: $showItemFormSheet) {
    if let order = viewModel.order {
        OrderItemFormSheet(
            order: order,
            editingItem: editingItem
        ) { request in
            if let item = editingItem {
                return await viewModel.updateItem(itemId: item.id, request: request)
            } else {
                return await viewModel.createItem(request)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
.alert("Delete Item", isPresented: $showDeleteConfirmation) {
    Button("Cancel", role: .cancel) { }
    Button("Delete", role: .destructive) {
        if let item = itemToDelete {
            Task { _ = await viewModel.deleteItem(itemId: item.id) }
        }
    }
} message: {
    if let item = itemToDelete {
        Text("Are you sure you want to delete \"\(item.description)\"? This cannot be undone.")
    }
}
.alert("Error", isPresented: Binding(
    get: { viewModel.itemError != nil },
    set: { if !$0 { viewModel.clearItemError() } }
)) {
    Button("OK") { }
} message: {
    Text(viewModel.itemError ?? "")
}
```

### iPad Layout Behaviour

1. **Detail pane context**: On iPad, `OrderDetailView` renders inside `AnimatedSplitView`'s detail pane [Ref: Features/Staff/Orders/OrderListView.swift#iPadLayout, line 62-87]. The detail pane is wrapped in its own `NavigationStack` with `.id(order.id)`. The `.sheet()` modifier on the ScrollView presents correctly within this context.

2. **Max width 700**: The existing `ScrollView` already has `.frame(maxWidth: isRegularWidth ? 700 : .infinity)` [Ref: OrderDetailView.swift, line 97]. All SectionCards fill the available width within this constraint. The `...` menu button adds ~32pt per row — fits within the 700pt max minus padding (~668pt content).

3. **Detail pane widths**: `AnimatedSplitView` sidebar width is `min(380, totalWidth * 0.38)`. On standard iPad landscape (1024pt): sidebar=380, detail=~644. Portrait (768pt): sidebar=~292, detail=~476. The items section `HStack` rows work at all these widths.

4. **Sheet on iPad**: `.sheet()` on iPad presents as a centered card overlay. With `.presentationDetents([.large])` it takes most of the screen, not just the detail pane. The `OrderItemFormSheet` reads `@Environment(\.horizontalSizeClass)` independently — on iPad the sheet gets `.regular`, so quantity+price show side-by-side.

5. **Refresh after mutation**: `viewModel.refresh()` (called by create/update/delete) updates `@Published order`, which re-renders the detail pane. The `.id(order.id)` in `OrderListView` keeps the same detail view, so the refresh is smooth (no re-create).

6. **Selected row highlight**: `OrderListView`'s iPad list highlights the selected row with `.listRowBackground(accentColor.opacity(0.1))`. This persists during add/edit/delete since `selectedOrder` doesn't change.

## Database Changes

None.

## Test Cases

| Scenario | Action | Expected |
|----------|--------|----------|
| **Add item** | Tap "Add Item" → fill form → tap "Add" | Sheet opens blank → dismisses on success → item appears in list → totals update |
| **Edit item** | Tap `...` → Edit → change price → tap "Update" | Sheet opens pre-filled → dismisses → item updated → totals recalculate |
| **Delete item** | Tap `...` → Delete → tap "Delete" on alert | Alert with description → item removed → totals update |
| **Cancel delete** | Tap `...` → Delete → tap "Cancel" | Alert dismissed, nothing changes |
| **Collected order** | Open collected/despatched order | No "Add Item" button, no `...` menus on any row |
| **Empty + editable** | Open pending order with no items | Empty state card with icon + "Add First Item" button |
| **Empty + collected** | Open collected order with no items | Items section not shown at all |
| **API error on add** | Submit form, API returns 400 | Error alert from `viewModel.itemError`, sheet stays open via `onSave` returning false |
| **API error on delete** | Delete fails | Error alert shown |
| **iPad: split view add** | iPad landscape, order selected in list, tap Add Item | Sheet presents as card overlay, form works, detail pane refreshes |
| **iPad: split view edit** | iPad portrait, tap `...` → Edit | Sheet presents, form pre-filled, save refreshes detail pane |
| **iPad: totals after delete** | Delete an item on iPad | Totals section in detail pane updates immediately |
| **Auth badge** | Item has `authorization_status: "approved"` | Green "Approved" capsule badge shown next to type |
| **Auth badge pending** | Item has `authorization_status: "pending"` | Orange "Pending" capsule badge |

## Acceptance Checklist

- [ ] 4 new `@State` variables added (showItemFormSheet, editingItem, itemToDelete, showDeleteConfirmation)
- [ ] "Add Item" button at top of items section, right-aligned, `.borderedProminent .small`
- [ ] "Add Item" hidden when `!viewModel.isOrderEditable`
- [ ] Each item row: description + type label/icon + auth badge | total + qty×price | `...` menu
- [ ] `...` menu has "Edit" and "Delete" (destructive) buttons
- [ ] `...` menu hidden when `!viewModel.isOrderEditable`
- [ ] Edit: sets `editingItem` then `showItemFormSheet = true`
- [ ] Delete: sets `itemToDelete` then `showDeleteConfirmation = true`
- [ ] `.sheet()` presents `OrderItemFormSheet` with correct `editingItem` and `onSave` closure
- [ ] `onSave` calls `viewModel.createItem()` (add) or `viewModel.updateItem()` (edit)
- [ ] `.presentationDetents([.large])` + `.presentationDragIndicator(.visible)` on sheet
- [ ] Delete alert shows item description, has Cancel + destructive Delete buttons
- [ ] Error alert bound to `viewModel.itemError` via computed `Binding`
- [ ] Empty items section shown when no items + editable order
- [ ] Empty items section NOT shown for collected orders
- [ ] `authorizationColor()` helper returns correct colours
- [ ] iPad: items section works within 700pt max width constraint
- [ ] iPad: sheet presents as overlay, not constrained to detail pane
- [ ] iPad: detail pane refreshes smoothly after mutations
- [ ] iPhone: items section fills full width
- [ ] App builds without warnings

## Deployment

No deployment — iOS code only. Test on:
- iPhone 15 simulator (compact width)
- iPad Pro 12.9" simulator (regular width, test both portrait + landscape)
- Test with an order that has items + devices
- Test with an empty order
- Test with a collected/despatched order

## Handoff Notes

Feature complete after this stage. Potential future enhancements:
- Warranty item toggle (UI for `isWarrantyItem` / `warrantyNotes` fields already in `OrderItemRequest`)
- Product catalog quick-add search (search products → auto-fill description + price)
- Swipe-to-delete as alternative to `...` context menu
- Inline "quick add" row without opening sheet
