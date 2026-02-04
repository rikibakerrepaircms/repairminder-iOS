//
//  SyncMetadata.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import CoreData

struct SyncMetadata: Equatable, Sendable {
    let trackedEntityName: String
    let lastSyncedAt: Date?
    let lastSyncCursor: String?
    let syncStatus: SyncStatus
    let errorMessage: String?

    var needsSync: Bool {
        guard let lastSynced = lastSyncedAt else { return true }
        // Consider data stale after 5 minutes
        return Date().timeIntervalSince(lastSynced) > 300
    }

    var isStale: Bool {
        guard let lastSynced = lastSyncedAt else { return true }
        // Consider data stale after 1 hour
        return Date().timeIntervalSince(lastSynced) > 3600
    }
}

enum SyncStatus: String, Codable, Sendable {
    case idle
    case syncing
    case error

    var displayName: String {
        switch self {
        case .idle: return "Up to date"
        case .syncing: return "Syncing..."
        case .error: return "Sync failed"
        }
    }
}

// MARK: - Tracked Entity Types
enum SyncableEntity: String, CaseIterable, Sendable {
    case orders = "CDOrder"
    case devices = "CDDevice"
    case clients = "CDClient"
    case tickets = "CDTicket"
    case ticketMessages = "CDTicketMessage"

    var displayName: String {
        switch self {
        case .orders: return "Orders"
        case .devices: return "Devices"
        case .clients: return "Clients"
        case .tickets: return "Tickets"
        case .ticketMessages: return "Messages"
        }
    }
}

// MARK: - Core Data Conversion
extension SyncMetadata {
    @MainActor
    init(from entity: CDSyncMetadata) {
        self.trackedEntityName = entity.trackedEntityName ?? ""
        self.lastSyncedAt = entity.lastSyncedAt
        self.lastSyncCursor = entity.lastSyncCursor
        self.syncStatus = SyncStatus(rawValue: entity.syncStatus ?? "") ?? .idle
        self.errorMessage = entity.errorMessage
    }

    @MainActor
    func toEntity(in context: NSManagedObjectContext) -> CDSyncMetadata {
        let entity = CDSyncMetadata(context: context)
        entity.trackedEntityName = trackedEntityName
        entity.lastSyncedAt = lastSyncedAt
        entity.lastSyncCursor = lastSyncCursor
        entity.syncStatus = syncStatus.rawValue
        entity.errorMessage = errorMessage
        return entity
    }

    @MainActor
    static func updateOrCreate(
        for trackedEntityName: String,
        in context: NSManagedObjectContext,
        update: (CDSyncMetadata) -> Void
    ) throws {
        let request = NSFetchRequest<CDSyncMetadata>(entityName: "CDSyncMetadata")
        request.predicate = NSPredicate(format: "trackedEntityName == %@", trackedEntityName)
        request.fetchLimit = 1

        let entity: CDSyncMetadata
        if let existing = try context.fetch(request).first {
            entity = existing
        } else {
            entity = CDSyncMetadata(context: context)
            entity.trackedEntityName = trackedEntityName
            entity.syncStatus = SyncStatus.idle.rawValue
        }

        update(entity)
    }
}
