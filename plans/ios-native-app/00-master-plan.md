# RepairMinder iOS Native App - Master Plan

## Feature Overview

Convert the existing RepairMinder web application (React/TypeScript) into a native iOS app built with SwiftUI. The app will serve **two user types**:

1. **Staff App** - For technicians, engineers, and office staff to manage repairs
2. **Customer Portal** - For end customers to track their repair status

The iOS app will connect to the existing API at `api.repairminder.com` and provide full offline support with background sync.

### Why Native iOS?

- Better performance and UX than web wrapper
- Native iOS features (push notifications, widgets, Shortcuts)
- Offline-first capability for field technicians
- Camera/QR scanning integration
- Keychain security for credentials

---

## Success Criteria

| Criteria | Measurement |
|----------|-------------|
| Staff can view/manage orders | Create, edit, update status on orders |
| Staff can scan QR/barcodes | Camera scan identifies devices/assets |
| Dashboard shows live stats | Revenue, devices, lifecycle metrics load correctly |
| Customers can track repairs | View order status, timeline, communicate |
| **Customers can approve/reject quotes** | **Quote cards with action buttons** |
| **Customers can submit new enquiries** | **Enquiry form to previous shops** |
| **Staff can manage enquiries** | **Polished inbox with conversations** |
| Offline mode works | App usable without network, syncs when online |
| Push notifications work | Receive alerts for orders, **enquiries**, **tickets** |
| Authentication secure | JWT tokens stored in Keychain, refresh works |
| App passes App Store review | No crashes, meets Apple guidelines |
| White-label builds work | Same codebase, different branding per client |

---

## Dependencies & Prerequisites

### Required Before Starting

1. **Xcode 16+** installed (confirmed)
2. **iOS 17+ simulator** or physical device for testing
3. **Apple Developer account** for push notifications and App Store
4. **API access** to `api.repairminder.com` (existing, no changes needed)
5. **Push notification certificates** (to be created in Stage 11)

### Existing Infrastructure

- [Ref: /Volumes/Riki Repos/repairminder/src/services/api.ts] - API client reference
- [Ref: /Volumes/Riki Repos/repairminder/worker/] - Backend API implementation
- API Base URL: `https://api.repairminder.com`

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| API rate limiting on mobile | Medium | High | Implement request queuing, caching |
| Offline sync conflicts | High | Medium | Last-write-wins with conflict UI for critical data |
| Push notification setup complexity | Medium | Medium | Document step-by-step, test early |
| Large data sets performance | Medium | Medium | Pagination, lazy loading, Core Data indices |
| App Store rejection | Low | High | Follow HIG, test thoroughly, no private APIs |
| Token refresh edge cases | Medium | High | Robust refresh logic, graceful logout on failure |

---

## Stage Index

| Stage | Name | Description |
|-------|------|-------------|
| 01 | Project Architecture ✅ | Set up folder structure, targets, dependencies |
| 02 | Networking Layer ✅ | API client, request/response handling, error types |
| 03 | Authentication ✅ | Login, token storage, refresh, logout |
| 04 | Core Data Models ✅ | Offline storage schema, entity definitions |
| 05 | Sync Engine ✅ | Background sync, conflict resolution, queue management |
| 06 | Staff Dashboard ✅ | Stats, charts, quick actions for staff |
| 07 | Orders Module ✅ | Order list, detail, create, edit, status updates |
| 08 | Devices Module ✅ | Device list, detail, status management |
| 09 | QR Scanner ✅ | Camera scanning, device lookup, asset identification |
| 10 | Clients Module ✅ | Client list, detail, order history |
| 11 | Push Notifications ✅ | APNS setup, notification handling, deep linking |
| 12 | Customer Portal ✅ | Customer login, order tracking, **quote approval**, **new enquiries** |
| 13 | Settings & Polish ✅ | User preferences, app settings, final polish |
| 14 | White-Label Support ✅ | Re-brandable builds for clients (logo, colors, bundle ID) |
| 15 | Enquiries Module ✅ | Staff enquiry inbox, conversations, convert to order |

---

## Out of Scope

This plan does **NOT** cover:

- **iPad-specific layouts** (will work on iPad but not optimized)
- **Apple Watch app** (future enhancement)
- **macOS Catalyst** (future enhancement)
- **Widgets** (future enhancement, after v1.0)
- **Siri Shortcuts** (future enhancement)
- **Social media features** (social export from web app)
- **Invoice PDF generation** (view only, generate via API)
- **Admin/Master Admin features** (staff app for regular users only)
- **Macro creation/editing** (view macro status only)
- **VAT reports** (web-only feature)
- **API key management** (web-only feature)
- **Custom domain setup** (web-only feature)

---

## Technical Decisions

### Architecture Pattern
- **MVVM** with SwiftUI
- **Repository pattern** for data access (API + Core Data)
- **Dependency injection** via Environment

### Key Technologies
- **SwiftUI** - UI framework (iOS 17+)
- **Core Data** - Offline storage
- **Swift Concurrency** - async/await for networking
- **Keychain** - Secure credential storage
- **AVFoundation** - Camera/QR scanning
- **UserNotifications** - Push notifications
- **BackgroundTasks** - Background sync

### Targets
1. **Repair Minder** - Staff app (primary)
2. **Repair Minder Customer** - Customer portal (separate target sharing code)

---

## File Structure (Target State)

```
Repair Minder/
├── App/
│   ├── RepairMinderApp.swift
│   └── AppDelegate.swift (push notifications)
├── Core/
│   ├── Networking/
│   │   ├── APIClient.swift
│   │   ├── APIEndpoints.swift
│   │   ├── APIError.swift
│   │   └── RequestInterceptor.swift
│   ├── Storage/
│   │   ├── CoreDataStack.swift
│   │   ├── KeychainManager.swift
│   │   └── SyncEngine.swift
│   └── Models/
│       ├── User.swift
│       ├── Order.swift
│       ├── Device.swift
│       ├── Client.swift
│       └── ...
├── Features/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   ├── LoginViewModel.swift
│   │   └── AuthManager.swift
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── DashboardViewModel.swift
│   │   └── Components/
│   ├── Orders/
│   │   ├── OrderListView.swift
│   │   ├── OrderDetailView.swift
│   │   └── OrderViewModel.swift
│   ├── Enquiries/               # Staff enquiry management
│   │   ├── EnquiryListView.swift
│   │   ├── EnquiryDetailView.swift
│   │   └── Components/
│   ├── Devices/
│   ├── Clients/
│   ├── Scanner/
│   └── Settings/
├── Shared/
│   ├── Components/
│   │   ├── LoadingView.swift
│   │   ├── ErrorView.swift
│   │   └── StatCard.swift
│   ├── Extensions/
│   └── Utilities/
└── Resources/
    ├── Assets.xcassets
    ├── RepairMinder.xcdatamodeld
    └── Localizable.strings
```

---

## Timeline Estimate

| Stage | Complexity | Estimated Effort |
|-------|------------|------------------|
| 01-03 | Foundation | Core setup |
| 04-05 | Complex | Offline/sync |
| 06-10 | Medium each | Feature modules |
| 11 | Medium | Push notifications |
| 12 | Medium | Customer portal + quote approval |
| 13 | Low | Polish |
| 14 | Medium | White-label infrastructure |
| 15 | Medium | Enquiries module (polished UI) |

---

## Next Steps

1. Begin with [See: Stage 01] - Project Architecture
2. Each stage builds on previous stages
3. Test incrementally after each stage
4. Stages 01-05 must be completed sequentially
5. Stages 06-10 can be parallelized after Stage 05
