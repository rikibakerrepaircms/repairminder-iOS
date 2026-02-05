# Passcode Lock — Checking Work Prompt

Copy the prompt below and paste it into a Claude session after a stage is completed.

Replace `Stage X` with the stage number that was just completed (e.g., `Stage 1`).

---

```
You are a technical project manager reviewing completed work.

---

## CONFIGURATION

**Master Plan Path:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/passcode-lock/00-master-plan.md`
**Stage Documents:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/passcode-lock/`
**Backend Repo:** `/Volumes/Riki Repos/repairminder/`
**iOS Repo:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/`
**Just Completed:** Stage 1

---

## Part 1: Review the Completed Stage

Read the stage document for the just-completed stage, then verify it was implemented correctly.

### Code Review
- Were the correct files modified?
- Does the implementation match the spec?
- Any obvious bugs, edge cases missed, or code quality issues?
- Is the passcode properly optional/configurable? (Users must be able to turn it off)

### Schema Verification (for backend stages)
Verify the D1 schema matches expectations:
```bash
cd "/Volumes/Riki Repos/repairminder" && npx wrangler d1 execute repairminder_database --remote --command "PRAGMA table_info(users)"
```

### Deployment Verification
- Was the worker deployed? (Check: `cd "/Volumes/Riki Repos/repairminder/worker" && npx wrangler deploy` if needed)
- Can you verify it's live? Hit the endpoints and check responses.

### API Testing ⚠️ REQUIRED
- Read `docs/REFERENCE-test-tokens/CLAUDE.md` in BOTH repos for JWT tokens and wrangler commands:
  - `/Volumes/Riki Repos/repairminder/docs/REFERENCE-test-tokens/CLAUDE.md`
  - `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/docs/REFERENCE-test-tokens/CLAUDE.md`
- Use tokens from CLAUDE.md to test all endpoints
- If tokens are expired, generate new ones using the process in CLAUDE.md and UPDATE the file
- Run specific curl commands to verify each acceptance criterion
- Test cross-platform readiness: verify the API responses contain all fields needed by both iOS and web

### iOS Build & Simulator Verification (for iOS stages) ⚠️ REQUIRED
- Build and run on simulator: use `mcp__XcodeBuildMCP__build_run_sim`
- Project: `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder.xcodeproj`
- Simulator: iPhone 16 Pro
- Verify no compilation errors
- Check that new files are added to the Xcode project
- **Log into the app with the test account and verify the feature works:**
  1. Login with `rikibaker+admin@gmail.com` using magic link
  2. Get the code: `cd "/Volumes/Riki Repos/repairminder" && npx wrangler d1 execute repairminder_database --remote --json --command "SELECT magic_link_code FROM users WHERE email = 'rikibaker+admin@gmail.com'" 2>/dev/null | jq -r '.[0].results[0].magic_link_code'`
  3. Enter the code in the app
  4. Navigate to the relevant screens (e.g., Settings → Security) and verify the feature works
  5. Test the happy path AND at least one error path (e.g., wrong PIN)
  6. Take a screenshot to confirm the UI renders correctly

### If you find issues:

**Fixable issues** (minor bugs, missing error handling you can add):
→ Fix them, redeploy if needed, and note what you changed.

**Blocking issues** (broken functionality, spec deviation, failed deployment):
→ STOP and tell me what's wrong. Do NOT proceed to the next stage.

---

## 🚫 GATE: Do not proceed until the completed stage fully works.

---

## Part 2: Update Progress

Mark the completed stage as done in the Master Plan:
- Add ✅ to the stage heading in `00-master-plan.md`
- Update the Stage Index table with `[COMPLETE]`

---

## Part 3: Create the Next Stage Worker Prompt

Generate the prompt for the NEXT stage using the same format:

**1. Task Overview**
- Which file(s) and function(s) to modify
- Reference to specific sections of the next stage document

**2. Scope Boundaries**
- What they SHOULD do
- What they should NOT do (future stages, out-of-scope)

**3. Reference Files** ⚠️ REQUIRED
- Direct the worker to check `docs/REFERENCE-test-tokens/CLAUDE.md` in BOTH repos:
  - `/Volumes/Riki Repos/repairminder/docs/REFERENCE-test-tokens/CLAUDE.md` — wrangler commands, D1 access, token generation, deployment
  - `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/docs/REFERENCE-test-tokens/CLAUDE.md` — same tokens for cross-reference
- If the stage involves authenticated API calls, they MUST use tokens from this file
- If the stage involves D1 queries, they MUST use wrangler commands from this file

**4. Verification Steps** ⚠️ REQUIRED
- How to test their changes (curl commands, simulator build, etc.)
- Specific test cases using reference tokens where applicable
- Expected outputs
- For iOS stages: build and run on simulator, navigate to the relevant screen

**5. Simulator Verification (for iOS stages)** ⚠️ REQUIRED
- Build and run: `mcp__XcodeBuildMCP__build_run_sim`
- Project: `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder.xcodeproj`
- Simulator: iPhone 16 Pro
- **Log in with the test account and verify the feature works end-to-end:**
  1. Login with `rikibaker+admin@gmail.com` using magic link
  2. Get magic link code from D1: `cd "/Volumes/Riki Repos/repairminder" && npx wrangler d1 execute repairminder_database --remote --json --command "SELECT magic_link_code FROM users WHERE email = 'rikibaker+admin@gmail.com'" 2>/dev/null | jq -r '.[0].results[0].magic_link_code'`
  3. Enter code in the app to complete login
  4. Navigate to relevant screens and test the feature
  5. Test happy path AND at least one error path
  6. Take a screenshot to confirm UI

**6. Deployment** ⚠️ REQUIRED
- Backend: `cd "/Volumes/Riki Repos/repairminder/worker" && npx wrangler deploy`
- iOS: `mcp__XcodeBuildMCP__build_run_sim` to build and verify
- Confirmation that deployment/build is PART OF the task, not optional
- How to verify it succeeded

**7. Completion Checklist**
- [ ] Code changes made
- [ ] Tests/verification pass
- [ ] Deployed/built successfully
- [ ] Simulator tested with test account login (for iOS stages)
- [ ] Deployment verified
- [ ] CLAUDE.md updated if new tokens were generated

### Format
Output the worker prompt in a code block so it can be copied directly.

If there is no next stage (all stages complete), confirm the project is complete and summarise:
- What was built
- All API endpoints created
- All iOS views created
- How to test the full end-to-end flow
```
