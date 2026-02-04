# Master Plan: Remove Offline Sync and Core Data

## Feature Overview

**What:** Remove all offline synchronization capabilities and Core Data storage from the Repair Minder iOS app.

**Why:** The app currently maintains a parallel Core Data layer for offline storage, but ViewModels already fetch data directly from the API. The offline sync infrastructure adds complexity without providing value since:
- Users expect real-time/live data, not cached offline data
- The sync layer creates potential data conflicts
- Maintenance overhead for dual data storage is high
- Core Data adds ~50KB+ to binary size

## Success Criteria

- [ ] App builds without Core Data framework dependency
- [ ] App launches and authenticates successfully
- [ ] All list views (Orders, Devices, Clients, Enquiries) load data from API
- [ ] All detail views load and display data correctly
- [ ] Pull-to-refresh works on all list views
- [ ] Settings view no longer shows sync-related UI
- [ ] No references to `SyncEngine`, `CoreDataStack`, `CDOrder`, `CDDevice`, `CDClient`, `CDTicket` remain
- [ ] App size reduced by removal of Core Data model

## Dependencies & Prerequisites

- Xcode 15+ installed
- iOS Simulator or device for testing
- Valid API credentials for testing
- Network connectivity for API access

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking compilation mid-refactor | Medium | High | Follow stage order strictly; each stage is independently compilable |
| Missing a Core Data reference | Low | Medium | Use Xcode's "Find in Project" to search for all CD* references |
| Losing functionality users depend on | Low | Low | ViewModels already use API directly; no user-facing functionality lost |
| Regression in data loading | Medium | Medium | Test each screen after implementation |

## Stage Index

| Stage | Name | Description |
|-------|------|-------------|
| 01 | Remove Model Core Data Extensions | Remove `import CoreData` and Core Data conversion methods from model files |
| 02 | Remove ViewModels Sync References | Remove SyncEngine references from all ViewModels |
| 03 | Remove App Infrastructure Sync | Remove sync triggers from app entry points (AppState, AppDelegate, etc.) |
| 04 | Remove Sync UI Components | Remove sync-related UI (banners, buttons, status rows) |
| 05 | Delete Core Data Files | Delete SyncEngine, CoreDataStack, Repositories, and xcdatamodeld |
| 06 | Update Xcode Project | Remove file references from project and clean build |

## Out of Scope

- **NOT** changing the APIClient or networking layer
- **NOT** modifying how ViewModels fetch data (they already use APIClient)
- **NOT** adding new caching mechanisms
- **NOT** implementing real-time updates (WebSockets/SSE)
- **NOT** changing the data models' Codable/Decodable conformance
- **NOT** modifying the Customer app target (changes apply to both targets naturally)

## Architecture Reference

**Current Architecture (Before):**
```
View → ViewModel → APIClient → API
                 ↘ SyncEngine → CoreDataStack → Core Data
```

**Target Architecture (After):**
```
View → ViewModel → APIClient → API
```

## File Summary

### Files to Delete (11 files)
- `Core/Storage/SyncEngine.swift`
- `Core/Storage/CoreDataStack.swift`
- `Core/Storage/PersistenceController.swift`
- `Core/Storage/Repositories/OrderRepository.swift`
- `Core/Storage/Repositories/DeviceRepository.swift`
- `Core/Storage/Repositories/ClientRepository.swift`
- `Core/Storage/Repositories/TicketRepository.swift`
- `Core/Models/SyncMetadata.swift`
- `Resources/RepairMinder.xcdatamodeld/`
- `Features/Dashboard/Components/SyncStatusBanner.swift`
- `Features/Settings/Components/SyncStatusRow.swift`

### Files to Modify (16 files)
- `Core/Models/Order.swift`
- `Core/Models/Device.swift`
- `Core/Models/Client.swift`
- `Core/Models/Ticket.swift`
- `Core/Models/TicketMessage.swift`
- `Features/Dashboard/DashboardViewModel.swift`
- `Features/Orders/OrderDetailViewModel.swift`
- `Features/Devices/DeviceDetailViewModel.swift`
- `Features/Settings/SettingsViewModel.swift`
- `App/AppState.swift`
- `App/AppDelegate.swift`
- `Core/Notifications/DeepLinkHandler.swift`
- `Repair_MinderApp.swift`
- `Features/Dashboard/DashboardView.swift`
- `Features/Settings/SettingsView.swift`
- `Features/Settings/DebugView.swift`
