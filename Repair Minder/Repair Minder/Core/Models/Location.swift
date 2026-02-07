//
//  Location.swift
//  Repair Minder
//

import Foundation

/// Full location model for booking (extends the simpler LocationOption in DeviceQueueItem.swift)
/// Uses Decodable only — locations are read-only from GET /api/locations
struct Location: Identifiable, Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let county: String?
    let postcode: String?
    let countryCode: String?
    let phone: String?
    let email: String?
    let isPrimary: Bool?
    let latitude: Double?
    let longitude: Double?
    let phoneCountryCode: String?
    let websiteUrl: String?

    var fullAddress: String {
        [addressLine1, city, postcode]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

extension Location {
    static var sample: Location {
        Location(
            id: "loc-1",
            name: "Main Store",
            addressLine1: "123 High Street",
            addressLine2: nil,
            city: "London",
            county: "Greater London",
            postcode: "SW1A 1AA",
            countryCode: "GB",
            phone: "020 1234 5678",
            email: "store@example.com",
            isPrimary: true,
            latitude: 51.5074,
            longitude: -0.1278,
            phoneCountryCode: "GB",
            websiteUrl: nil
        )
    }
}
