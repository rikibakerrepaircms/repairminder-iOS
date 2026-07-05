# iOS Quick-Quote "Auto-detect from ticket" — Design

**Date:** 2026-07-05
**Status:** Approved design, pre-implementation
**Scope:** iOS/iPadOS/macOS (shared `WorkflowExecutionSheet`). No backend changes.

## Problem

When staff reply to a customer enquiry with a quote, the **web** app offers an
"Auto-detect from ticket" button (a.k.a. "auto analyse"). It reads the enquiry
text, matches the company's service catalog via an AI job, and either:

- pre-fills the `device_type` / `repair_type` / `price` fields, or
- when the catalog has multiple quality tiers, jumps straight to the preview
  step with a **fully AI-composed** multi-option quote email.

The **iOS** app already has the surrounding two-step macro flow
(variables → editable preview → send) but is **missing this auto-detect
button entirely**. The goal is to add it to iOS so the quote experience
matches web.

## Current State (verified by reading source)

### Web — `src/components/tickets/MacroExecutionModal.tsx`
- `handleAutoDetect` (lines 73–118) calls
  `ticketLLMSettingsService.suggestQuoteVariables(ticketId, macroId)`.
- The blue callout with the button renders on the variables step only when
  `hasQuoteVars` is true (lines 429–452).
- `previewSourcedByAi` flag (line 71) prevents the entry preview-fetch from
  overwriting an AI-composed body (lines 130–134); it is reset when the user
  edits variables again (line 173).

### Web backend (already generic, no changes needed)
- `POST /api/tickets/:id/macro/suggest-quote` starts an async Durable-Object
  job (`kind='suggest_quote'`); `GET` on the same path polls it.
- Job envelope: `{ status: 'idle'|'running'|'done'|'error', result?, error? }`,
  returned inside the standard `{ success, data }` API wrapper.
- Result shape (`ticket_llm_engine.js:861-866`):
  ```
  {
    suggestion:     { device_type, repair_type, price, product_name, sku, confidence } | null,
    composed_email: { subject, body } | null,
    matches:        [ { sku, name, price } ],
    reason:         string   // e.g. 'no_service_catalog', 'no_match'
  }
  ```

### iOS — `Features/Staff/Enquiries/EnquiryDetailView.swift`
- `WorkflowExecutionSheet` (lines 785–1004) already implements
  variables → preview → send, editable subject/body, SMS toggle, and calls
  `/macro/preview` and `/macro`.
- **No** auto-detect button, **no** suggest-quote endpoint, **no**
  `previewSourcedByAi` flag.
- Existing AI features (`generateAIResponse`, `rewriteResponse` in the view
  model) already POST-start + poll a job via `pollAIJob`, and surface a
  friendly "no provider key" message via `friendlyAIError`. We reuse both
  patterns.

## Design

Mirror web's `handleAutoDetect` into the existing `WorkflowExecutionSheet`.
No new screens. Four files change.

### 1. `Core/Networking/APIEndpoints.swift`
Add two cases, both mapping to `/api/tickets/{id}/macro/suggest-quote`
(the same start/poll shape as `ticketGenerateResponse` / `…Status`):
- `case ticketSuggestQuote(id: String)` — **POST**, body `{ macro_id }`
- `case ticketSuggestQuoteStatus(id: String)` — **GET**

Register the POST case in the method allow-list (where
`ticketExecuteMacro` / `ticketPreviewMacro` are listed).

### 2. `Core/Models/Macro.swift` (or a small new model file)
Codable structs matching the backend result **exactly** (snake_case handled by
`.convertFromSnakeCase`; do not add explicit CodingKeys):
- `SuggestQuoteRequest { macroId: String }` — Encodable (→ `macro_id`)
- `QuoteSuggestion { deviceType, repairType, price, productName, sku, confidence }`
  — all `String?` (price is a String in the API)
- `ComposedEmail { subject: String, body: String }`
- `QuoteMatch { sku: String?, name: String?, price: String? }`
- `QuoteSuggestionResult { suggestion: QuoteSuggestion?, composedEmail: ComposedEmail?, matches: [QuoteMatch]?, reason: String? }`
- `SuggestQuoteJobStatus { status: String, result: QuoteSuggestionResult? }`
  (parallel to the existing `AIJobStatus`; reuse `AIJobStart` for the POST
  start response since it only decodes `status`).

