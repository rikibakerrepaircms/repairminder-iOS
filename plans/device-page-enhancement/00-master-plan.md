# Device Page Enhancement - Master Plan

## Feature Overview

Bring the iOS staff app's Device Detail screen to full feature parity with the web application at `app.mendmyi.com`. This includes photo capture/viewing, inline field editing, and the ability to add parts, accessories, line items, and notes.

### Current State
The iOS app can:
- View device details (status, info, identifiers, issues, diagnosis, repair notes, timeline)
- Execute status actions (start/complete diagnosis, start/complete repair)
- Update some fields via ViewModel (assign engineer, priority, sub-location, notes)

### Target State
The iOS app will additionally:
- View photos in a gallery with full-screen viewer
- Capture and upload photos using the device camera
- Edit fields inline (diagnosis notes, repair notes, technician issues, etc.)
- Add parts used during repair
- Add/manage accessories
- Add quote line items
- Add device notes

---

## Success Criteria

| Criteria | Measurement |
|----------|-------------|
| Photo gallery displays all device images | Can view pre-repair, post-repair, diagnostic, damage photos |
| Camera captures and uploads photos | Staff can take photo and see it appear in gallery within 5 seconds |
| Inline editing works | Tap field → edit → save → see updated value |
| Add parts works | Add part → appears in parts list immediately |
| Add accessories works | Add accessory → appears in list, can mark returned |
| Add line items works | Add quote item → appears with correct VAT calculation |
| Build passes with no warnings related to new code | Xcode build succeeds |
| All features work offline-first where possible | Graceful degradation on network issues |

---

## Dependencies & Prerequisites

| Dependency | Status | Notes |
|------------|--------|-------|
| Backend API endpoints | ✅ Ready | All endpoints exist (images, parts, accessories, items) |
| R2 image storage | ✅ Ready | Server handles upload/download with JWT auth |
| Device camera permission | ⚠️ Need Info.plist | Add camera usage description |
| Photo library permission | ⚠️ Need Info.plist | Add photo library usage description |
| Existing DeviceDetailView | ✅ Ready | Foundation to build upon |
| Existing DeviceDetailViewModel | ✅ Ready | Has update methods to extend |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Large image uploads fail on slow networks | Medium | High | Compress images, show progress, allow retry |
| Camera permission denied | Low | Medium | Show clear permission prompt with explanation |
| Concurrent edits conflict | Low | Medium | Refresh after save, show error if conflict |
| Memory pressure from many images | Medium | Medium | Use thumbnail loading, lazy image loading |
| API response format changes | Low | High | Defensive decoding, good error messages |

---

## Stage Index

| Stage | Name | Complexity | Description |
|-------|------|------------|-------------|
| 01 | [API Layer Extension](01-api-layer-extension.md) | Medium | Add missing endpoints and multipart upload support |
| 02 | [Image Service](02-image-service.md) | Medium | Create image loading, caching, and upload service |
| 03 | [Photo Gallery](03-photo-gallery.md) | Medium | View photos in grid with full-screen viewer |
| 04 | [Camera Integration](04-camera-integration.md) | Medium | Capture photos with ImagePicker and upload |
| 05 | [Inline Field Editing](05-inline-field-editing.md) | Low | Tap-to-edit for text fields (notes, issues) |
| 06 | [Add Parts](06-add-parts.md) | Low | UI to add parts used during repair |
| 07 | [Add Accessories](07-add-accessories.md) | Low | UI to add accessories and mark returned |
| 08 | [Add Line Items](08-add-line-items.md) | Medium | UI to add quote items with VAT calculation |
| 09 | [Delete Operations](09-delete-operations.md) | Low | Delete parts, accessories, images, line items |

---

## Out of Scope

This plan does **NOT** cover:
- Barcode/QR scanner integration (separate feature)
- Signature capture (already exists, separate enhancement if needed)
- Print/share functionality
- Bulk operations (batch photo upload, etc.)
- Image editing/annotation
- Order creation wizard (separate feature)
- Client management screens
- Push notification enhancements
- Offline-first architecture (basic caching only)

---

## Architecture Decisions

### Image Upload Strategy
- **Chosen**: Direct multipart upload to API (no presigned URLs)
- **Reason**: Backend already implements this; simpler client code

### Image Caching
- **Chosen**: URLCache + in-memory thumbnail cache
- **Reason**: Leverage system caching, minimal custom code

### State Management
- **Chosen**: Extend existing @Observable DeviceDetailViewModel
- **Reason**: Consistent with existing patterns, minimal refactoring

### UI Pattern for Editing
- **Chosen**: Sheet-based editors for complex fields, inline for simple
- **Reason**: Matches iOS conventions, good keyboard handling

---

## File Structure Overview

```
Features/Staff/Devices/
├── DeviceDetailView.swift          # Existing - extend
├── DeviceDetailViewModel.swift     # Existing - extend
├── Components/
│   ├── DeviceStatusBadge.swift     # Existing
│   ├── PriorityBadge.swift         # Existing
│   ├── WorkflowTypeBadge.swift     # Existing
│   └── ...
├── Gallery/
│   ├── DeviceImageGalleryView.swift    # NEW
│   ├── DeviceImageGridView.swift       # NEW
│   ├── FullScreenImageViewer.swift     # NEW
│   └── ImageTypeFilter.swift           # NEW
├── Camera/
│   ├── CameraPickerView.swift          # NEW
│   └── ImageUploadProgressView.swift   # NEW
├── Editors/
│   ├── TextFieldEditorSheet.swift      # NEW
│   ├── AddPartSheet.swift              # NEW
│   ├── AddAccessorySheet.swift         # NEW
│   └── AddLineItemSheet.swift          # NEW

Core/
├── Services/
│   └── ImageService.swift              # NEW
├── Networking/
│   ├── APIClient.swift                 # Extend with multipart
│   └── APIEndpoints.swift              # Add new endpoints
└── Models/
    └── DeviceDetail.swift              # May need minor updates
```

---

## Estimated Total Effort

| Stage | Complexity | Estimate |
|-------|------------|----------|
| 01-API Layer | Medium | ~200 lines |
| 02-Image Service | Medium | ~300 lines |
| 03-Photo Gallery | Medium | ~400 lines |
| 04-Camera Integration | Medium | ~250 lines |
| 05-Inline Editing | Low | ~200 lines |
| 06-Add Parts | Low | ~150 lines |
| 07-Add Accessories | Low | ~150 lines |
| 08-Add Line Items | Medium | ~200 lines |
| 09-Delete Operations | Low | ~100 lines |
| **Total** | | **~1,950 lines** |

---

## Testing Strategy

1. **Unit Tests**: Model decoding for new response types
2. **Integration Tests**: API calls with mock responses
3. **Manual Testing**:
   - Take photo → see in gallery
   - Add part → see in list
   - Edit field → see saved value
   - Delete item → confirm removed
4. **Device Testing**: Test on real device for camera functionality

---

## Rollout Plan

1. Complete Stages 01-02 (foundation)
2. Complete Stages 03-04 (photo feature - highest value)
3. Complete Stage 05 (inline editing - high value)
4. Complete Stages 06-09 (CRUD operations)
5. Full regression test
6. Deploy to TestFlight
