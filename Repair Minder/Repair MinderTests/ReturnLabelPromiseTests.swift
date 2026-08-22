//
//  ReturnLabelPromiseTests.swift
//  Repair MinderTests
//

import Testing
import Foundation

/// WE DO NOT SEND A LABEL, AND PRESSING THE BUTTON DOES NOT GET ONE.
///
/// `POST /api/customer/enquiries/:id/return-label` stages a PENDING row in
/// `label_requests` and returns 202 with `data: null`. A human approves it, and
/// approval is what mints. Nothing is sent, and the customer cannot make it happen.
/// What this app said until 2026-08-22:
///
///   button   "Send me a postage label"
///   postal   "Your label is usually ready and waiting here the moment you order.
///             This one did not come through, which is on us - press below and we
///             will get it now."
///   walk-in  "We can send you a free, pre-paid Royal Mail label instead"
///   doorstep "we can send you a free, pre-paid Royal Mail label instead and cancel
///             the collection"
///
/// Every line is wrong. The label is not ready at order time, it waits for review.
/// Nothing "did not come through" - nothing was due. We do not send one; it appears
/// in the portal to print. And nothing in the label path touches `collection_slot_*`,
/// so a doorstep customer who believed that last line cancels nothing and waits in
/// for a van that is still coming.
///
/// The web twin is `src/lib/labelPromises.test.ts` in the repairminder repo, and the
/// storefront's is `src/lib/labelInstructions.test.ts`. All three exist because this
/// copy has drifted apart across surfaces twice already: the storefront kept claiming
/// Royal Mail print the label for months after the app stopped, and the app kept
/// promising to send one after the storefront stopped.
///
/// Scans the shipped source rather than rendering the view, because the failure mode
/// is a sentence, not a state - and a sentence can be reintroduced anywhere.
struct ReturnLabelPromiseTests {

    /// The customer-facing sources this guard covers, resolved from this file's own
    /// path so it keeps working wherever the checkout lives.
    private static var customerSources: [URL] {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let root = testsDir.deletingLastPathComponent()          // "Repair Minder" (project dir)
        let customer = root
            .appendingPathComponent("Repair Minder")
            .appendingPathComponent("Features")
            .appendingPathComponent("Customer")
        guard let e = FileManager.default.enumerator(at: customer,
                                                     includingPropertiesForKeys: nil) else { return [] }
        return e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    @Test("the guard actually reaches the customer sources")
    func findsTheSources() throws {
        let files = Self.customerSources
        #expect(files.count > 5)
        #expect(files.contains { $0.lastPathComponent == "CustomerReturnLabelStep.swift" })
    }

    @Test("never promises to send a label, mint one on the spot, or cancel a collection")
    func makesNoPromiseWeCannotKeep() throws {
        // Each pattern is a claim the code cannot honour. The comments quoting the old
        // wording are excluded by scanning only string literals, below.
        let falseClaims: [(needle: String, why: String)] = [
            ("we can send you a free", "we do not send a label - it is published to the portal to print"),
            ("we will send you a", "we do not send a label - it is published to the portal to print"),
            ("ready and waiting here the moment you order", "a postal label is staged for review, not minted"),
            ("press below and we will get it now", "pressing the button stages a request for a human"),
            ("instead and cancel the collection", "nothing in the label path touches collection_slot_*"),
            ("Send me a postage label", "the button stages a request; it sends nothing"),
            ("Send me a new label", "the button stages a request; it sends nothing"),
        ]

        var offenders: [String] = []
        for url in Self.customerSources {
            let source = try String(contentsOf: url, encoding: .utf8)
            for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
                // Comments are allowed to quote the old wording - that is how the next
                // person learns why it went. Only shipped strings are policed.
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("///") { continue }
                guard line.contains("\"") else { continue }
                for claim in falseClaims where line.lowercased().contains(claim.needle.lowercased()) {
                    offenders.append("\(url.lastPathComponent): \(claim.why) - \(trimmed)")
                }
            }
        }

        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }
}
