import SwiftUI
import Lottie

/// Branded loading animation using the RM robot mascot.
/// Drop-in replacement for ProgressView() at prominent loading points.
struct LottieLoadingView: View {
    var size: CGFloat = 120
    var message: String?

    var body: some View {
        VStack(spacing: 12) {
            LottieView(animation: .named("repairminder-loading"))
                .playbackMode(.playing(.toProgress(1, loopMode: .loop)))
                .frame(width: size, height: size)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
