import SwiftUI

/// Async product image for the kiosk catalog. Loads `GET /api/product-types/{id}/image`
/// as raw bytes, caches the decoded image per product id, and falls back to a
/// `shippingbox` placeholder when there is no image or the load fails.
struct KioskProductImage: View {
    let productId: String
    let primaryImageId: String?
    var contentMode: ContentMode = .fill

    @State private var loaded: Image?
    @State private var didAttempt = false

    var body: some View {
        ZStack {
            if let loaded {
                loaded.resizable().aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: "shippingbox")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        }
        .task(id: productId) { await load() }
    }

    private func load() async {
        guard primaryImageId != nil, !didAttempt else { return }
        didAttempt = true
        if let cached = KioskImageCache.shared.image(for: productId) {
            loaded = cached
            return
        }
        do {
            let data = try await APIClient.shared.requestRawData(.productTypeImage(id: productId))
            #if canImport(UIKit)
            if let ui = UIImage(data: data) {
                let img = Image(uiImage: ui)
                KioskImageCache.shared.set(img, for: productId)
                loaded = img
            }
            #elseif canImport(AppKit)
            if let ns = NSImage(data: data) {
                let img = Image(nsImage: ns)
                KioskImageCache.shared.set(img, for: productId)
                loaded = img
            }
            #endif
        } catch {
            // Keep the placeholder on failure.
        }
    }
}

/// In-memory cache of decoded catalog images keyed by product id.
final class KioskImageCache {
    static let shared = KioskImageCache()
    private var store: [String: Image] = [:]
    func image(for key: String) -> Image? { store[key] }
    func set(_ image: Image, for key: String) { store[key] = image }
}
