# Stage 09: Delete Operations

## Objective
Enable staff to delete images, parts, accessories, and line items from device records.

## Dependencies
`[Requires: Stages 01, 03, 06, 07, 08 complete]` - Needs all add functionality working first

## Complexity
**Low** - Swipe actions and confirmation dialogs with API calls

---

## Files to Modify

### 1. `Features/Staff/Devices/DeviceDetailView.swift`
Add swipe-to-delete actions for parts, accessories, and line items.

### 2. `Features/Staff/Devices/Gallery/DeviceImageGalleryView.swift`
Add delete option for images.

### 3. `Features/Staff/Devices/Gallery/FullScreenImageViewer.swift`
Add delete button to toolbar.

### 4. `Features/Staff/Devices/DeviceDetailViewModel.swift`
Add delete methods.

---

## Implementation Details

### Update DeviceDetailViewModel.swift

```swift
// MARK: - Delete Operations

/// Delete a part
func deletePart(_ partId: String) async {
    isUpdating = true
    error = nil

    do {
        try await APIClient.shared.requestVoid(
            .deleteDevicePart(orderId: orderId, deviceId: deviceId, partId: partId)
        )
        await refresh()
        successMessage = "Part deleted"
    } catch {
        self.error = error.localizedDescription
    }

    isUpdating = false
}

/// Delete an accessory
func deleteAccessory(_ accessoryId: String) async {
    isUpdating = true
    error = nil

    do {
        try await APIClient.shared.requestVoid(
            .deleteDeviceAccessory(orderId: orderId, deviceId: deviceId, accessoryId: accessoryId)
        )
        await refresh()
        successMessage = "Accessory deleted"
    } catch {
        self.error = error.localizedDescription
    }

    isUpdating = false
}

/// Delete a line item
func deleteLineItem(_ itemId: String) async {
    isUpdating = true
    error = nil

    do {
        try await APIClient.shared.requestVoid(
            .deleteOrderItem(orderId: orderId, itemId: itemId)
        )
        await refresh()
        successMessage = "Quote item deleted"
    } catch {
        self.error = error.localizedDescription
    }

    isUpdating = false
}

/// Delete an image
func deleteImage(_ imageId: String) async {
    isUpdating = true
    error = nil

    do {
        try await ImageService.shared.deleteImage(
            orderId: orderId,
            deviceId: deviceId,
            imageId: imageId
        )
        await refresh()
        successMessage = "Photo deleted"
    } catch {
        self.error = error.localizedDescription
    }

    isUpdating = false
}
```

### Update DeviceDetailView.swift - Parts Section

```swift
// Add state for delete confirmation
@State private var partToDelete: DevicePart?
@State private var showingDeletePartConfirmation = false

// Update partsSection - add swipe action
ForEach(device.partsUsed) { part in
    // ... existing part row content ...
}
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
    Button(role: .destructive) {
        partToDelete = part
        showingDeletePartConfirmation = true
    } label: {
        Label("Delete", systemImage: "trash")
    }
}

// Add confirmation dialog
.confirmationDialog(
    "Delete Part",
    isPresented: $showingDeletePartConfirmation,
    titleVisibility: .visible
) {
    Button("Delete", role: .destructive) {
        if let part = partToDelete {
            Task {
                await viewModel.deletePart(part.id)
            }
        }
    }
    Button("Cancel", role: .cancel) {
        partToDelete = nil
    }
} message: {
    if let part = partToDelete {
        Text("Are you sure you want to delete \"\(part.partName)\"? This cannot be undone.")
    }
}
```

### Update DeviceDetailView.swift - Accessories Section

```swift
// Add state for delete confirmation
@State private var accessoryToDelete: DeviceAccessory?
@State private var showingDeleteAccessoryConfirmation = false

// Update accessoriesSection - add delete swipe action
ForEach(device.accessories) { accessory in
    accessoryRow(accessory)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Delete action
            Button(role: .destructive) {
                accessoryToDelete = accessory
                showingDeleteAccessoryConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }

            // Return action (only if not returned)
            if !accessory.isReturned {
                Button {
                    Task {
                        await viewModel.returnAccessory(accessory.id)
                    }
                } label: {
                    Label("Returned", systemImage: "checkmark.circle")
                }
                .tint(.green)
            }
        }
}

// Add confirmation dialog
.confirmationDialog(
    "Delete Accessory",
    isPresented: $showingDeleteAccessoryConfirmation,
    titleVisibility: .visible
) {
    Button("Delete", role: .destructive) {
        if let accessory = accessoryToDelete {
            Task {
                await viewModel.deleteAccessory(accessory.id)
            }
        }
    }
    Button("Cancel", role: .cancel) {
        accessoryToDelete = nil
    }
} message: {
    if let accessory = accessoryToDelete {
        Text("Are you sure you want to delete the \(accessory.typeDisplayName.lowercased())? This cannot be undone.")
    }
}
```

### Update DeviceDetailView.swift - Line Items Section

