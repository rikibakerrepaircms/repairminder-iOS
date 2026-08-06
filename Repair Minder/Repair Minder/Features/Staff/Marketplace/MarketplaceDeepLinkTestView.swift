//
//  MarketplaceDeepLinkTestView.swift
//  Repair Minder
//
//  DEBUG-only scratch pad for manually comparing candidate "open the actual
//  Marketplace item" deep-link strategies on a real device with the Facebook
//  app installed. None of these can be validated in the simulator -- see
//  Settings > About > Marketplace Deep Link Test (DEBUG builds only).
//
//  Paste a real listing URL (e.g. https://www.facebook.com/marketplace/item/1234567890/)
//  and tap each candidate to see which one actually lands on the item screen
//  vs. the app's home/feed vs. Safari.
//

#if DEBUG
import SwiftUI

struct MarketplaceDeepLinkTestView: View {
    @State private var listingURLString = ""

    private var listingURL: URL? {
        let trimmed = listingURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        return url
    }

    /// Best-effort numeric item id parsed out of a
    /// `.../marketplace/item/<id>/` URL, for the id-based candidates below.
    private var listingID: String? {
        guard let listingURL else { return nil }
        let parts = listingURL.pathComponents
        if let idx = parts.firstIndex(of: "item"), idx + 1 < parts.count {
            return parts[idx + 1]
        }
        return nil
    }

    var body: some View {
        Form {
            Section {
                TextField("https://www.facebook.com/marketplace/item/…", text: $listingURLString)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .autocorrectionDisabled()
            } header: {
                Text("Listing URL")
            } footer: {
                Text("Paste a real marketplace listing URL from the app or a listing notification, then try each candidate below on a device with Facebook installed.")
            }

            Section("Candidates") {
                candidateRow(
                    title: "A. Plain https URL (current fix)",
                    detail: "UIApplication.shared.open(listingURL) — no fb:// wrapping. Currently shipped in platformOpenMarketplaceListing.",
                    action: { url in platformOpenURL(url) }
                )

                candidateRow(
                    title: "B. fb://facewebmodal/f?href=… (old behavior)",
                    detail: "Generic in-app web-view wrapper. Known from the bug report to land somewhere generic, kept here for side-by-side comparison.",
                    action: { url in openFacewebmodal(url) }
                )

                candidateRow(
                    title: "C. m.facebook.com mobile URL",
                    detail: "Same item path on the mobile subdomain instead of www — untested whether Facebook's own smart-banner JS handles this differently.",
                    action: { url in openMobileDomain(url) }
                )

                candidateRow(
                    title: "D. l.facebook.com link-shim redirect",
                    detail: "Routes through Facebook's own l.php redirector — speculative, no confirmation this changes native-app routing behavior.",
                    action: { url in openLinkShim(url) }
                )

                idBasedCandidateRow(
                    title: "E. fb://marketplace_product_details?listing_id=…",
                    detail: "Unconfirmed guessed scheme — no public documentation found for this or any per-item Marketplace fb:// scheme.",
                    scheme: "fb", host: "marketplace_product_details", paramName: "listing_id"
                )

                idBasedCandidateRow(
                    title: "F. fb://marketplace?listing_id=…",
                    detail: "Another unconfirmed guess at a shorter form of the same idea.",
                    scheme: "fb", host: "marketplace", paramName: "listing_id"
                )
            }

            Section {
                Text("Report back which letter (if any) actually opened the specific listing screen in the Facebook app, vs. the app's home feed, vs. Safari, vs. did nothing (canOpenURL false / no handler).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Marketplace Deep Link Test")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func candidateRow(title: String, detail: String, action: @escaping (URL) -> Void) -> some View {
        Button {
            if let listingURL { action(listingURL) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .disabled(listingURL == nil)
    }

    @ViewBuilder
    private func idBasedCandidateRow(title: String, detail: String, scheme: String, host: String, paramName: String) -> some View {
        Button {
            guard let listingID else { return }
            var components = URLComponents()
            components.scheme = scheme
            components.host = host
            components.queryItems = [URLQueryItem(name: paramName, value: listingID)]
            if let url = components.url {
                platformOpenURL(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .disabled(listingID == nil)
    }

    private func openFacewebmodal(_ listingURL: URL) {
        var components = URLComponents()
        components.scheme = "fb"
        components.host = "facewebmodal"
        components.path = "/f"
        components.queryItems = [URLQueryItem(name: "href", value: listingURL.absoluteString)]
        if let url = components.url {
            platformOpenURL(url)
        }
    }

    private func openMobileDomain(_ listingURL: URL) {
        guard var components = URLComponents(url: listingURL, resolvingAgainstBaseURL: false) else { return }
        components.host = "m.facebook.com"
        if let url = components.url {
            platformOpenURL(url)
        }
    }

    private func openLinkShim(_ listingURL: URL) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "l.facebook.com"
        components.path = "/l.php"
        components.queryItems = [URLQueryItem(name: "u", value: listingURL.absoluteString)]
        if let url = components.url {
            platformOpenURL(url)
        }
    }
}

#Preview {
    NavigationStack {
        MarketplaceDeepLinkTestView()
    }
}
#endif
