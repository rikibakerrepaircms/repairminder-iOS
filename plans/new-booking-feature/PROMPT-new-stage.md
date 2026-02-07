# PROMPT: Start a New Booking Feature Stage

Use this prompt when starting work on a new stage of the New Booking feature. Replace `[STAGE_NUMBER]` and `[STAGE_NAME]` with the actual values (e.g., `01`, `Models & Endpoints`).

---

## The Prompt

```
I'm implementing the New Booking feature for the Repair Minder iOS app. I need you to implement Stage [STAGE_NUMBER]: [STAGE_NAME].

## Task Overview

Read the stage plan file and implement it exactly:
- Plan file: `plans/new-booking-feature/[STAGE_NUMBER]-[filename].md`
- Master plan: `plans/new-booking-feature/00-master-plan.md`

## Scope Boundaries

- ONLY implement what is specified in the stage plan file
- Do NOT modify files outside the scope of this stage
- Do NOT add features, refactoring, or "improvements" beyond the plan
- Do NOT skip ahead to later stages
- If a dependency from an earlier stage is missing, STOP and tell me

## Reference Files (READ THESE FIRST)

Before writing any code:

1. **Token management rules**: Read `docs/REFERENCE-test-tokens/CLAUDE.md`
   - Follow Rule 1 (token reuse) and Rule 2 (test data company) exactly
   - If you need to make API calls to verify endpoints, generate a token using the magic link flow:
     - Step 1: Request magic link for `rikibaker+admin@gmail.com`
     - Step 2: Get code from D1 via wrangler (run from `/Volumes/Riki Repos/repairminder` directory):
       ```bash
       npx wrangler d1 execute repairminder_database --remote --json --command "SELECT magic_link_code FROM users WHERE email = 'rikibaker+admin@gmail.com'" 2>/dev/null | jq -r '.[0].results[0].magic_link_code'
       ```
     - Step 3: Exchange code for JWT token
     - Step 4: Update the CLAUDE.md token file with the new token

2. **Backend API handlers** (verify endpoint shapes before coding):
   - Order creation: `/Volumes/Riki Repos/repairminder/worker/order_handlers.js`
   - Device operations: `/Volumes/Riki Repos/repairminder/worker/device_handlers.js`
   - Brand/model search: `/Volumes/Riki Repos/repairminder/worker/brand_handlers.js`
   - Locations: `/Volumes/Riki Repos/repairminder/worker/location_handlers.js`
   - Device types: `/Volumes/Riki Repos/repairminder/worker/device_types_handlers.js`
   - Company public info: `/Volumes/Riki Repos/repairminder/worker/index.js` (search for "public-info")

3. **Existing iOS code** (understand patterns before writing new code):
   - API client: `Repair Minder/Repair Minder/Core/Networking/APIClient.swift`
   - API endpoints: `Repair Minder/Repair Minder/Core/Networking/APIEndpoints.swift`
   - API response wrapper: `Repair Minder/Repair Minder/Core/Models/APIResponse.swift`
   - Existing models: `Repair Minder/Repair Minder/Core/Models/`
   - Signature component: `Repair Minder/Repair Minder/Features/Customer/Components/CustomerSignatureView.swift`

## Critical Coding Rules

- Use `.convertFromSnakeCase` decoder strategy — do NOT add explicit snake_case raw values in CodingKeys (e.g., use `case ticketNumber` not `case ticketNumber = "ticket_number"`)
- Use `.convertToSnakeCase` encoder strategy — same rule applies for encoding
- Exception: `addressLine1` / `addressLine2` need explicit CodingKeys because `.convertToSnakeCase` produces `address_line1` (missing underscore before number), but backend expects `address_line_1`
- Backend wraps all responses in `{ success: true, data: { ... } }` — the APIClient already handles this
- Boolean fields may come as Int (0/1) — handle with flexible decoding
- Use `@Observable` macro (not `@ObservableObject`) for ViewModels
- Use `@State private var` in views (not `@StateObject`)
- Use `@Bindable var viewModel` when passing to child views

## Verification Steps

After implementing, verify the build:

1. **Build in simulator** using the Xcode MCP:
   - Set session defaults: project path, scheme "Repair Minder", simulator "iPhone 17 Pro"
   - Run `build_sim` to compile
   - If build fails, fix errors and rebuild

2. **Run in simulator** (if the stage adds UI):
   - Use `build_run_sim` to build and launch
   - Take a screenshot to verify the UI renders correctly
   - Navigate to the new feature and verify it appears

3. **Verify API integration** (if the stage adds network calls):
   - Generate a fresh token using the magic link flow above
   - Test the endpoint with curl to confirm the response shape matches your model
   - Run the app and verify the network call works

## Completion Checklist

Before marking this stage as done, confirm ALL of the following:
- [ ] All files from the stage plan have been created/modified
- [ ] Build passes without errors (`build_sim` succeeds)
- [ ] No warnings introduced in new files
- [ ] Code follows existing patterns in the codebase
- [ ] CodingKeys do NOT have explicit snake_case raw values (let decoder handle it)
- [ ] All models match the actual backend API response shapes
- [ ] Previews render without error (if applicable)
- [ ] Stage plan acceptance checklist is fully satisfied
```

---

## Stage File Reference

| Stage | File | Description |
|-------|------|-------------|
| 01 | `01-models-and-api-endpoints.md` | Models & API endpoint cases |
| 02 | `02-booking-view-model.md` | BookingViewModel + form data |
| 03 | `03-service-type-selection.md` | BookingView with service cards |
| 04 | `04-wizard-container.md` | BookingWizardView + step progress |
| 05 | `05-client-step.md` | Client search/creation |
| 06 | `06-devices-step.md` | Device entry forms |
| 07 | `07-summary-step.md` | Review + ready-by + pre-auth |
| 08 | `08-signature-step.md` | Terms + signature capture |
| 09 | `09-confirmation-step.md` | Submit + success screen |
| 10 | `10-dashboard-integration.md` | FAB + fullScreenCover |
