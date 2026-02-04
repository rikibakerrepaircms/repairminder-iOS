//
//  CoreDataStack.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import CoreData
import os.log

final class CoreDataStack: @unchecked Sendable {
    static let shared = CoreDataStack()

    private let logger = Logger(subsystem: "com.mendmyi.repairminder", category: "CoreData")

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "RepairMinder")

        // Configure for background sync
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        container.loadPersistentStores { [weak self] _, error in
            if let error = error as NSError? {
                self?.logger.error("Core Data error: \(error), \(error.userInfo)")
                fatalError("Core Data load failed: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                logger.error("Save failed: \(error.localizedDescription)")
            }
        }
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }

    // MARK: - Fetch Helpers

    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) throws -> [T] {
        try viewContext.fetch(request)
    }

    func fetchFirst<T: NSManagedObject>(_ request: NSFetchRequest<T>) throws -> T? {
        request.fetchLimit = 1
        return try fetch(request).first
    }

    // MARK: - Delete Helpers

    func deleteAll<T: NSManagedObject>(_ entityType: T.Type) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entityType))
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try persistentContainer.persistentStoreCoordinator.execute(deleteRequest, with: viewContext)
    }
}
