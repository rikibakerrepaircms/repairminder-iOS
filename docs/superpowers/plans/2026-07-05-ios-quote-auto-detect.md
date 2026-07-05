# iOS Quick-Quote "Auto-detect from ticket" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add web's "Auto-detect from ticket" (AI quote suggestion) button to the iOS/iPadOS/macOS enquiry quote-macro flow, so it either pre-fills device/repair/price or jumps straight to a fully AI-composed quote preview — matching the web app.

**Architecture:** Pure client-side addition consuming the existing generic backend job `POST/GET /api/tickets/:id/macro/suggest-quote` (a Durable-Object async job returning `{ suggestion, composed_email, matches, reason }`). New Codable models + two endpoint cases + a view-model poll method + a callout button in the existing `WorkflowExecutionSheet`. The branch logic (composed-email vs field-fill vs manual) is extracted into a pure, unit-tested function so the SwiftUI view stays thin.

**Tech Stack:** Swift, SwiftUI, `swift-testing` (`import Testing`) + XCTest, `xcodebuild`. Shared code across iPhone/iPad/Mac targets.

**Spec:** `docs/superpowers/specs/2026-07-05-ios-quote-auto-detect-design.md`

**Repo root (all paths below are relative to this):** `/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS`

---

## Reference facts (verified against source — do not re-derive)

- Backend job envelope (what iOS `APIClient.request<T>` receives AFTER unwrapping `{success, data}`):
  - POST start → `data = { job_id, kind, status: "running", started_at }` (no `result`).
  - GET status when done → `data = { status: "done", kind, job_id, result: {...}, ... }`.
  - `result` shape: `{ suggestion: {device_type, repair_type, price, product_name, sku, confidence}|null, composed_email: {subject, body}|null, matches: [{sku,name,price}], reason: string }`.
  - `reason` values seen: `"no_service_catalog"`, `"no_match"`. A null `suggestion` with a `reason` is a SUCCESSFUL result, not an error.
- The iOS decoder uses `.convertFromSnakeCase` — so `composed_email` → `composedEmail`, `device_type` → `deviceType`. **Do NOT add explicit CodingKeys.**
- `Macro.id` is `String`; `Macro.isEmailMacro: Bool` exists (`Core/Models/Macro.swift:14,32`).
- `WorkflowExecutionSheet` already has `@State previewSubject/previewContent`, `Step.{variables,preview}`, `variableValues`, `usedPerUseVariables`, `fetchPreview()`, and `onChange(of: step)`/`onAppear` that call `fetchPreview()` (`Features/Staff/Enquiries/EnquiryDetailView.swift:785-1004`).
- Existing async-job pattern to mirror: `EnquiryDetailViewModel.pollAIJob` (`:313-329`), `AIJobStatus` (`Core/Models/TicketMessage.swift:415`), and `friendlyAIError`/`providerKeyHint` (`:335-349`).

---

## Task 0: Create feature branch

**Files:** none (git only)

- [ ] **Step 1: Branch off the current default branch**

```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS"
git checkout -b feature/ios-quote-auto-detect
```

Expected: `Switched to a new branch 'feature/ios-quote-auto-detect'`.

---

## Task 1: Add Codable models for the suggest-quote job

**Files:**
- Modify: `Repair Minder/Repair Minder/Core/Models/Macro.swift` (append at end of file)
- Test: `Repair Minder/Repair MinderTests/QuoteSuggestionDecodeTests.swift` (create)

- [ ] **Step 1: Write the failing decode test**

Create `Repair Minder/Repair MinderTests/QuoteSuggestionDecodeTests.swift`:

