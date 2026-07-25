import SwiftUI

/// Transient "Connected to <shop>" confirmation, shown when this device is
/// recognised / paired to a shop (via the Bridge USB handshake). Presented as a
/// global top overlay so it appears regardless of the current screen. State is
/// cross-platform; only the iOS handshake ever triggers it.
@MainActor
final class ShopPairingBanner: ObservableObject {
    static let shared = ShopPairingBanner()

    /// Non-nil while the banner is visible.
    @Published var message: String?

    private var hideTask: Task<Void, Never>?

    /// Show the banner for ~3.5s. An empty/nil `shopName` falls back to a generic
    /// confirmation (the shop name arrives from the backend on the first run either way).
    func show(shopName: String?) {
        let name = (shopName?.isEmpty == false) ? shopName : nil
        message = name.map { "Connected to \($0)" } ?? "Shop connected"
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            self?.message = nil
        }
    }
}

/// Green pill that slides in from the top when a shop is recognised.
struct ShopConnectedBanner: View {
    @ObservedObject private var banner = ShopPairingBanner.shared

    var body: some View {
        VStack {
            if let msg = banner.message {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(msg)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(Capsule().fill(Color.green))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: banner.message)
    }
}
