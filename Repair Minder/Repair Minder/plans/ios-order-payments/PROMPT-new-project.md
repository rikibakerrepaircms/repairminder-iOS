# NEW PROJECT PROMPT

```
NEW PROJECT

You are a technical project manager. Your task has two parts, with a GATE between them.

---

## CONFIGURATION

**Master Plan Path:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder/plans/ios-order-payments/00-master-plan.md`

---

## Part 1: Review the Specification

Read the specification document at the Master Plan Path above, plus ALL stage files (01 through 05) in that same directory.

Review them for:
- Completeness — Are requirements clear? Any gaps that would block a developer?
- Technical accuracy — Do Swift code snippets look correct? Are file references accurate?
- Stage dependencies — Is the order logical? Are parallel stages truly independent?
- Model consistency — Do Decodable structs match the API response shapes described?
- iOS patterns — Do the proposed patterns (sheet presentation, state management, navigation) match the existing codebase conventions in `OrderItemFormSheet.swift` and `OrderDetailView.swift`?
- Test coverage — Do checklists cover acceptance criteria and edge cases?

### Additional verification steps:
1. Read `APIEndpoints.swift` and confirm the existing endpoint cases match what Stage 1 describes
2. Read `Order.swift` and confirm existing payment models (`OrderPayment`, `PaymentMethod`, `PaymentStatus`, `OrderTotals`, `OrderCompany`) match the spec
3. Read `OrderDetailViewModel.swift` and confirm the proposed extensions don't conflict with existing methods
4. Read `OrderDetailView.swift` and confirm the proposed section insertion points exist

### If you find issues:

**Fixable issues** (typos, minor code errors, missing details you can infer):
→ Fix them directly in the spec file(s) and note what you changed.

**Blocking issues** (ambiguous requirements, missing context, model mismatches, decisions needed):
→ STOP and list your questions. Do NOT proceed to Part 2.

---

## 🚫 GATE: Do not proceed until the spec is accurate and complete.

---

## Part 2: Create the Stage 1 Worker Prompt

Only proceed here once the specification has no outstanding issues.

Write a clear prompt for a developer to implement **Stage 1 only** (Models, API Endpoints & PaymentService).

### The prompt MUST include these sections:

**1. Task Overview**
- Which file(s) to create and modify
- Reference to specific sections of the Stage 1 spec
- Note that this is iOS-only (no backend changes, no deployment)

**2. Scope Boundaries**
- What they SHOULD do: Create `PosModels.swift`, add `ManualPaymentRequest` + `DevicePaymentBreakdown` to `Order.swift`, add 9 new `APIEndpoints` cases, create `PaymentService.swift`, extend `OrderDetailViewModel`
- What they should NOT do: No UI changes, no sheet creation (Stages 2-4), no `OrderDetailView` modifications (Stage 5)

**3. Reference Files** ⚠️ REQUIRED
- Direct the worker to read the existing files before modifying:
  - `Core/Models/Order.swift` — understand existing payment types
  - `Core/Networking/APIEndpoints.swift` — understand endpoint pattern (path, method, queryItems)
  - `Features/Staff/Orders/OrderDetailViewModel.swift` — understand existing published properties and method patterns
  - `Core/Services/` directory — check if `PaymentService` would be the first service file or if there's a pattern to follow

**4. Verification Steps** ⚠️ REQUIRED
- Build the project in Xcode — zero warnings
- Run the app on simulator, open any order detail — verify it still loads correctly (no regression)
- Set a breakpoint or add a temporary print in `loadPosConfig()` — verify it's called during order load
- Verify all new types conform to `Sendable` (no concurrency warnings)

**5. Parallel Stage Check** ⚠️ NEW
- After Stage 1 is complete, Stages 2, 3, and 4 can run in parallel
- The worker should confirm that the foundation is solid enough for all three:
  - `ManualPaymentRequest` is available for Stage 2 and Stage 4
  - All POS models are available for Stage 3
  - `PaymentService` methods cover all needs of Stages 2-4
  - `OrderDetailViewModel` payment methods are ready for all sheets to call

**6. Completion Checklist**
- [ ] `PosModels.swift` created with all types
- [ ] `ManualPaymentRequest` and `DevicePaymentBreakdown` added to `Order.swift`
- [ ] 9 new endpoint cases in `APIEndpoints.swift` with paths, methods, queryItems
- [ ] `PaymentService.swift` created with 10 methods
- [ ] `OrderDetailViewModel` extended with payment state + 5 methods
- [ ] `loadPosConfig()` and `loadPaymentLinks()` called during order load
- [ ] App builds with zero warnings
- [ ] Existing order detail loads without regression
- [ ] All types are `Sendable`-conformant

### Format
Output your worker prompt in a code block so it can be copied directly. Keep it brief — the spec documents contain the detail.
```
