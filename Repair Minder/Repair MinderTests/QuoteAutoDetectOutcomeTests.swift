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
