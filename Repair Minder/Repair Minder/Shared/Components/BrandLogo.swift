//
//  BrandLogo.swift
//  Repair Minder
//
//  Brand logo view component for white-label support
//

import SwiftUI

struct BrandLogo: View {
    enum Size {
        case small
        case medium
        case large
        case custom(CGFloat)

        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 60
            case .large: return 100
            case .custom(let size): return size
            }
        }
    }

    let size: Size
    var showFallbackIcon: Bool = true

    @Environment(\.brandColors) private var colors

    var body: some View {
        Group {
            if BrandAssets.current.hasCustomLogo {
                BrandAssets.current.logoImage
                    .resizable()
                    .scaledToFit()
            } else if showFallbackIcon {
                // Fallback to system icon with brand color
                Image(systemName: "wrench.and.screwdriver.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(colors.primary)
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .accessibilityLabel(BrandConfiguration.current.displayName)
    }
}

// MARK: - Preview

#Preview("Brand Logo Sizes") {
    VStack(spacing: 24) {
        BrandLogo(size: .small)
        BrandLogo(size: .medium)
        BrandLogo(size: .large)
        BrandLogo(size: .custom(150))
    }
    .padding()
}
