# PROMPT: Check Completed Stage & Prepare Next

Use this prompt after a stage has been implemented to verify correctness, update the master plan, and generate the next stage's working prompt.

---

## The Prompt

```
I've just completed Stage [STAGE_NUMBER]: [STAGE_NAME] of the New Booking feature for the Repair Minder iOS app. I need you to verify the work, update progress, and prepare the next stage.

## Step 1: Read the Stage Plan

Read the stage plan file to understand what was supposed to be implemented:
- Stage plan: `plans/new-booking-feature/[STAGE_NUMBER]-[filename].md`
- Master plan: `plans/new-booking-feature/00-master-plan.md`

## Step 2: Read the Implemented Code

Read every file that was created or modified in this stage. Compare the actual implementation against the plan. Check for:

1. **Missing features** — Is anything from the plan not implemented?
2. **Extra features** — Was anything added that wasn't in the plan? (Flag for removal)
3. **Model accuracy** — Do Swift models match the actual backend API response shapes?
4. **CodingKeys correctness** — No explicit snake_case raw values when using `.convertFromSnakeCase`
5. **Exception check** — `addressLine1`/`addressLine2` DO need explicit CodingKeys (`.convertToSnakeCase` produces `address_line1` not `address_line_1`)
6. **Enum values** — Do enum raw values match backend constants exactly?
7. **API endpoint paths** — Do they match the backend routes?
8. **Response wrapper** — Does code properly handle the `{ success: true, data: { ... } }` envelope?

## Step 3: Cross-Reference Backend

Read the relevant backend handler files to verify the implementation matches reality:
- Backend handlers are at: `/Volumes/Riki Repos/repairminder/worker/`
- Key files: `order_handlers.js`, `device_handlers.js`, `brand_handlers.js`, `location_handlers.js`, `device_types_handlers.js`, `index.js`

For any endpoint used in this stage, verify:
- Request path and HTTP method
- Request body fields (names, types, required vs optional)
- Response body shape (field names, types, nesting)

## Step 4: Build Verification

Verify the project builds successfully:

1. **Build in simulator** using the Xcode MCP:
   - Set session defaults: project path, scheme "Repair Minder", simulator "iPhone 17 Pro"
   - Run `build_sim` to verify compilation
   - If build fails, list all errors

2. **Run in simulator** (if this stage added UI):
   - Use `build_run_sim` to build and launch
   - Take a screenshot to verify the UI
   - Navigate to the booking feature and verify the new stage's UI renders

3. **Test API calls** (if this stage added network calls):
   - Read `docs/REFERENCE-test-tokens/CLAUDE.md` for token management rules
   - Check if a valid token exists; if expired, generate a new one:
     - Request magic link for `rikibaker+admin@gmail.com`
     - Get code from D1 (run from `/Volumes/Riki Repos/repairminder` directory):
       ```bash
       npx wrangler d1 execute repairminder_database --remote --json --command "SELECT magic_link_code FROM users WHERE email = 'rikibaker+admin@gmail.com'" 2>/dev/null | jq -r '.[0].results[0].magic_link_code'
       ```
     - Exchange code for JWT, update CLAUDE.md
   - Test the endpoint with curl to confirm it returns expected data
   - Run the app and verify the call works end-to-end

## Step 5: Report Findings

Provide a structured report:

### Build Status
- [ ] Build passes without errors
- [ ] No new warnings introduced

### Implementation Accuracy
For each item in the stage plan's acceptance checklist:
- [ ] Item description — PASS / FAIL (with details if fail)

### Issues Found
List any issues found, categorised by severity:
- **CRITICAL** — Will cause runtime crash or data loss
- **MAJOR** — Feature won't work correctly
- **MINOR** — Cosmetic, naming, or non-blocking issues

### Fixes Applied
If you fix any issues, list what you changed and why.

## Step 6: Update Master Plan

If the stage is fully complete and verified:
- Note the stage completion status (do NOT modify the master plan file unless explicitly asked)

## Step 7: Prepare Next Stage Prompt

Generate a ready-to-paste prompt for the NEXT stage using the template from `plans/new-booking-feature/PROMPT-new-stage.md`. Fill in:
- The next stage number
- The next stage name
- Any specific notes or dependencies from the stage just completed that the next stage needs to know about (e.g., "BookingViewModel is now at path X", "Location model uses Y pattern", etc.)

Output the prompt in a code block so I can copy-paste it directly.
```

---

## When to Use This Prompt

Use after completing each stage:
- Stage 01 done → Check Stage 01, prepare Stage 02 prompt
- Stage 02 done → Check Stage 02, prepare Stage 03 prompt
- ...and so on through Stage 10

## Notes

- The checking prompt deliberately re-reads backend handlers every time — this catches drift
- Token generation uses wrangler D1 access (must be run from `/Volumes/Riki Repos/repairminder`)
- Xcode MCP build verification catches compile errors that might not show in the plan review
- The "prepare next stage" step ensures context carries forward between stages