### 3. `Features/Staff/Enquiries/EnquiryDetailViewModel.swift`
- `@Published var isSuggestingQuote = false`
- `func suggestQuote(for macro: Macro) async -> QuoteSuggestionResult?`
  - POST `.ticketSuggestQuote(id:)` with `SuggestQuoteRequest(macroId:)`
  - poll `.ticketSuggestQuoteStatus(id:)` until `status == "done"`, reusing the
    `pollAIJob` timing/retry logic (generalised to this result type — either a
    typed copy `pollQuoteJob` or a small generic poll helper)
  - on `APIError` route through `friendlyAIError` so a missing provider key
    shows the existing friendly hint; set `error` and return `nil` on failure.

### 4. `WorkflowExecutionSheet` in `EnquiryDetailView.swift`
- Add `private var hasQuoteVars: Bool` — true when `usedPerUseVariables`
  contains any of `device_type` / `repair_type` / `price`.
- Add `@State private var previewSourcedByAi = false` and
  `@State private var suggestNote: String?`.
- In `variablesStep`, when `hasQuoteVars`, render a callout Section:
  a button "Auto-detect from ticket" (SF Symbol `sparkles`; while running show
  a `ProgressView` and "Matching catalog…"), a one-line explainer, and
  `suggestNote` below. Disable the button while `viewModel.isSuggestingQuote`.
- Handler (mirrors web `handleAutoDetect`):
  1. `composedEmail` present **and** `macro.isEmailMacro` → set
     `previewSubject`/`previewContent`, set `previewSourcedByAi = true`,
     set note ("Composed with N catalog options. Review and send." / "Composed
     from catalog. Review and send."), then `step = .preview`.
  2. else `suggestion` present → set `variableValues` for
     `device_type`/`repair_type`/`price`, clear those validation errors,
     note "Filled from catalog (<product>) · <confidence> confidence. Edit if
     needed."
  3. else → note: `reason == "no_service_catalog"` → "No service catalog set up
     for this company — fill in manually."; otherwise "Could not match this
     enquiry to a product — fill in manually."
- Guard the preview fetch so an AI-composed body is not overwritten:
  - `onChange(of: step)` and `onAppear` fetch only when `!previewSourcedByAi`.
  - Set `previewSourcedByAi = true` **before** assigning `step = .preview` in
    case 1 (so `onChange` sees it).
  - In the "Preview" button action (variables → preview), set
    `previewSourcedByAi = false` first (matches web line 173) so a manual edit
    re-renders the plain template.

## Error Handling
- Suggest-quote failure (network, timeout, DO error): show `viewModel.error`
  (already surfaced) via `suggestNote`; the user can still fill fields manually.
- Missing provider key (HTTP 400 mentioning "provider key"): surface the
  existing `providerKeyHint` string through `friendlyAIError` — the button stays
  enabled (matches iOS `generate`/`rewrite` behaviour; we do **not** add a
  readiness probe).
- Preview and send paths are unchanged and already handle their own errors.

## Non-Goals (YAGNI)
- No readiness pre-check endpoint (iOS handles it reactively).
- No changes to the free-text composer (auto-detect is quote-macro only).
- No backend changes, no new fields, no schema changes.
- Not surfacing the `matches[]` list in the UI beyond the count in the note
  (web doesn't either).

## Cross-Project Sync
- **Consumes an existing endpoint only.** No new backend fields/endpoints; no
  breaking changes; no auth/push/portal impact.
- Shared model + shared `WorkflowExecutionSheet` → change affects **iPhone,
  iPad, and Mac**. All APIs used (`Form`, `Section`, `Button`, `sparkles`,
  `ProgressView`) are cross-platform SwiftUI.
- **Verification must build the `Repair Minder Mac` scheme too** — an iOS-sim
  build passes while a macOS break is hidden.

## Testing / Verification
- Unit-decodable: `QuoteSuggestionResult` decodes a sample backend payload
  (suggestion path, composed_email path, no_match/no_service_catalog paths).
- Build both `Repair Minder` (iOS sim) and `Repair Minder Mac` (macOS) schemes.
- Manual/XCUITest against a demo account: open a quote macro on an enquiry, tap
  Auto-detect, confirm (a) fields fill or (b) it jumps to a composed preview,
  and that editing variables then re-previewing shows the plain render.
