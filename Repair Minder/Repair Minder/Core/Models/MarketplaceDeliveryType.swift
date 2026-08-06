//
//  MarketplaceDeliveryType.swift
//  Repair Minder
//
//  listing.deliveryType is Facebook's raw enum values, comma-joined (e.g.
//  "IN_PERSON, DOOR_PICKUP") -- mirrors src/utils/marketplaceDeliveryType.ts
//  on the web dashboard exactly, including the known-value table. An
//  unrecognized value falls back to being shown as-is (not dropped/blanked)
//  since Facebook can add new enum values without warning.
//

import Foundation

enum MarketplaceDeliveryType {
    private static let labels: [String: String] = [
        "IN_PERSON": "In person",
        "PUBLIC_MEETUP": "Public meetup",
        "DOOR_PICKUP": "Doorstep pickup",
        "DOOR_DROPOFF": "Doorstep drop-off",
        "SHIPPING_OFFSITE": "Shipping",
    ]

    static func format(_ deliveryType: String?) -> String? {
        guard let deliveryType, !deliveryType.isEmpty else { return nil }
        let formatted = deliveryType
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { labels[$0] ?? $0 }
        return formatted.isEmpty ? nil : formatted.joined(separator: ", ")
    }
}
