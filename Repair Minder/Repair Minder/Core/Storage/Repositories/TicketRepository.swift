//
//  TicketRepository.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import CoreData
import Combine

@MainActor
final class TicketRepository: ObservableObject {
    @Published private(set) var tickets: [Ticket] = []
    @Published private(set) var messages: [TicketMessage] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: String?

    private let coreData = CoreDataStack.shared
    private let syncEngine = SyncEngine.shared

    // MARK: - Fetch Tickets

    func fetchTickets(status: TicketStatus? = nil) async {
        isLoading = true
        error = nil

        loadTicketsFromCache(status: status)

        if NetworkMonitor.shared.isConnected {
            await syncEngine.sync(.tickets)
            loadTicketsFromCache(status: status)
        }

        isLoading = false
    }

    func fetchTicket(id: String) async -> Ticket? {
        if let cached = tickets.first(where: { $0.id == id }) {
            return cached
        }

        let request = CDTicket.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)

        if let entity = try? coreData.viewContext.fetch(request).first {
            return Ticket(from: entity)
        }

        if NetworkMonitor.shared.isConnected {
            do {
                let ticket: Ticket = try await APIClient.shared.request(
                    .ticket(id: id),
                    responseType: Ticket.self
                )
                return ticket
            } catch {
                self.error = error.localizedDescription
            }
        }

        return nil
    }

    func fetchOpenTickets() async {
        await fetchTickets(status: .open)
    }

    func fetchPendingTickets() async {
        await fetchTickets(status: .pending)
    }

    // MARK: - Fetch Messages

    func fetchMessages(forTicketId ticketId: String) async {
        isLoading = true
        error = nil

        loadMessagesFromCache(ticketId: ticketId)

        if NetworkMonitor.shared.isConnected {
            do {
                let fetchedMessages: [TicketMessage] = try await APIClient.shared.request(
                    .ticketMessages(id: ticketId),
                    responseType: [TicketMessage].self
                )

                // Save to Core Data
                let context = coreData.newBackgroundContext()
                await context.perform {
                    for message in fetchedMessages {
                        let request = CDTicketMessage.fetchRequest()
                        request.predicate = NSPredicate(format: "id == %@", message.id)

                        let existing = try? context.fetch(request).first
                        let entity = existing ?? CDTicketMessage(context: context)

                        entity.id = message.id
                        entity.ticketId = message.ticketId
                        entity.content = message.content
                        entity.senderType = message.senderType.rawValue
                        entity.senderName = message.senderName
                        entity.senderId = message.senderId
                        entity.isInternal = message.isInternal
                        entity.createdAt = message.createdAt
                        entity.syncedAt = Date()
                        entity.needsSync = false
                    }
                    try? context.save()
                }

                loadMessagesFromCache(ticketId: ticketId)
            } catch {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - Send Message

    func sendMessage(ticketId: String, content: String, isInternal: Bool = false) async throws {
        let context = coreData.newBackgroundContext()
        let messageId = UUID().uuidString

        // Create local message
        try await context.perform {
            let entity = CDTicketMessage(context: context)
            entity.id = messageId
            entity.ticketId = ticketId
            entity.content = content
            entity.senderType = SenderType.staff.rawValue
            entity.senderName = nil // Will be set by API
            entity.senderId = nil
            entity.isInternal = isInternal
            entity.createdAt = Date()
            entity.needsSync = true
            entity.syncedAt = nil

            try context.save()
        }

        // Queue for sync
        syncEngine.queueChange(.ticketMessageCreated(id: messageId))

        // Reload messages
        loadMessagesFromCache(ticketId: ticketId)

        // Try to push immediately if online
        if NetworkMonitor.shared.isConnected {
            try await syncEngine.pushLocalChanges()
            // Refresh from server to get proper message data
            await fetchMessages(forTicketId: ticketId)
        }
    }

    // MARK: - Private

    private func loadTicketsFromCache(status: TicketStatus?) {
        let request = CDTicket.fetchRequest()

        if let status = status {
            request.predicate = NSPredicate(format: "status == %@", status.rawValue)
        }

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDTicket.lastMessageAt, ascending: false),
            NSSortDescriptor(keyPath: \CDTicket.createdAt, ascending: false)
        ]

        do {
            let entities = try coreData.viewContext.fetch(request)
            tickets = entities.map { Ticket(from: $0) }
        } catch {
            self.error = "Failed to load tickets"
        }
    }

    private func loadMessagesFromCache(ticketId: String) {
        let request = CDTicketMessage.fetchRequest()
        request.predicate = NSPredicate(format: "ticketId == %@", ticketId)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDTicketMessage.createdAt, ascending: true)
        ]

        do {
            let entities = try coreData.viewContext.fetch(request)
            messages = entities.map { TicketMessage(from: $0) }
        } catch {
            self.error = "Failed to load messages"
        }
    }
}
