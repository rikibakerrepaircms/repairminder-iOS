//
//  Environment.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import Foundation

enum AppEnvironment {
    case development
    case staging
    case production

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    /// API base URL - uses brand-specific URL from BrandConfiguration
    var apiBaseURL: URL {
        // Use brand-specific API URL
        let brandURL = BrandConfiguration.current.apiBaseURL

        switch self {
        case .development:
            // In development, use the brand URL
            return brandURL
        case .staging:
            // For staging, modify the brand URL to use staging subdomain
            let brandId = BrandConfiguration.current.id
            if brandId == "repairminder" {
                return URL(string: "https://api-staging.repairminder.com")!
            }
            return brandURL
        case .production:
            return brandURL
        }
    }

    /// App display name - uses brand-specific name from BrandConfiguration
    var appName: String {
        return BrandConfiguration.current.displayName
    }
}
