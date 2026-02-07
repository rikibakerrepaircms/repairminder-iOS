//
//  DeviceType.swift
//  Repair Minder
//

import Foundation

struct DeviceType: Identifiable, Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let slug: String?
    let isSystem: Bool?
    let deviceCount: Int?
    let sortOrder: Int?

    private enum CodingKeys: String, CodingKey {
        case id, name, slug, isSystem, deviceCount, sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        deviceCount = try container.decodeIfPresent(Int.self, forKey: .deviceCount)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder)

        // Handle Bool-or-Int from SQLite
        if let boolVal = try? container.decodeIfPresent(Bool.self, forKey: .isSystem) {
            isSystem = boolVal
        } else if let intVal = try? container.decodeIfPresent(Int.self, forKey: .isSystem) {
            isSystem = intVal != 0
        } else {
            isSystem = nil
        }
    }

    // Keep manual init for sample data
    init(id: String, name: String, slug: String?, isSystem: Bool?, deviceCount: Int?, sortOrder: Int?) {
        self.id = id
        self.name = name
        self.slug = slug
        self.isSystem = isSystem
        self.deviceCount = deviceCount
        self.sortOrder = sortOrder
    }

    var systemImage: String {
        switch slug {
        case "phone", "mobile": return "iphone"
        case "tablet", "ipad": return "ipad"
        case "laptop", "macbook": return "laptopcomputer"
        case "desktop", "imac": return "desktopcomputer"
        case "watch", "smartwatch": return "applewatch"
        case "console", "gaming": return "gamecontroller.fill"
        case "repair": return "wrench.and.screwdriver"
        case "buyback": return "arrow.triangle.2.circlepath"
        default: return "cpu"
        }
    }
}

extension DeviceType {
    static var sample: DeviceType {
        DeviceType(id: "type-1", name: "Phone", slug: "phone", isSystem: true, deviceCount: 5, sortOrder: 1)
    }

    static var sampleList: [DeviceType] {
        [
            DeviceType(id: "type-1", name: "Phone", slug: "phone", isSystem: true, deviceCount: 5, sortOrder: 1),
            DeviceType(id: "type-2", name: "Tablet", slug: "tablet", isSystem: true, deviceCount: 3, sortOrder: 2),
            DeviceType(id: "type-3", name: "Laptop", slug: "laptop", isSystem: true, deviceCount: 2, sortOrder: 3),
            DeviceType(id: "type-4", name: "Desktop", slug: "desktop", isSystem: true, deviceCount: 1, sortOrder: 4)
        ]
    }
}