```swift
// Add state for delete confirmation
@State private var lineItemToDelete: DeviceLineItem?
@State private var showingDeleteLineItemConfirmation = false

// Update lineItemsSection - add swipe action
ForEach(device.lineItems) { item in
    // ... existing line item row ...
}
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
    Button(role: .destructive) {
        lineItemToDelete = item
        showingDeleteLineItemConfirmation = true
    } label: {
        Label("Delete", systemImage: "trash")
    }
}

// Add confirmation dialog
.confirmationDialog(
    "Delete Quote Item",
    isPresented: $showingDeleteLineItemConfirmation,
    titleVisibility: .visible
) {
    Button("Delete", role: .destructive) {
        if let item = lineItemToDelete {
            Task {
                await viewModel.deleteLineItem(item.id)
            }
        }
    }
    Button("Cancel", role: .cancel) {
        lineItemToDelete = nil
    }
} message: {
    if let item = lineItemToDelete {
        Text("Are you sure you want to delete \"\(item.description)\"? This cannot be undone.")
    }
}
```

### Update FullScreenImageViewer.swift

```swift
// Add state
@State private var showingDeleteConfirmation = false
@State private var isDeleting = false

// Add to toolbar
ToolbarItem(placement: .topBarTrailing) {
    Menu {
        if let caption = currentImage.caption {
            Section {
                Text(caption)
            }
        }

        Button {
            // Share action (future)
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Divider()

        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label("Delete Photo", systemImage: "trash")
        }
    } label: {
        if isDeleting {
            ProgressView()
        } else {
            Image(systemName: "ellipsis.circle")
        }
    }
    .disabled(isDeleting)
}

// Add confirmation dialog
.confirmationDialog(
    "Delete Photo",
    isPresented: $showingDeleteConfirmation,
    titleVisibility: .visible
) {
    Button("Delete", role: .destructive) {
        Task {
            await deleteCurrentImage()
        }
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("Are you sure you want to delete this photo? This cannot be undone.")
}

// Add delete function
private func deleteCurrentImage() async {
    isDeleting = true

    do {
        try await ImageService.shared.deleteImage(
            orderId: orderId,
            deviceId: deviceId,
            imageId: currentImage.id
        )

        // Remove from local array
        await MainActor.run {
            if images.count > 1 {
                // Move to next or previous
                let newIndex = currentIndex >= images.count - 1 ? currentIndex - 1 : currentIndex
                images.remove(at: currentIndex)
                currentIndex = max(0, newIndex)
            } else {
                // Last image, dismiss viewer
                dismiss()
            }
        }
    } catch {
        // Show error (could add alert)
        print("Delete failed: \(error)")
    }

    isDeleting = false
}
```

### Update DeviceImageGalleryView.swift

Add context menu for quick delete from grid:

```swift
// Update ImageThumbnail or grid
ForEach(filteredImages) { image in
    ImageThumbnail(
        image: image,
        orderId: orderId,
        deviceId: deviceId
    )
    .onTapGesture {
        selectedImage = image
    }
    .contextMenu {
        Button(role: .destructive) {
            imageToDelete = image
            showingDeleteImageConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// Add state and confirmation
@State private var imageToDelete: DeviceImageInfo?
@State private var showingDeleteImageConfirmation = false

.confirmationDialog(
    "Delete Photo",
    isPresented: $showingDeleteImageConfirmation,
    titleVisibility: .visible
) {
    Button("Delete", role: .destructive) {
        if let image = imageToDelete {
            Task {
                await deleteImage(image)
            }
        }
    }
    Button("Cancel", role: .cancel) {
        imageToDelete = nil
    }
} message: {
    Text("Are you sure you want to delete this photo? This cannot be undone.")
}

private func deleteImage(_ image: DeviceImageInfo) async {
    do {
        try await ImageService.shared.deleteImage(
            orderId: orderId,
            deviceId: deviceId,
            imageId: image.id
        )
        // Remove from local array
        images.removeAll { $0.id == image.id }
        // Update counts
        await loadImages()
    } catch {
        error = error.localizedDescription
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
| Swipe delete part | Swipe left on part | Delete button appears |
| Confirm delete part | Tap Delete in dialog | Part removed from list |
| Cancel delete part | Tap Cancel | Part remains |
| Swipe delete accessory | Swipe left | Delete and Return buttons |
| Delete image from viewer | Tap menu → Delete | Image removed, viewer updates |
| Delete last image | Delete only image | Viewer dismisses |
| Delete from gallery | Long press → Delete | Image removed from grid |
| Delete line item | Swipe left | Total recalculates |

---

## Acceptance Checklist

- [ ] Parts have swipe-to-delete action
- [ ] Parts show confirmation before delete
- [ ] Accessories have swipe-to-delete action
- [ ] Accessories confirmation works
- [ ] Line items have swipe-to-delete action
- [ ] Line items total updates after delete
- [ ] Images deletable from full-screen viewer
- [ ] Images deletable via context menu in gallery
- [ ] Delete last image dismisses viewer
- [ ] All deletes refresh the device data
- [ ] Error handling works for all delete operations
- [ ] Build passes with no errors

---

## Deployment
```bash
xcodebuild -scheme "Repair Minder" -destination "generic/platform=iOS Simulator" build
```

---

## Handoff Notes
- All delete operations require confirmation to prevent accidental data loss
- Swipe actions use `allowsFullSwipe: false` to prevent accidental full-swipe deletes
- The gallery context menu provides quick access to delete without opening full-screen
- Delete operations call `refresh()` to ensure UI is in sync with server
- This completes the Device Page Enhancement feature set
