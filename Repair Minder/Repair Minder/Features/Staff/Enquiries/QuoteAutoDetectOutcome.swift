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