```swift
import Testing
import Foundation
@testable import Repair_Minder

struct QuoteSuggestionDecodeTests {
    // Decodes the `data` payload of a GET /macro/suggest-quote poll when done
    // with a field suggestion (snake_case → camelCase via the app decoder).
    @Test func decodesSuggestionResult() throws {
        let json = #"""
        {"status":"done","result":{
          "suggestion":{"device_type":"iPhone 14 Pro","repair_type":"Screen Replacement","price":"149.99","product_name":"iPhone 14 Pro Screen","sku":"SCR-14P","confidence":"high"},
          "composed_email":null,
          "matches":[{"sku":"SCR-14P","name":"iPhone 14 Pro Screen","price":"149.99"}],
          "reason":"match"}}
        """#
        let status = try RMDecode.decode(SuggestQuoteJobStatus.self, json)
        #expect(status.status == "done")
        #expect(status.result?.suggestion?.deviceType == "iPhone 14 Pro")
        #expect(status.result?.suggestion?.price == "149.99")
        #expect(status.result?.composedEmail == nil)
        #expect(status.result?.matches?.count == 1)
    }

    // Decodes a composed-email result (multi-tier quote).
    @Test func decodesComposedEmailResult() throws {
        let json = #"""
        {"status":"done","result":{
          "suggestion":null,
          "composed_email":{"subject":"Your repair quote","body":"Premium: £149\nAftermarket: £99"},
          "matches":[{"sku":"A","name":"Premium","price":"149"},{"sku":"B","name":"Aftermarket","price":"99"}],
          "reason":"match"}}
        """#
        let status = try RMDecode.decode(SuggestQuoteJobStatus.self, json)
        #expect(status.result?.composedEmail?.subject == "Your repair quote")
        #expect(status.result?.matches?.count == 2)
    }

    // Decodes the "no catalog" success result (suggestion null, reason set).
    @Test func decodesNoServiceCatalogResult() throws {
        let json = #"""
        {"status":"done","result":{"suggestion":null,"composed_email":null,"matches":[],"reason":"no_service_catalog"}}
        """#
        let status = try RMDecode.decode(SuggestQuoteJobStatus.self, json)
        #expect(status.result?.suggestion == nil)
        #expect(status.result?.reason == "no_service_catalog")
    }

    // Decodes the POST-start payload (running, no result).
    @Test func decodesRunningStart() throws {
        let json = #"{"job_id":"abc","kind":"suggest_quote","status":"running","started_at":"2026-07-05T00:00:00Z"}"#
        let status = try RMDecode.decode(SuggestQuoteJobStatus.self, json)
        #expect(status.status == "running")
        #expect(status.result == nil)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS"
xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:"Repair MinderTests/QuoteSuggestionDecodeTests" \
  -parallel-testing-enabled NO 2>&1 | tail -20
```

Expected: FAIL — compile error `cannot find 'SuggestQuoteJobStatus' in scope`.

- [ ] **Step 3: Add the models**

Append to `Repair Minder/Repair Minder/Core/Models/Macro.swift`:

```swift
// MARK: - Quick Quote auto-detect (AI suggest-quote job)

/// Request body for POST /api/tickets/:id/macro/suggest-quote
struct SuggestQuoteRequest: Encodable {
    let macroId: String   // encoded as macro_id
}

/// One catalog match returned alongside a suggestion.
struct QuoteMatch: Decodable, Sendable, Equatable {
    let sku: String?
    let name: String?
    let price: String?
}

/// A single-option field suggestion for the quote macro variables.
struct QuoteSuggestion: Decodable, Sendable, Equatable {
    let deviceType: String?
    let repairType: String?
    let price: String?
    let productName: String?
    let sku: String?
    let confidence: String?
}

/// A fully composed quote email (used when the catalog has multiple tiers).
struct ComposedEmail: Decodable, Sendable, Equatable {
    let subject: String
    let body: String
}

/// The `result` payload of a finished suggest-quote job.
struct QuoteSuggestionResult: Decodable, Sendable, Equatable {
    let suggestion: QuoteSuggestion?
    let composedEmail: ComposedEmail?
    let matches: [QuoteMatch]?
    let reason: String?
}

/// Start/poll response for the suggest-quote job (the unwrapped `data`).
/// Reused for both the POST start (result nil, status "running") and the GET
/// poll (status "done" carries the result).
struct SuggestQuoteJobStatus: Decodable, Sendable {
    let status: String            // idle | running | done | error
    let result: QuoteSuggestionResult?
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS"
xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:"Repair MinderTests/QuoteSuggestionDecodeTests" \
  -parallel-testing-enabled NO 2>&1 | tail -20
```

Expected: `Test Suite 'QuoteSuggestionDecodeTests' passed` — 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Core/Models/Macro.swift" "Repair Minder/Repair MinderTests/QuoteSuggestionDecodeTests.swift"
git commit -m "feat(ios): add suggest-quote job Codable models

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Add the two API endpoint cases

