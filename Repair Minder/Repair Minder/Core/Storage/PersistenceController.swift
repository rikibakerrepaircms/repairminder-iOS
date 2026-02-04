//
//  PersistenceController.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import CoreData

struct PersistenceController: Sendable {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    @MainActor
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "RepairMinder")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // Preview helper with sample data
    @MainActor
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.viewContext

        // Sample orders
        let statuses = ["booked_in", "in_progress", "awaiting_parts", "ready", "collected"]
        for i in 1...5 {
            let order = CDOrder(context: context)
            order.id = UUID().uuidString
            order.orderNumber = Int32(1000 + i)
            order.status = statuses[i % statuses.count]
            order.total = NSDecimalNumber(value: Double.random(in: 50...500))
            order.deposit = NSDecimalNumber(value: Double.random(in: 0...100))
            order.balance = NSDecimalNumber(value: Double.random(in: 0...400))
            order.clientId = UUID().uuidString
            order.createdAt = Date().addingTimeInterval(-Double(i * 86400))
            order.updatedAt = Date()
            order.needsSync = false

            // Add a device for each order
            let device = CDDevice(context: context)
            device.id = UUID().uuidString
            device.orderId = order.id!
            device.type = ["iPhone", "iPad", "MacBook", "iMac", "Apple Watch"][i % 5]
            device.brand = "Apple"
            device.model = "Pro \(i)"
            device.status = statuses[i % statuses.count]
            device.issue = "Screen not working"
            device.createdAt = Date()
            device.updatedAt = Date()
            device.needsSync = false
            device.order = order
        }

        // Sample clients
        for i in 1...3 {
            let client = CDClient(context: context)
            client.id = UUID().uuidString
            client.email = "client\(i)@example.com"
            client.firstName = "John"
            client.lastName = "Doe \(i)"
            client.phone = "+44 7700 90000\(i)"
            client.orderCount = Int32(i)
            client.totalSpent = NSDecimalNumber(value: Double(i) * 150.0)
            client.createdAt = Date()
            client.updatedAt = Date()
        }

        // Sample tickets
        let ticketStatuses = ["open", "pending", "closed"]
        for i in 1...3 {
            let ticket = CDTicket(context: context)
            ticket.id = UUID().uuidString
            ticket.ticketNumber = Int32(100 + i)
            ticket.subject = "Question about order #100\(i)"
            ticket.status = ticketStatuses[i % ticketStatuses.count]
            ticket.clientEmail = "client\(i)@example.com"
            ticket.clientName = "John Doe \(i)"
            ticket.createdAt = Date().addingTimeInterval(-Double(i * 3600))
            ticket.updatedAt = Date()

            // Add a message to each ticket
            let message = CDTicketMessage(context: context)
            message.id = UUID().uuidString
            message.ticketId = ticket.id!
            message.content = "Hi, I have a question about my order."
            message.senderType = "client"
            message.senderName = "John Doe \(i)"
            message.isInternal = false
            message.createdAt = Date()
            message.needsSync = false
            message.ticket = ticket
        }

        try? context.save()
        return controller
    }()
}
