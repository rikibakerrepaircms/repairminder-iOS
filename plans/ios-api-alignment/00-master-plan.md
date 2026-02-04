# iOS App API Alignment - Master Plan

## Feature Overview

The iOS app (Staff and Customer targets) was built against assumed API structures that don't match the actual backend. This causes:
- JSON decoding failures ("Failed to decode response")
- Features that silently fail or show no data
- Endpoints calling paths that don't exist
- Request/response format mismatches

This plan systematically reviews and fixes every API integration in both app targets.

## Success Criteria

- [ ] Staff app builds without errors
- [ ] Customer app builds without errors
- [ ] All Staff app screens load data successfully (Dashboard, Orders, Devices, Clients, Enquiries)
- [ ] All Customer app screens load data successfully (Orders, Order Detail)
- [ ] Push notifications register and receive on both apps
- [ ] No "Failed to decode response" errors in Xcode console
- [ ] Quote approval flow works with signature capture
- [ ] All API calls match backend endpoint paths exactly

## Dependencies & Prerequisites

1. **Backend codebase access**: `/Volumes/Riki Repos/repairminder`
2. **iOS codebase access**: `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS`
3. **Reference document**: `IOS_API_VERIFICATION_DOCUMENT.md` (existing analysis)
4. **Backend routes file**: `worker/index.js` (source of truth for endpoints)

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Backend endpoint changes during fix | Low | High | Lock backend version, coordinate with backend team |
| Breaking existing functionality | Medium | Medium | Test each stage independently before moving on |
| Missing edge cases in response formats | Medium | Low | Use backend handler code as source of truth |
| Customer app features need backend work | High | Medium | Document and defer to separate backend plan |

## Stage Index

| Stage | Name | Complexity | Description |
|-------|------|------------|-------------|
| 01 | Core Models - Device | High | Fix Device.swift to match backend response structure |
| 02 | Core Models - Client & Ticket | Medium | Fix Client.swift and Ticket.swift models |
| 03 | Core Models - Order & Dashboard | Medium | Fix Order.swift and DashboardStats.swift models |
| 04 | Staff Auth & API Client | Medium | Verify auth flow and fix API response handling |
| 05 | Staff Dashboard & My Queue | Low | Fix dashboard view model and my-queue integration |
| 06 | Staff Orders | Medium | Fix order list and detail view models |
| 07 | Staff Devices | Medium | Fix device list, detail, and status update flows |
| 08 | Staff Clients | Low | Fix client list and detail view models |
| 09 | Staff Enquiries | Medium | Fix enquiry/ticket list, detail, and reply flows |
| 10 | Staff Settings & Push | High | Fix settings, implement push notification registration |
| 11 | Customer Auth | Medium | Fix customer magic link login flow |
| 12 | Customer Orders & Quotes | High | Fix order detail, add signature capture for approval |
| 13 | Customer Cleanup | Low | Remove non-working features (enquiries, messages tabs) |
| 14 | Customer Push | Medium | Implement customer app push notifications |
| 15 | Integration Testing | Medium | End-to-end testing of both apps |

## Out of Scope

- **Backend changes**: This plan only modifies iOS code. If backend endpoints are missing, document for separate plan.
- **New features**: Only fixing existing features to work correctly.
- **UI/UX improvements**: No design changes unless required for functionality (e.g., signature capture).
- **Offline mode / CoreData**: Offline sync has been removed; this plan focuses on online-only API calls.
- **Unit tests**: Focus is on functional correctness; test coverage is a separate effort.

## File Structure Reference

```
Repair Minder/
├── Core/
│   ├── Models/
│   │   ├── Device.swift         [Stage 01]
│   │   ├── Client.swift         [Stage 02]
│   │   ├── Ticket.swift         [Stage 02]
│   │   ├── Order.swift          [Stage 03]
│   │   └── DashboardStats.swift [Stage 03]
│   └── Networking/
│       ├── APIClient.swift      [Stage 04]
│       ├── APIEndpoints.swift   [Multiple stages]
│       └── APIResponse.swift    [Stage 04]
├── Features/
│   ├── Auth/                    [Stage 04]
│   ├── Dashboard/               [Stage 05]
│   ├── Orders/                  [Stage 06]
│   ├── Devices/                 [Stage 07]
│   ├── Clients/                 [Stage 08]
│   ├── Enquiries/               [Stage 09]
│   ├── Settings/                [Stage 10]
│   └── Scanner/                 [Stage 09]
├── Customer/
│   ├── Auth/                    [Stage 11]
│   ├── Orders/                  [Stage 12]
│   ├── Enquiries/               [Stage 13 - DELETE]
│   └── Messages/                [Stage 13 - DELETE]
└── App/
    └── AppDelegate.swift        [Stage 10, 14]
```

## Backend Reference

All endpoint verification should use:
- **Routes**: `/Volumes/Riki Repos/repairminder/worker/index.js`
- **Search pattern**: `case path === '/api/...'` to find route handlers
- **Handler functions**: Named `handle*` functions contain request/response logic

## Verification Process

For each endpoint:
1. Find route in `worker/index.js`
2. Read handler function to get exact request body and response format
3. Update iOS model to match response exactly
4. Update endpoint definition if path/method is wrong
5. Test with real API call

## Timeline Estimate

- Stages 01-03 (Models): Foundation work, do first
- Stages 04-10 (Staff App): Can parallelize some stages
- Stages 11-14 (Customer App): Depends on model fixes
- Stage 15: Final validation

Total: ~15 worker sessions