**Files:**
- Modify: `Repair Minder/Repair Minder/Core/Networking/APIEndpoints.swift` (enum ~`:160`, path switch ~`:569`, method lists ~`:806`/`:838`)
- Test: `Repair Minder/Repair MinderTests/SuggestQuoteEndpointTests.swift` (create)

- [ ] **Step 1: Write the failing endpoint test**

Create `Repair Minder/Repair MinderTests/SuggestQuoteEndpointTests.swift`:

```swift
import XCTest
@testable import Repair_Minder

/// The suggest-quote start (POST) and poll (GET) hit the SAME path; only the
/// HTTP method differs — mirroring the generate/rewrite job endpoints.
final class SuggestQuoteEndpointTests: XCTestCase {
    func testSuggestQuoteStartIsPost() {
        let ep = APIEndpoint.ticketSuggestQuote(id: "42")
        XCTAssertEqual(ep.path, "/api/tickets/42/macro/suggest-quote")
        XCTAssertEqual(ep.method, .post)
    }

    func testSuggestQuoteStatusIsGet() {
        let ep = APIEndpoint.ticketSuggestQuoteStatus(id: "42")
        XCTAssertEqual(ep.path, "/api/tickets/42/macro/suggest-quote")
        XCTAssertEqual(ep.method, .get)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS"
xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:"Repair MinderTests/SuggestQuoteEndpointTests" \
  -parallel-testing-enabled NO 2>&1 | tail -20
```

Expected: FAIL — `type 'APIEndpoint' has no member 'ticketSuggestQuote'`.

- [ ] **Step 3a: Add the enum cases**

In `APIEndpoints.swift`, after line 160 (`case ticketPreviewMacro(id: String)`), add:

```swift
    case ticketSuggestQuote(id: String)
    case ticketSuggestQuoteStatus(id: String)
```

- [ ] **Step 3b: Add the path mapping**

In the `var path: String` switch, after the `.ticketPreviewMacro` case (line 568-569), add:

```swift
        case .ticketSuggestQuote(let id):
            return "/api/tickets/\(id)/macro/suggest-quote"
        case .ticketSuggestQuoteStatus(let id):
            return "/api/tickets/\(id)/macro/suggest-quote"
```

- [ ] **Step 3c: Add to the GET method list**

In the `var method: HTTPMethod` switch, in the `.get` case list, add `.ticketSuggestQuoteStatus` next to `.ticketGenerateResponseStatus` (line 806):

```swift
             .ticketGenerateResponseStatus, .ticketRewriteResponseStatus, .ticketSuggestQuoteStatus,
```

- [ ] **Step 3d: Add to the POST method list**

In the `.post` case list, add `.ticketSuggestQuote` to the ticket line (line 838):

```swift
             .createTicket, .ticketReply, .ticketNote, .ticketGenerateResponse, .ticketRewriteResponse, .ticketExecuteMacro, .ticketPreviewMacro, .ticketSuggestQuote,
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS"
xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:"Repair MinderTests/SuggestQuoteEndpointTests" \
  -parallel-testing-enabled NO 2>&1 | tail -20
```

Expected: `SuggestQuoteEndpointTests passed` — 2 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Core/Networking/APIEndpoints.swift" "Repair Minder/Repair MinderTests/SuggestQuoteEndpointTests.swift"
git commit -m "feat(ios): add suggest-quote start/poll API endpoints

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Extract the auto-detect branch logic as a pure, tested function

This is the composed-email vs field-fill vs manual decision from web's `handleAutoDetect`, isolated so it is unit-testable and the SwiftUI view stays thin.

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Enquiries/QuoteAutoDetectOutcome.swift`
- Test: `Repair Minder/Repair MinderTests/QuoteAutoDetectOutcomeTests.swift` (create)

- [ ] **Step 1: Write the failing test**

Create `Repair Minder/Repair MinderTests/QuoteAutoDetectOutcomeTests.swift`:

```swift
import Testing
@testable import Repair_Minder

struct QuoteAutoDetectOutcomeTests {
    private func result(
        suggestion: QuoteSuggestion? = nil,
        composed: ComposedEmail? = nil,
        matches: [QuoteMatch]? = nil,
        reason: String? = nil
    ) -> QuoteSuggestionResult {
        QuoteSuggestionResult(suggestion: suggestion, composedEmail: composed, matches: matches, reason: reason)
    }

