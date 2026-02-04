//
//  Client.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import CoreData

struct Client: Identifiable, Equatable, Sendable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let phone: String?
    let company: String?
    let address: String?
    let city: String?
    let postcode: String?
    let notes: String?
    let orderCount: Int
    let totalSpent: Decimal
    let createdAt: Date
    let updatedAt: Date

    var fullName: String {
        [firstName, lastName].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " ")
    }

    var displayName: String {
        if !fullName.isEmpty {
            return fullName
        }
        return email
    }

    var initials: String {
        if let first = firstName?.first, let last = lastName?.first {
            return "\(first)\(last)".uppercased()
        }
        return String(email.prefix(2)).uppercased()
    }
}

// MARK: - Codable
extension Client: Codable {
    enum CodingKeys: String, CodingKey {
        case id, email, phone, company, address, city, postcode, notes
        case firstName, lastName, orderCount, totalSpent
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        company = try container.decodeIfPresent(String.self, forKey: .company)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        postcode = try container.decodeIfPresent(String.self, forKey: .postcode)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        orderCount = try container.decodeIfPresent(Int.self, forKey: .orderCount) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // Handle Decimal decoding from String or Double
        if let totalString = try? container.decode(String.self, forKey: .totalSpent) {
            totalSpent = Decimal(string: totalString) ?? 0
        } else if let totalDouble = try? container.decode(Double.self, forKey: .totalSpent) {
            totalSpent = Decimal(totalDouble)
        } else {
            totalSpent = 0
        }
    }
}

// MARK: - Core Data Conversion
extension Client {
    @MainActor
    init(from entity: CDClient) {
        self.id = entity.id ?? ""
        self.email = entity.email ?? ""
        self.firstName = entity.firstName
        self.lastName = entity.lastName
        self.phone = entity.phone
        self.company = entity.company
        self.address = entity.address
        self.city = entity.city
        self.postcode = entity.postcode
        self.notes = entity.notes
        self.orderCount = Int(entity.orderCount)
        self.totalSpent = entity.totalSpent as Decimal? ?? 0
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
    }

    @MainActor
    func toEntity(in context: NSManagedObjectContext) -> CDClient {
        let entity = CDClient(context: context)
        entity.id = id
        entity.email = email
        entity.firstName = firstName
        entity.lastName = lastName
        entity.phone = phone
        entity.company = company
        entity.address = address
        entity.city = city
        entity.postcode = postcode
        entity.notes = notes
        entity.orderCount = Int32(orderCount)
        entity.totalSpent = totalSpent as NSDecimalNumber
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        entity.syncedAt = Date()
        return entity
    }
}

// MARK: - CDClient Extension
extension CDClient {
    var fullName: String? {
        let name = [firstName, lastName].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " ")
        return name.isEmpty ? nil : name
    }
}
