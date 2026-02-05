# Passcode Lock — New Project Prompt

Copy the prompt below and paste it into a new Claude session to begin work.

---

```
You are a technical project manager. Your task has two parts, with a GATE between them.

---

## CONFIGURATION

**Master Plan Path:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/passcode-lock/00-master-plan.md`
**Stage Documents:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/passcode-lock/`
**Backend Repo:** `/Volumes/Riki Repos/repairminder/`
**iOS Repo:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/`

---

## Part 1: Review the Specification

Read ALL specification documents in the plans/passcode-lock/ directory:
- `00-master-plan.md`
- `01-backend-database-api.md`
- `02-ios-core-service.md`
- `03-ios-pin-entry-ui.md`
- `04-ios-first-login-and-lock.md`
- `05-ios-settings-and-reset.md`

Review them for:
- **Completeness** — Are requirements clear? Any gaps that would block a developer?
- **Technical accuracy** — Do code snippets look correct? Are file/line references accurate?
- **Stage dependencies** — Is the order logical?
- **Test coverage** — Do checklists cover acceptance criteria and edge cases?
- **Configurability** — The passcode must be OPTIONAL. Users can skip setup on first login, enable/disable it from settings, and configure the timeout. `passcode_enabled` is a separate field from having a passcode hash set.
- **Cross-platform** — The API design must work for both iOS and the web dashboard at https://app.mendmyi.com/settings/account. The web team will consume the same endpoints.

### CRITICAL: Verify the D1 schema FIRST

Before reviewing any migration or database changes, run this command to check the ACTUAL current schema:

```bash
cd "/Volumes/Riki Repos/repairminder" && npx wrangler d1 execute repairminder_database --remote --command "PRAGMA table_info(users)"
```

Verify that:
- The columns proposed in the migration don't already exist
- The migration number (0268) is correct (check `ls worker/migrations/ | tail -5`)
- The proposed column types/defaults are compatible with existing patterns

### If you find issues:

**Fixable issues** (typos, minor code errors, missing details you can infer):
→ Fix them directly in the spec files and note what you changed.

**Blocking issues** (ambiguous requirements, missing context, decisions needed):
→ STOP and list your questions. Do NOT proceed to Part 2.

---

## 🚫 GATE: Do not proceed until the spec is accurate and complete.

---

## Part 2: Create the Stage 1 Worker Prompt

Only proceed here once the specification has no outstanding issues.

Write a clear prompt for a developer to implement **Stage 1 (Backend: Database & API)** only.

### The prompt MUST include these sections:

**1. Task Overview**
- Which file(s) and function(s) to modify
- Reference to specific sections of `01-backend-database-api.md`

**2. Scope Boundaries**
- What they SHOULD do: migration, API endpoints, email template, `/me` response update
- What they should NOT do: iOS code, web frontend, future stages

**3. Reference Files** ⚠️ REQUIRED
- Direct the worker to read `docs/REFERENCE-test-tokens/CLAUDE.md` in BOTH repos:
  - `/Volumes/Riki Repos/repairminder/docs/REFERENCE-test-tokens/CLAUDE.md` (backend — has wrangler commands, D1 access, token generation)
  - `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/docs/REFERENCE-test-tokens/CLAUDE.md` (iOS — same tokens, for cross-reference)
- Worker MUST use tokens from this file for all API testing
- Worker MUST use wrangler for all D1 database operations

**4. Verification Steps** ⚠️ REQUIRED
- Verify D1 schema before AND after migration
- Specific curl commands to test each endpoint using tokens from CLAUDE.md
- Test the full flow: set passcode → verify → change → reset-request → reset
- Verify `/api/auth/me` includes new `hasPasscode`, `passcodeEnabled`, `passcodeTimeoutMinutes` fields
- Expected outputs for each test

**5. Deployment** ⚠️ REQUIRED
- Run the D1 migration: `cd "/Volumes/Riki Repos/repairminder" && npx wrangler d1 execute repairminder_database --remote --file worker/migrations/0268_add_passcode_fields.sql`
- Deploy the worker: `cd "/Volumes/Riki Repos/repairminder/worker" && npx wrangler deploy`
- Verification: hit `/api/auth/me` with a valid token and confirm new fields appear
- Deployment is PART OF the task, not optional

**6. Simulator Verification (for iOS stages)** ⚠️ REQUIRED
- For any stage that touches iOS code, the worker MUST build and run on the simulator to verify
- Build command: use `mcp__XcodeBuildMCP__build_run_sim` (Xcode Build MCP tool)
- Project: `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder.xcodeproj`
- Simulator: iPhone 16 Pro
- **Test account login flow:**
  1. Login with `rikibaker+admin@gmail.com` using magic link
  2. Get the magic link code: `cd "/Volumes/Riki Repos/repairminder" && npx wrangler d1 execute repairminder_database --remote --json --command "SELECT magic_link_code FROM users WHERE email = 'rikibaker+admin@gmail.com'" 2>/dev/null | jq -r '.[0].results[0].magic_link_code'`
  3. Enter the code in the app to complete login
  4. Navigate to the relevant screen and verify the feature works visually
- Take screenshots if helpful to confirm UI is correct

**7. Completion Checklist**
- [ ] D1 schema verified before changes
- [ ] Migration file created and applied
- [ ] All API endpoints implemented (set, verify, change, reset-request, reset, toggle-enabled, update-timeout)
- [ ] `/api/auth/me` response updated with passcode fields
- [ ] Passcode reset email template added
- [ ] All endpoints tested with curl using tokens from CLAUDE.md
- [ ] Worker deployed to production
- [ ] Deployment verified (endpoints return expected responses)
- [ ] CLAUDE.md token file updated if new tokens were generated

### Format
Output the worker prompt in a code block so it can be copied directly. Keep it brief — the spec documents contain the detail.
```
