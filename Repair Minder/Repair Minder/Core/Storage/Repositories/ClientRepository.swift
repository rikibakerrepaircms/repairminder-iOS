//
//  ClientRepository.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import CoreData
import Combine

@MainActor
final class ClientRepository: ObservableObject {
    @Published private(set) var clients: [Client] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: String?

    private let coreData = CoreDataStack.shared
    private let syncEngine = SyncEngine.shared

    // MARK: - Fetch

    func fetchClients(search: String? = nil) async {
        isLoading = true
        error = nil

        loadFromCache(search: search)

        if NetworkMonitor.shared.isConnected {
            await syncEngine.sync(.clients)
            loadFromCache(search: search)
        }

        isLoading = false
    }

    func fetchClient(id: String) async -> Client? {
        if let cached = clients.first(where: { $0.id == id }) {
            return cached
        }

        let request = CDClient.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)

        if let entity = try? coreData.viewContext.fetch(request).first {
            return Client(from: entity)
        }

        if NetworkMonitor.shared.isConnected {
            do {
                let client: Client = try await APIClient.shared.request(
                    .client(id: id),
                    responseType: Client.self
                )
                return client
            } catch {
                self.error = error.localizedDescription
            }
        }

        return nil
    }

    func searchClients(_ query: String) async {
        isLoading = true
        error = nil

        // Search locally first
        loadFromCache(search: query)

        // Also search via API if online
        if NetworkMonitor.shared.isConnected {
            do {
                let results: [Client] = try await APIClient.shared.request(
                    .clients(page: 1, limit: 50, search: query),
                    responseType: [Client].self
                )

                // Upsert results to cache
                let context = coreData.newBackgroundContext()
                await context.perform {
                    for client in results {
                        let request = CDClient.fetchRequest()
                        request.predicate = NSPredicate(format: "id == %@", client.id)

                        let existing = try? context.fetch(request).first
                        let entity = existing ?? CDClient(context: context)

                        entity.id = client.id
                        entity.email = client.email
                        entity.firstName = client.firstName
                        entity.lastName = client.lastName
                        entity.phone = client.phone
                        entity.company = client.company
                        entity.address = client.address
                        entity.city = client.city
                        entity.postcode = client.postcode
                        entity.notes = client.notes
                        entity.orderCount = Int32(client.orderCount)
                        entity.totalSpent = client.totalSpent as NSDecimalNumber
                        entity.createdAt = client.createdAt
                        entity.updatedAt = client.updatedAt
                        entity.syncedAt = Date()
                    }
                    try? context.save()
                }

                // Reload from cache with search
                loadFromCache(search: query)
            } catch {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    func fetchRecentClients(limit: Int = 20) async {
        isLoading = true
        error = nil

        loadRecentFromCache(limit: limit)

        if NetworkMonitor.shared.isConnected {
            await syncEngine.sync(.clients)
            loadRecentFromCache(limit: limit)
        }

        isLoading = false
    }

    // MARK: - Private

    private func loadFromCache(search: String?) {
        let request = CDClient.fetchRequest()

        if let search = search, !search.isEmpty {
            request.predicate = NSPredicate(
                format: "firstName CONTAINS[cd] %@ OR lastName CONTAINS[cd] %@ OR email CONTAINS[cd] %@ OR phone CONTAINS[cd] %@",
                search, search, search, search
            )
        }

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDClient.createdAt, ascending: false)
        ]

        do {
            let entities = try coreData.viewContext.fetch(request)
            clients = entities.map { Client(from: $0) }
        } catch {
            self.error = "Failed to load clients"
        }
    }

    private func loadRecentFromCache(limit: Int) {
        let request = CDClient.fetchRequest()
        request.fetchLimit = limit
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDClient.updatedAt, ascending: false)
        ]

        do {
            let entities = try coreData.viewContext.fetch(request)
            clients = entities.map { Client(from: $0) }
        } catch {
            self.error = "Failed to load clients"
        }
    }
}
