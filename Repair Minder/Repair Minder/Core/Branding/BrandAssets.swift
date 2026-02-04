//
//  BrandAssets.swift
//  Repair Minder
//
//  Logo and image management for white-label branding
//

import SwiftUI

struct BrandAssets: Sendable {
    let logoImageName: String
    let logoImageSmallName: String
    let splashBackground: Color

    // MARK: - Current Brand Assets (Singleton)

    static let current: BrandAssets = {
        let brandId = BrandConfiguration.current.id
        return BrandAssets(
            logoImageName: "\(brandId)_logo",
            logoImageSmallName: "\(brandId)_logo_small",
            splashBackground: BrandConfiguration.current.colors.primary
        )
    }()

    // MARK: - Image Accessors

    var logoImage: Image {
        // Try to load brand-specific image, fall back to system icon
        if let _ = UIImage(named: logoImageName) {
            return Image(logoImageName, bundle: .main)
        } else {
            return Image(systemName: "wrench.and.screwdriver.fill")
        }
    }

    var logoImageSmall: Image {
        if let _ = UIImage(named: logoImageSmallName) {
            return Image(logoImageSmallName, bundle: .main)
        } else {
            return Image(systemName: "wrench.and.screwdriver.fill")
        }
    }

    /// Check if custom logo assets exist
    var hasCustomLogo: Bool {
        UIImage(named: logoImageName) != nil
    }
}
