# RepairMinder iOS - Checking Work Prompt

You are a technical project manager reviewing completed work.

---

## CONFIGURATION

**Master Plan Path:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/ios-native-app/00-master-plan.md`
**Test Tokens & API Reference:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/docs/REFERENCE-test-tokens/CLAUDE.md`
**Xcode Project:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/`
**Just Completed:** Stage [NUMBER]

---

## Part 1: Review the Completed Stage

Verify the stage listed above was implemented correctly:

### Code Review
- Were the correct files created/modified?
- Does the implementation match the spec?
- Any obvious bugs, SwiftUI anti-patterns, or code quality issues?
- Are there any compiler warnings?

### Build Verification
- Does the project build successfully?
- Does it run on the simulator without crashes?

Use XcodeBuildMCP to verify:
```
mcp__XcodeBuildMCP__build_sim
mcp__XcodeBuildMCP__build_run_sim
mcp__XcodeBuildMCP__screenshot
```

### Test Coverage
- Were the acceptance criteria in the checklist met?
- Are there things I should manually test/verify?

### API Testing (if applicable)
For stages with API calls, verify using tokens from `docs/REFERENCE-test-tokens/CLAUDE.md`:

```bash
# Test API connectivity (replace TOKEN with valid token from CLAUDE.md)
curl -s "https://api.repairminder.com/api/dashboard/stats" \
  -H "Authorization: Bearer TOKEN" | jq '.success'
```

### If you find issues:

**Fixable issues** (minor bugs, missing error handling you can add):
→ Fix them, rebuild, and note what you changed.

**Blocking issues** (broken functionality, spec deviation, build failures):
→ STOP and tell me what's wrong. Do NOT proceed to the next stage.

---

## 🚫 GATE: Do not proceed until the completed stage fully works.

---

## Part 2: Update Progress

Mark the completed stage as done in the Master Plan:
- Add ✅ to the stage row in the Stage Index table
- Example: `| 01 | Project Architecture ✅ | Set up folder structure... |`

---

## Part 3: Create the Next Stage Worker Prompt

Generate the prompt for the next stage(s) using the same format:

1. **Task Overview** (files, functions, spec section reference)
2. **Scope Boundaries** (do / don't do)
3. **Reference Files** — point to `docs/REFERENCE-test-tokens/CLAUDE.md` for JWT tokens and API testing
4. **Verification Steps** (with specific test commands, curl examples where applicable)
5. **Build & Run** (XcodeBuildMCP commands)
6. **Completion Checklist**

### Parallel Stage Handling

After Stage 05 is complete, stages 06-10 can run in parallel. When generating prompts for parallel stages, create **separate prompts** for each:

**Example output format for parallel stages:**

---
### Stage 06 Worker Prompt
```
[prompt content for Stage 06]
```

---
### Stage 07 Worker Prompt
```
[prompt content for Stage 07]
```

---
### Stage 08 Worker Prompt
```
[prompt content for Stage 08]
```

(etc.)

---

Output each worker prompt in a code block.

If there is no next stage, confirm the project is complete and summarise what was built.

---

## Stage Dependency Reference

```
Sequential Stages (01-05):
  01 → 02 → 03 → 04 → 05

Parallel Batch after Stage 05:
  06 (Dashboard)     ─┐
  07 (Orders)        ─┼─ Can run simultaneously
  08 (Devices)       ─┤
  09 (QR Scanner)    ─┤
  10 (Clients)       ─┘
  11 (Push Notifications)

Dependencies:
  Stage 12 requires: 03 ✓ AND 11 ✓
  Stage 15 requires: 07 ✓ AND 11 ✓

Final Stages (after all features):
  13 (Settings & Polish)
  14 (White-Label)
```