    @Test func composedEmailForEmailMacroJumpsToPreview() {
        let r = result(
            composed: ComposedEmail(subject: "Quote", body: "Body"),
            matches: [QuoteMatch(sku: "A", name: "Premium", price: "149"),
                      QuoteMatch(sku: "B", name: "Aftermarket", price: "99")]
        )
        let outcome = resolveQuoteAutoDetect(r, isEmailMacro: true)
        #expect(outcome == .composed(subject: "Quote", body: "Body",
                                     note: "Composed with 2 catalog options. Review and send."))
    }

    @Test func composedEmailSingleMatchNote() {
        let r = result(composed: ComposedEmail(subject: "Q", body: "B"),
                       matches: [QuoteMatch(sku: "A", name: "Premium", price: "149")])
        let outcome = resolveQuoteAutoDetect(r, isEmailMacro: true)
        #expect(outcome == .composed(subject: "Q", body: "B",
                                     note: "Composed from catalog. Review and send."))
    }

    @Test func composedEmailIgnoredForNoteMacroFallsToSuggestion() {
        // A note macro can't send email — a composed body is ignored; if there's
        // also no suggestion, we fall through to manual.
        let r = result(composed: ComposedEmail(subject: "Q", body: "B"), reason: "no_match")
        let outcome = resolveQuoteAutoDetect(r, isEmailMacro: false)
        #expect(outcome == .manual(note: "Could not match this enquiry to a product — fill in manually."))
    }

    @Test func suggestionFillsFields() {
        let r = result(suggestion: QuoteSuggestion(
            deviceType: "iPhone 14 Pro", repairType: "Screen Replacement", price: "149.99",
            productName: "iPhone 14 Pro Screen", sku: "SCR", confidence: "high"))
        let outcome = resolveQuoteAutoDetect(r, isEmailMacro: true)
        #expect(outcome == .filled(
            values: ["device_type": "iPhone 14 Pro", "repair_type": "Screen Replacement", "price": "149.99"],
            note: "Filled from catalog (iPhone 14 Pro Screen) · high confidence. Edit if needed."))
    }

    @Test func suggestionWithoutProductOrConfidence() {
        let r = result(suggestion: QuoteSuggestion(
            deviceType: "iPad", repairType: nil, price: "80",
            productName: nil, sku: nil, confidence: nil))
        let outcome = resolveQuoteAutoDetect(r, isEmailMacro: true)
        #expect(outcome == .filled(
            values: ["device_type": "iPad", "price": "80"],
            note: "Filled from catalog. Edit if needed."))
    }

    @Test func noServiceCatalogIsManual() {
        let outcome = resolveQuoteAutoDetect(result(reason: "no_service_catalog"), isEmailMacro: true)
        #expect(outcome == .manual(note: "No service catalog set up for this company — fill in manually."))
    }

    @Test func noMatchIsManual() {
        let outcome = resolveQuoteAutoDetect(result(reason: "no_match"), isEmailMacro: true)
        #expect(outcome == .manual(note: "Could not match this enquiry to a product — fill in manually."))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS"
xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:"Repair MinderTests/QuoteAutoDetectOutcomeTests" \
  -parallel-testing-enabled NO 2>&1 | tail -20
```

Expected: FAIL — `cannot find 'resolveQuoteAutoDetect' in scope`.

- [ ] **Step 3: Implement the pure function**

Create `Repair Minder/Repair Minder/Features/Staff/Enquiries/QuoteAutoDetectOutcome.swift`:

```swift
import Foundation

/// The three ways an auto-detect result is applied to the quote-macro sheet.
/// Mirrors the web app's handleAutoDetect branch logic (MacroExecutionModal.tsx).
enum QuoteAutoDetectOutcome: Equatable {
    /// A fully composed multi-tier email — jump straight to the editable preview.
    case composed(subject: String, body: String, note: String)
    /// A single-option field suggestion — pre-fill the per-use variables.
    case filled(values: [String: String], note: String)
    /// No usable suggestion — user fills in manually; `note` explains why.
    case manual(note: String)
}

/// Decide how to apply a suggest-quote result. Pure — no view state.
func resolveQuoteAutoDetect(_ result: QuoteSuggestionResult, isEmailMacro: Bool) -> QuoteAutoDetectOutcome {
    // Best path: LLM returned a fully composed body (only usable on an email macro).
    if let email = result.composedEmail, isEmailMacro {
        let count = result.matches?.count ?? 0
        let note = count > 1
            ? "Composed with \(count) catalog options. Review and send."
            : "Composed from catalog. Review and send."
        return .composed(subject: email.subject, body: email.body, note: note)
    }

    // Field suggestion path.
    guard let s = result.suggestion else {
        let note = result.reason == "no_service_catalog"
            ? "No service catalog set up for this company — fill in manually."
            : "Could not match this enquiry to a product — fill in manually."
        return .manual(note: note)
    }

    var values: [String: String] = [:]
    if let d = s.deviceType { values["device_type"] = d }
    if let r = s.repairType { values["repair_type"] = r }
    if let p = s.price { values["price"] = p }

    let label = s.productName.map { " (\($0))" } ?? ""
    let conf = s.confidence.map { " · \($0) confidence" } ?? ""
    return .filled(values: values, note: "Filled from catalog\(label)\(conf). Edit if needed.")
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS"
xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:"Repair MinderTests/QuoteAutoDetectOutcomeTests" \
  -parallel-testing-enabled NO 2>&1 | tail -20
```

Expected: `QuoteAutoDetectOutcomeTests passed` — 7 tests, 0 failures.

> **Note for the executor:** the new file must be added to the "Repair Minder" app target AND its symbols compiled into the test target via `@testable import`. If the project uses folder-synchronized groups (Xcode 16 `PBXFileSystemSynchronizedRootGroup`), the file is picked up automatically. If the build fails with "cannot find file in target", add it to the "Repair Minder" target membership in Xcode. It is shared code — confirm it is a member of both the iOS and the `Repair Minder Mac` targets (it uses only `Foundation`, so it is cross-platform safe).

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Enquiries/QuoteAutoDetectOutcome.swift" "Repair Minder/Repair MinderTests/QuoteAutoDetectOutcomeTests.swift"
git commit -m "feat(ios): add pure resolveQuoteAutoDetect branch logic

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Add the view-model suggest-quote method + poll

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Enquiries/EnquiryDetailViewModel.swift`
  - Add `@Published var isSuggestingQuote` near the other AI flags.
  - Add `suggestQuote(for:)` and `pollSuggestQuoteJob(_:)` after `rewriteResponse()` / `pollAIJob` (`:310`/`:329`).

- [ ] **Step 1: Add the published flag**

Find the AI state flags (near `isGeneratingAI` / `isRewritingAI`, declared with the other `@Published` properties) and add:

```swift
    @Published var isSuggestingQuote = false
```

- [ ] **Step 2: Add the suggest-quote method and its poller**

Insert after `pollAIJob(...)` (after line 329) in `EnquiryDetailViewModel.swift`:

```swift
    /// Quick Quote auto-detect: match the enquiry against the company's service
    /// catalog via the async suggest-quote job. Returns nil (and sets `error`)
    /// on failure so the caller can fall back to manual entry.
    func suggestQuote(for macro: Macro) async -> QuoteSuggestionResult? {
        guard !isSuggestingQuote else { return nil }
        isSuggestingQuote = true
        error = nil
        defer { isSuggestingQuote = false }

        do {
            let request = SuggestQuoteRequest(macroId: macro.id)
            let start: SuggestQuoteJobStatus = try await APIClient.shared.request(
                .ticketSuggestQuote(id: ticketId), body: request
            )
            // The job may already be done on POST (cached); otherwise poll.
            if start.status == "done", let result = start.result {
                return result
            }
            return try await pollSuggestQuoteJob(.ticketSuggestQuoteStatus(id: ticketId))
        } catch let apiError as APIError {
            error = friendlyAIError(apiError)
            return nil
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    /// Poll the suggest-quote job until done. Longer budget than pollAIJob — the
    /// catalog-match engine (reasoning-high) can run up to ~180s server-side.
    private func pollSuggestQuoteJob(_ endpoint: APIEndpoint) async throws -> QuoteSuggestionResult {
        let maxAttempts = 120           // ~240s
        for attempt in 0..<maxAttempts {
            try await Task.sleep(for: .milliseconds(attempt == 0 ? 1500 : 2000))
            let status: SuggestQuoteJobStatus = try await APIClient.shared.request(endpoint)
            switch status.status {
            case "done":
                if let result = status.result { return result }
                throw APIError.serverError(message: "Suggest-quote finished without a result", code: nil)
            case "error":
                throw APIError.serverError(message: "Auto-detect failed", code: nil)
            default:
                continue                // idle / running
            }
        }
        throw APIError.serverError(message: "Auto-detect timed out", code: nil)
    }
```

- [ ] **Step 3: Verify the view model compiles (build the test target)**

```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS"
xcodebuild build-for-testing -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Enquiries/EnquiryDetailViewModel.swift"
git commit -m "feat(ios): add suggestQuote job call + poll to enquiry view model

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Wire the Auto-detect button into WorkflowExecutionSheet

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Enquiries/EnquiryDetailView.swift` (`WorkflowExecutionSheet`, `:785-1004`)

This adds the button + note, the branch application, and the `previewSourcedByAi` guard so an AI-composed body is not overwritten by the plain template preview.

- [ ] **Step 1: Add state + computed helper**

In `WorkflowExecutionSheet`, next to the existing `@State` (after `previewError` at `:805`), add:

```swift
    @State private var previewSourcedByAi = false
    @State private var suggestNote: String?
    @State private var isAutoDetecting = false
```

And add this computed property near `usedPerUseVariables` (`:827`):

```swift
    /// True when the macro uses any quote variable — gates the Auto-detect UI.
    private var hasQuoteVars: Bool {
        usedPerUseVariables.contains { $0 == "device_type" || $0 == "repair_type" || $0 == "price" }
    }
```

- [ ] **Step 2: Add the auto-detect handler**

Add this method inside `WorkflowExecutionSheet` (near `fetchPreview()` at `:846`):

```swift
    private func runAutoDetect() {
        isAutoDetecting = true
        suggestNote = nil
        Task {
            defer { isAutoDetecting = false }
            guard let result = await viewModel.suggestQuote(for: macro) else {
                suggestNote = viewModel.error ?? "Auto-detect failed — fill in manually."
                return
            }
            switch resolveQuoteAutoDetect(result, isEmailMacro: macro.isEmailMacro) {
            case let .composed(subject, body, note):
                previewSubject = subject
                previewContent = body
                previewSourcedByAi = true       // set BEFORE step change so onChange skips fetch
                suggestNote = note
                withAnimation { step = .preview }
            case let .filled(values, note):
                for (key, value) in values {
                    variableValues[key] = value
                    validationErrors.remove(key)
                }
                suggestNote = note
            case let .manual(note):
                suggestNote = note
            }
        }
    }
```

- [ ] **Step 3: Render the callout in the variables step**

In `variablesStep` (`:944`), insert a new `Section` immediately before the `if !usedPerUseVariables.isEmpty` block (`:980`), shown only for quote macros:

```swift
            // Quick Quote auto-detect
            if hasQuoteVars {
                Section {
                    Button {
                        runAutoDetect()
                    } label: {
                        HStack(spacing: 8) {
                            if isAutoDetecting {
                                ProgressView()
                                Text("Matching catalog…")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Auto-detect from ticket")
                            }
                        }
                    }
                    .disabled(isAutoDetecting)

                    Text("Match this enquiry against your service catalog and pre-fill device, repair and price. You can still edit.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let note = suggestNote {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
```

- [ ] **Step 4: Guard the preview fetch against overwriting the AI body**

In `body`, update the `onChange(of: step)` handler (`:927-931`) and `onAppear` (`:932-938`) so they do not re-fetch when the body came from auto-detect:

Replace the `onChange(of: step)` block with:

```swift
            .onChange(of: step) { _, newStep in
                if newStep == .preview && macro.isEmailMacro && !previewSourcedByAi {
                    fetchPreview()
                }
            }
```

(The `onAppear` block is unaffected — `previewSourcedByAi` is always false on first appear — so leave it as-is.)

- [ ] **Step 5: Reset the AI-source flag when the user re-enters preview manually**

In the "Preview" confirmation button action (`:897-911`, the `else if macro.isEmailMacro` branch), set the flag false before advancing so a manual variable edit re-renders the plain template. Change the action body to:

```swift
                    } else if macro.isEmailMacro {
                        Button {
                            let missing = usedPerUseVariables.filter { (variableValues[$0] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
                            if !missing.isEmpty {
                                validationErrors = Set(missing)
                                return
                            }
                            previewSourcedByAi = false
                            withAnimation { step = .preview }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "eye")
                                Text("Preview")
                            }
                        }
                        .fontWeight(.semibold)
                    }
```

- [ ] **Step 6: Build the iOS target to verify it compiles**

```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS"
xcodebuild build-for-testing -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Enquiries/EnquiryDetailView.swift"
git commit -m "feat(ios): add Auto-detect from ticket button to quote macro sheet

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Full test + cross-platform build verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full unit-test suite (iOS)**

```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS"
xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:"Repair MinderTests" \
  -parallel-testing-enabled NO 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **`, including the 3 new test files (13 new tests), 0 failures.

- [ ] **Step 2: Build the macOS target (iOS-sim build hides macOS breaks)**

```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS"
xcodebuild build -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder Mac" \
  -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`. If it fails on a symbol from the new files, add them to the `Repair Minder Mac` target membership (they use only Foundation/SwiftUI and are cross-platform).

- [ ] **Step 3: Manual smoke test (demo account)**

Per memory `project_ios_runtime_testing_demo_account`: sign in as `appstore-demo@repairminder.com` (2FA `123456`), open an enquiry, tap the bolt/Run-Macro menu, pick a **quote** macro (one using `{{device_type}}`/`{{repair_type}}`/`{{price}}`). Confirm:
  1. The "Auto-detect from ticket" button appears on the variables step.
  2. Tapping it either (a) fills the fields with a "Filled from catalog…" note, or (b) jumps to the preview with a composed body and a "Composed with N catalog options…" note.
  3. From a composed preview, tapping "Back" then "Preview" re-renders the plain template (AI body is discarded).
  4. A company with no service catalog shows the "No service catalog…" note and manual entry still works.

- [ ] **Step 4: Final commit (if any manual-test fixups were needed)**

Only if changes were made:

```bash
git add -A
git commit -m "fix(ios): quote auto-detect smoke-test fixups

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Cross-Project Sync (MANDATORY gate — completed at plan time)

| Question | Answer |
|---|---|
| Consumes an API endpoint? | Yes — `POST/GET /api/tickets/:id/macro/suggest-quote`, **already exists** (`worker/src/ticket_llm_handlers.js:115`). Response shape verified against `ticket_llm_engine.js:861-866`. Swift models match exactly. |
| Needs a new field from the API? | No. |
| Needs a new endpoint? | No — the endpoint is already deployed and generic. |
| Changes auth / token handling? | No. |
| Affects push notifications? | No. |
| Affects the customer portal? | No. |
| Changes magic-link / deep links? | No. |
| Platform-specific? | No — shared `WorkflowExecutionSheet` + shared models affect **iPhone, iPad, and Mac**. All APIs used are cross-platform SwiftUI. Verified by building the `Repair Minder Mac` scheme (Task 6, Step 2). |

**Backend:** no changes required. **Deploy order:** N/A (backend already live). **Breaking:** No.

---

## Self-Review

- **Spec coverage:** endpoints (Task 2) ✅, models (Task 1) ✅, view-model poll + friendlyAIError gating (Task 4) ✅, callout button + three branches + `previewSourcedByAi` guard + manual-reset (Task 3 logic, Task 5 wiring) ✅, cross-platform build (Task 6) ✅. All spec sections map to a task.
- **Placeholder scan:** no TBD/TODO; every code step shows complete code.
- **Type consistency:** `QuoteSuggestionResult` / `QuoteSuggestion` / `ComposedEmail` / `QuoteMatch` / `SuggestQuoteJobStatus` / `SuggestQuoteRequest` used identically across Tasks 1, 3, 4. `resolveQuoteAutoDetect(_:isEmailMacro:)` and `QuoteAutoDetectOutcome` cases (`.composed`/`.filled`/`.manual`) match between Task 3 definition and Task 5 usage. Endpoint cases `.ticketSuggestQuote` / `.ticketSuggestQuoteStatus` consistent across Tasks 2 and 4.
