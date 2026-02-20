# CHECKING WORK PROMPT

```
CHECKING WORK

You are a technical project manager reviewing completed work.

---

## CONFIGURATION

**Master Plan Path:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder/plans/ios-order-payments/00-master-plan.md`
**Just Completed:** Stage 1

---

## Part 1: Review the Completed Stage

Verify the stage listed above was implemented correctly:

### Code Review
- Were the correct files created and modified?
- Does the implementation match the spec in the stage document?
- Any obvious bugs, edge cases missed, or Swift code quality issues?
- Do all types conform to `Sendable`? Any concurrency warnings?
- Are the `APIEndpoints` cases using the correct HTTP methods and paths?
- Does `PaymentService` use `apiClient.request<T>()` and `requestVoid()` correctly?
- Are the `OrderDetailViewModel` extensions consistent with the existing method patterns?

### Verification
- Does the app build with zero warnings?
- Does an existing order detail still load correctly (no regression)?
- Are `loadPosConfig()` and `loadPaymentLinks()` being called during order load?

### If you find issues:

**Fixable issues** (minor bugs, missing `Sendable` conformance, wrong HTTP method):
→ Fix them and note what you changed.

**Blocking issues** (wrong model shapes, missing required methods, broken order loading):
→ STOP and tell me what's wrong. Do NOT proceed to the next stage.

---

## 🚫 GATE: Do not proceed until the completed stage fully works.

---

## Part 2: Update Progress

Mark the completed stage as done in the Master Plan's Stage Index (add ✅ after the stage name).

---

## Part 3: Check for Parallel Stages

Read the Master Plan's stage dependency table. Identify which upcoming stages can run **in parallel**.

After Stage 1:
- **Stage 2** (Manual Payment Sheet) — depends only on Stage 1 ✅
- **Stage 3** (POS Card Payment + Links) — depends only on Stage 1 ✅
- **Stage 4** (Buyback Payout Sheet) — depends only on Stage 1 ✅

Confirm that the completed Stage 1 provides everything needed for ALL three parallel stages:
- Does `ManualPaymentRequest` exist for Stages 2 and 4?
- Do all POS models exist for Stage 3?
- Does `PaymentService` have all methods needed by Stages 2, 3, and 4?
- Does `OrderDetailViewModel` have `recordPayment()`, `deletePayment()`, `depositsEnabled`, `balanceDue`, `hasPosIntegrations`, `hasActiveTerminals`, `posTerminals`?

If anything is missing that would block a parallel stage, flag it as a blocking issue.

---

## Part 4: Create Next Stage Worker Prompts

Since Stages 2, 3, and 4 can run in parallel, generate **THREE separate worker prompts** — one for each stage.

Each prompt should follow this format:

**1. Task Overview**
- Which file(s) to create
- Reference to the specific stage spec document
- Note that this stage runs in parallel with the other two (no cross-dependencies)

**2. Scope Boundaries**
- What they SHOULD do (this stage only)
- What they should NOT do:
  - Do NOT modify `OrderDetailView.swift` (that's Stage 5)
  - Do NOT create files belonging to other parallel stages
  - Do NOT wire sheets into any view (Stage 5 handles all wiring)

**3. Reference Files** ⚠️ REQUIRED
- Point to the Stage 1 files they depend on:
  - `Core/Models/PosModels.swift` — POS types (Stage 3 especially)
  - `Core/Models/Order.swift` — `ManualPaymentRequest`, `OrderPayment`, etc.
  - `Core/Services/PaymentService.swift` — API methods they'll reference
  - `Features/Staff/Orders/OrderDetailViewModel.swift` — ViewModel methods the sheet will call via closures
  - `Features/Staff/Orders/OrderItemFormSheet.swift` — Reference for sheet patterns (NavigationStack, toolbar, form layout, `.presentationDetents`)

**4. Verification Steps** ⚠️ REQUIRED
- Build the project — zero warnings
- The sheet file should compile standalone
- Preview should render (at minimum the initial/default state)
- No `OrderDetailView` changes means no integration test yet — that's expected

**5. Completion Checklist**
- Stage-specific checklist items from the spec document

### Format
Output each worker prompt in its own code block with a clear heading (e.g., "## Stage 2 Worker Prompt", "## Stage 3 Worker Prompt", "## Stage 4 Worker Prompt") so they can be copied and run independently.

If any stage cannot proceed due to missing prerequisites, explain why and what needs to be fixed first.

---

### For Subsequent Reviews (Stages 2-4 → Stage 5)

When reviewing the completion of Stages 2, 3, and 4:

1. Verify ALL THREE parallel stages are complete before generating the Stage 5 prompt
2. Confirm each sheet compiles and its preview renders
3. Check that the `onSave` closure signatures match what `OrderDetailViewModel` provides
4. Check that init parameter types match what `OrderDetailView` can provide from the ViewModel
5. Only then generate the Stage 5 prompt (which wires everything together)

If only some parallel stages are complete, generate prompts for the remaining ones and wait.
```
