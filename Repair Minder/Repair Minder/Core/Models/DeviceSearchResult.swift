//
//  DeviceSearchResult.swift
//  Repair Minder
//

import Foundation

/// Response from GET /api/device-search?q=<query>
/// Returns matching brands and models in a single response
struct DeviceSearchResponse: Decodable, Sendable {
    let brands: [DeviceSearchBrand]
    let models: [DeviceSearchModel]
}

/// A brand returned from the device search endpoint
struct DeviceSearchBrand: Identifiable, Decodable, Equatable, Sendable, Hashable {
    let id: String
    let name: String
    let category: String?
}

/// A model returned from the device search endpoint
struct DeviceSearchModel: Identifiable, Decodable, Equatable, Sendable, Hashable {
    let id: String
    let brandId: String
    let brandName: String?
    let name: String
    let displayName: String?

    /// Full display name with brand
    var fullDisplayName: String {
        displayName ?? (brandName.map { "\($0) \(name)" } ?? name)
    }
}

extension DeviceSearchResponse {
    static var sample: DeviceSearchResponse {
        DeviceSearchResponse(
            brands: [
                DeviceSearchBrand(id: "brand-1", name: "Apple", category: "phone"),
                DeviceSearchBrand(id: "brand-2", name: "Samsung", category: "phone"),
            ],
            models: [
                DeviceSearchModel(id: "model-1", brandId: "brand-1", brandName: "Apple", name: "iPhone 14 Pro", displayName: "Apple iPhone 14 Pro"),
                DeviceSearchModel(id: "model-2", brandId: "brand-1", brandName: "Apple", name: "iPhone 15", displayName: "Apple iPhone 15"),
            ]
        )
    }
}
