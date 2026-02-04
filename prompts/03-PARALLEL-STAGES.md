# RepairMinder iOS - Parallel Stages Prompt

Use this prompt **AFTER Stage 05 is complete** to generate worker prompts for all parallelizable stages.

---

## CONFIGURATION

**Master Plan Path:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/ios-native-app/00-master-plan.md`
**Test Tokens & API Reference:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/docs/REFERENCE-test-tokens/CLAUDE.md`
**Xcode Project:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/`

---

## Prerequisite Check

Before proceeding, verify Stage 05 (Sync Engine) is complete:
- [ ] Stage 05 marked as ✅ in Master Plan
- [ ] SyncEngine.swift exists and compiles
- [ ] Offline/online sync tested

If Stage 05 is NOT complete, STOP and complete it first.

---

## Task: Generate 6 Parallel Worker Prompts

Create separate, self-contained worker prompts for each of these stages:

| Stage | Name | Spec File |
|-------|------|-----------|
| 06 | Staff Dashboard | `plans/ios-native-app/06-staff-dashboard.md` |
| 07 | Orders Module | `plans/ios-native-app/07-orders-module.md` |
| 08 | Devices Module | `plans/ios-native-app/08-devices-module.md` |
| 09 | QR Scanner | `plans/ios-native-app/09-qr-scanner.md` |
| 10 | Clients Module | `plans/ios-native-app/10-clients-module.md` |
| 11 | Push Notifications | `plans/ios-native-app/11-push-notifications.md` |

---

## Each Prompt Must Include:

### 1. Task Overview
- Stage number and name
- Files to create (from the spec)
- Clear objective statement

### 2. Scope Boundaries

**SHOULD do:**
- Everything listed in the stage spec
- Use existing shared components from Stage 01
- Use networking layer from Stage 02
- Use auth from Stage 03
- Use Core Data models from Stage 04
- Use sync engine from Stage 05

**SHOULD NOT do:**
- Modify other stages' code (except adding navigation routes)
- Implement features from other parallel stages
- Break existing functionality

### 3. Reference Files
- Point to the specific stage spec file
- Reference `docs/REFERENCE-test-tokens/CLAUDE.md` for API testing
- Include relevant API endpoints from the web app reference

### 4. API Testing Commands
For each stage, provide curl commands to test relevant endpoints:

**Stage 06 (Dashboard):**
```bash
curl -s "https://api.repairminder.com/api/dashboard/stats" \
  -H "Authorization: Bearer TOKEN" | jq
```

**Stage 07 (Orders):**
```bash
curl -s "https://api.repairminder.com/api/orders?limit=10" \
  -H "Authorization: Bearer TOKEN" | jq
```

**Stage 08 (Devices):**
```bash
curl -s "https://api.repairminder.com/api/devices?limit=10" \
  -H "Authorization: Bearer TOKEN" | jq
```

**Stage 09 (QR Scanner):**
```bash
# Test device lookup by QR code
curl -s "https://api.repairminder.com/api/devices/lookup?code=TEST123" \
  -H "Authorization: Bearer TOKEN" | jq
```

**Stage 10 (Clients):**
```bash
curl -s "https://api.repairminder.com/api/clients?limit=10" \
  -H "Authorization: Bearer TOKEN" | jq
```

**Stage 11 (Push Notifications):**
```bash
# Test device token registration endpoint
curl -s -X POST "https://api.repairminder.com/api/user/device-token" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"deviceToken": "test-token", "platform": "ios"}' | jq
```

### 5. Verification Steps
- Build successfully
- Run on simulator
- Feature-specific manual tests
- Screenshot capture

### 6. Build Commands
```
mcp__XcodeBuildMCP__build_sim
mcp__XcodeBuildMCP__build_run_sim
mcp__XcodeBuildMCP__screenshot
```

### 7. Completion Checklist
Stage-specific items from the spec's Acceptance Checklist

---

## Output Format

Generate each prompt in a separate code block with a clear header:

```markdown
---
## Stage 06: Staff Dashboard - Worker Prompt
---
```

```
[Stage 06 prompt content here]
```

```markdown
---
## Stage 07: Orders Module - Worker Prompt
---
```

```
[Stage 07 prompt content here]
```

(Continue for all 6 stages...)

---

## Important Notes

1. **Independence**: Each prompt should be self-contained. A worker should be able to complete their stage without knowing about the other parallel stages.

2. **Shared Code**: All stages share:
   - `Core/Networking/APIClient.swift` (Stage 02)
   - `Core/Storage/CoreDataStack.swift` (Stage 04)
   - `Core/Storage/SyncEngine.swift` (Stage 05)
   - `Shared/Components/*` (Stage 01)

3. **Navigation**: Each stage should add its routes to `AppRouter.swift` but not remove existing routes.

4. **Token Usage**: Always use fresh tokens from `docs/REFERENCE-test-tokens/CLAUDE.md`. Tokens expire in 15 minutes.

5. **Test Company**: Use company ID `4b63c1e6ade1885e73171e10221cac53` (RepairMinder test company) for all test data.
