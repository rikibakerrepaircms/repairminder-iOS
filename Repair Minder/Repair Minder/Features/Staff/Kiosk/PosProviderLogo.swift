import SwiftUI

/// White brand mark for a POS provider, mirroring the inline SVGs the web kiosk
/// renders on the branded Card button and terminal rows. Uses vector asset
/// imagesets (`provider_<name>`) rendered as template images; falls back to an
/// SF Symbol for any provider we don't have a mark for.
struct PosProviderLogo: View {
    let provider: String
    var height: CGFloat = 18

    var body: some View {
        switch provider.lowercased() {
        case "revolut", "square", "sumup":
            // Square glyphs — constrain both dimensions.
            logo("provider_\(provider.lowercased())")
                .frame(width: height, height: height)
        case "dojo":
            // Wordmark — let width follow the aspect ratio.
            logo("provider_dojo")
                .frame(height: height)
        default:
            Image(systemName: "creditcard.fill")
        }
    }

    private func logo(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
    }
}
