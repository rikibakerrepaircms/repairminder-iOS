# Passcode Lock with Face ID / Touch ID — Master Plan

## Feature Overview

Add a server-side passcode system to Repair Minder. On first iOS login, users create a 6-digit PIN that is stored (hashed) in the database. On subsequent app opens, the passcode is required to access the app — with Face ID / Touch ID as an optional bypass. The passcode is reusable across the platform (web, future apps) since it lives server-side. Users can reset their passcode via an email link if forgotten.

### Why
- Repair shops handle sensitive customer data, device info, and financials
- Adds a second layer of security beyond magic link / 2FA login
- Server-side storage means the passcode can gate sensitive actions on web/API too
- Biometric bypass keeps the UX fast for daily use

---

## Success Criteria

- [x] Users table has `passcode_hash`, `passcode_salt`, `passcode_enabled`, `passcode_timeout_minutes` columns
- [x] API endpoints exist: set-passcode, verify-passcode, reset-passcode-request, reset-passcode
- [x] On first iOS login, user is prompted to create a 6-digit passcode (can skip with "Set up later")
- [x] On subsequent app opens (after timeout), passcode entry screen is shown
- [x] Correct passcode (verified server-side) unlocks the app
- [x] Face ID / Touch ID can bypass passcode entry (when enabled)
- [x] Configurable timeout (default 15 minutes) — stored server-side per user
- [x] User can change passcode in Settings (requires current passcode)
- [x] User can reset passcode via email link ("Forgot Passcode?")
- [x] `NSFaceIDUsageDescription` present in Info.plist
- [x] Project builds and runs without errors

---

## Dependencies & Prerequisites

| Dependency | Status |
|-----------|--------|
| Cloudflare D1 database access | Exists |
| Cloudflare Workers backend | Exists [Ref: /Volumes/Riki Repos/repairminder/worker/] |
| Email service (Postmark/Brevo) | Exists [Ref: worker/src/email.js] |
| iOS `LocalAuthentication` framework | Built into SDK |
| iOS `CryptoKit` framework | Built into SDK |
| `KeychainManager` singleton | Exists [Ref: Core/Auth/KeychainManager.swift] |
| `AuthManager` singleton | Exists [Ref: Core/Auth/AuthManager.swift] |
| `AppState` singleton | Exists [Ref: App/AppState.swift] |
| User model with `hasPasscode` field | Needs adding |

---

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| User forgets passcode and can't access app | High | Medium | "Forgot Passcode?" sends reset email; also available from lock screen |
| Backend down during passcode verify | High | Low | Cache last-verified passcode hash locally in Keychain; verify locally if offline |
| API latency on every unlock | Medium | Medium | Verify locally against cached hash; sync with backend periodically |
| User has no email access for reset | Medium | Low | Admin can reset passcode from web dashboard (future) |
| Migration fails on existing users | Medium | Low | All new columns are nullable/have defaults; existing users get `has_passcode = false` |

---

## Stage Index

| Stage | Name | Description |
|-------|------|-------------|
| 01 | Backend: Database & API [COMPLETE] | Add passcode columns to users table, create set/verify/reset API endpoints, add reset email template |
| 02 | iOS: Core Service [COMPLETE] | Create `PasscodeService` with backend API calls, local hash caching, and biometric auth |
| 03 | iOS: PIN Entry UI [COMPLETE] | Build `NumberPadView`, `SetPasscodeView`, and `PasscodeLockView` components |
| 04 | iOS: First Login & App Lock [COMPLETE] | Wire passcode setup into first-login flow, add scene phase monitoring for app lock |
| 05 | iOS: Settings & Reset [COMPLETE] | Add passcode settings (change, timeout, biometric toggle) and forgot-passcode email reset flow |

---

## Configurability

The passcode feature is **fully optional and configurable by the user**:

- On first login, user is **prompted** to set a passcode but can **skip** ("Set up later")
- User can **enable/disable** passcode entirely from Settings → Security (iOS) or app.mendmyi.com/settings/account (web)
- When disabled: no lock screen, no passcode prompts
- When enabled: configurable timeout (1 min, 5 min, 15 min, 30 min, 1 hour) stored server-side
- `passcode_enabled` stored as column on users table (not just implied by hash presence) so web dashboard can read/write it too

---

## Out of Scope

- Web dashboard passcode settings page implementation (API supports it — web team implements separately)
- Admin ability to reset a user's passcode from dashboard
- Passcode required for specific sensitive actions (e.g. approve quote)
- Customer portal passcode (staff-only for now)
- Auto-wipe after X failed attempts
- Alphanumeric passcode (6-digit numeric only)
- Lockout/cooldown timers after failed attempts

---

## Data Flow

```
┌─────────────┐     POST /api/auth/set-passcode      ┌──────────────┐
│  iOS App     │ ──────────────────────────────────── │  Backend     │
│              │     POST /api/auth/verify-passcode   │  (Workers)   │
│ PasscodeService ◄──────────────────────────────── │              │
│              │     POST /api/auth/reset-passcode-*  │  D1 Database │
│ Keychain     │                                      │  users table │
│ (cached hash)│                                      │              │
└─────────────┘                                       └──────────────┘

First Login:
  Auth complete → API returns has_passcode: false → Force SetPasscodeView
  → User enters 6-digit PIN → POST /api/auth/set-passcode
  → Backend hashes + stores → Returns success
  → App caches hash locally → Proceeds to dashboard

App Unlock:
  App returns from background (after timeout) → Show PasscodeLockView
  → User enters PIN (or biometric) → Verify locally against cached hash
  → If valid → Unlock → Optionally verify with backend in background
  → If no cached hash → POST /api/auth/verify-passcode to backend

Reset Flow:
  Lock screen → "Forgot Passcode?" → POST /api/auth/reset-passcode-request
  → Email sent with reset link/code → User enters new passcode
  → POST /api/auth/reset-passcode → Backend updates hash → App caches new hash
```

---

## File Map

### Backend (new/modified)

```
worker/migrations/0268_add_passcode_fields.sql   — New migration
worker/src/auth.js                                 — Add passcode endpoints
worker/src/database.js                             — Add passcode DB methods
worker/src/email.js                                — Add reset email template
worker/index.js                                    — Register new routes
```

### iOS (new)

```
Core/Services/PasscodeService.swift
Core/Auth/PasscodeAPIModels.swift
Features/Settings/Security/NumberPadView.swift
Features/Settings/Security/SetPasscodeView.swift
Features/Settings/Security/PasscodeLockView.swift
Features/Settings/Security/PasscodeLockViewModel.swift
Features/Settings/Security/PasscodeSettingsView.swift
Features/Settings/Security/PasscodeSettingsViewModel.swift
Features/Settings/Security/ResetPasscodeView.swift
```

### iOS (modified)

```
Core/Auth/KeychainManager.swift      — Add passcode cache methods
Core/Auth/AuthManager.swift          — Check has_passcode after login
Core/Models/User.swift               — Add hasPasscode field
App/AppState.swift                   — Add passcodeSetup state
Repair_MinderApp.swift               — Add scene phase + lock overlay
Features/Settings/SettingsView.swift  — Add Security section
```
