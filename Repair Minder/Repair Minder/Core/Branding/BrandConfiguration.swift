//
//  BrandConfiguration.swift
//  Repair Minder
//
//  Runtime brand settings loader for white-label support
//

import Foundation
import SwiftUI

struct BrandConfiguration: Sendable {
    let id: String
    let displayName: String
    let apiBaseURL: URL
    let supportEmail: String
    let supportURL: URL?
    let termsURL: URL?
    let privacyURL: URL?
    let colors: BrandColors
    let companyName: String
    let companyLocation: String

    // MARK: - Current Brand (Singleton)

    static let current: BrandConfiguration = {
        // Brand is determined at compile time via Swift Active Compilation Conditions
        // Each brand configuration sets BRAND_REPAIRMINDER or BRAND_CLIENTA etc.
        #if BRAND_CLIENTA
        return loadBrand(id: "clienta")
        #else
        return loadBrand(id: "repairminder")
        #endif
    }()

    // MARK: - Brand Loading

    private static func loadBrand(id: String) -> BrandConfiguration {
        switch id {
        case "repairminder":
            return BrandConfiguration(
                id: "repairminder",
                displayName: "Repair Minder",
                apiBaseURL: URL(string: "https://api.repairminder.com")!,
                supportEmail: "support@repairminder.com",
                supportURL: URL(string: "https://repairminder.com/help"),
                termsURL: URL(string: "https://repairminder.com/terms"),
                privacyURL: URL(string: "https://repairminder.com/privacy"),
                colors: .repairMinder,
                companyName: "mendmyi Limited",
                companyLocation: "London, UK"
            )
        case "clienta":
            return BrandConfiguration(
                id: "clienta",
                displayName: "ClientA Repairs",
                apiBaseURL: URL(string: "https://clienta.api.repairminder.com")!,
                supportEmail: "support@clienta.com",
                supportURL: URL(string: "https://clienta.com/help"),
                termsURL: URL(string: "https://clienta.com/terms"),
                privacyURL: URL(string: "https://clienta.com/privacy"),
                colors: .clientA,
                companyName: "ClientA Inc.",
                companyLocation: "New York, USA"
            )
        default:
            // Fall back to default brand for unknown brand IDs
            return BrandConfiguration(
                id: "repairminder",
                displayName: "Repair Minder",
                apiBaseURL: URL(string: "https://api.repairminder.com")!,
                supportEmail: "support@repairminder.com",
                supportURL: URL(string: "https://repairminder.com/help"),
                termsURL: URL(string: "https://repairminder.com/terms"),
                privacyURL: URL(string: "https://repairminder.com/privacy"),
                colors: .repairMinder,
                companyName: "mendmyi Limited",
                companyLocation: "London, UK"
            )
        }
    }
}

// MARK: - Environment Key

struct BrandConfigurationKey: EnvironmentKey {
    static let defaultValue = BrandConfiguration.current
}

extension EnvironmentValues {
    var brandConfiguration: BrandConfiguration {
        get { self[BrandConfigurationKey.self] }
        set { self[BrandConfigurationKey.self] = newValue }
    }
}
