//
//  EnquiryDetailViewModel.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import Combine

@MainActor
final class EnquiryDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var enquiry: Enquiry?
    @Published var messages: [EnquiryMessage] = []
    @Published var isLoading = true
    @Published var isSending = false
    @Published var isGeneratingAI = false
    @Published var isExecutingWorkflow = false
    @Published var workflows: [Workflow] = []
    @Published var error: Error?

    // MARK: - Properties
    let enquiryId: String

    // MARK: - Reply Templates
    let replyTemplates: [ReplyTemplate] = [
        ReplyTemplate(
            id: "greeting",
            name: "Greeting",
            content: "Thank you for contacting us! We've received your enquiry and will get back to you shortly."
        ),
        ReplyTemplate(
            id: "info_needed",
            name: "More Info",
            content: "Thank you for your enquiry. To better assist you, could you please provide more details about the issue you're experiencing?"
        ),
        ReplyTemplate(
            id: "quote",
            name: "Quote",
            content: "Based on the information provided, we estimate the repair will cost approximately £XX.XX. Would you like to proceed with booking?"
        ),
        ReplyTemplate(
            id: "booking",
            name: "Book In",
            content: "Great! We can book your device in for repair. Please bring it to our shop at your earliest convenience, or let us know a preferred date/time."
        )
    ]

    // MARK: - Initialization
    init(enquiryId: String) {
        self.enquiryId = enquiryId
    }

    // MARK: - Public Methods
    func load() async {
        isLoading = true
        error = nil

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadEnquiry() }
            group.addTask { await self.loadMessages() }
            group.addTask { await self.loadWorkflows() }
        }

        isLoading = false
    }

    func loadEnquiry() async {
        do {
            let endpoint = APIEndpoint.enquiry(id: enquiryId)
            enquiry = try await APIClient.shared.request(
                endpoint,
                responseType: Enquiry.self
            )
        } catch {
            self.error = error
        }
    }

    func loadMessages() async {
        do {
            let endpoint = APIEndpoint.enquiryMessages(id: enquiryId)
            messages = try await APIClient.shared.request(
                endpoint,
                responseType: [EnquiryMessage].self
            )
        } catch {
            // Messages might not exist yet, that's okay
            messages = []
        }
    }

    func loadWorkflows() async {
        do {
            struct WorkflowsResponse: Decodable {
                let macros: [Workflow]
            }
            let endpoint = APIEndpoint.workflows(includeStages: true)
            let response: WorkflowsResponse = try await APIClient.shared.request(
                endpoint,
                responseType: WorkflowsResponse.self
            )
            workflows = response.macros.filter { $0.isActive }
        } catch {
            // Non-critical, workflows are optional
            workflows = []
        }
    }

    /// Generate an AI reply for this enquiry
    func generateAIReply() async -> String? {
        isGeneratingAI = true
        defer { isGeneratingAI = false }

        do {
            let endpoint = APIEndpoint.generateEnquiryReply(id: enquiryId)
            let response: AIReplyResponse = try await APIClient.shared.request(
                endpoint,
                responseType: AIReplyResponse.self
            )
            return response.text
        } catch {
            self.error = error
            return nil
        }
    }

    /// Execute a workflow on this enquiry
    func executeWorkflow(_ workflow: Workflow, variableOverrides: [String: String]? = nil) async -> Bool {
        isExecutingWorkflow = true
        defer { isExecutingWorkflow = false }

        do {
            let endpoint = APIEndpoint.executeEnquiryWorkflow(
                enquiryId: enquiryId,
                workflowId: workflow.id,
                variableOverrides: variableOverrides
            )
            try await APIClient.shared.requestVoid(endpoint)
            // Reload messages and enquiry to show executed workflow
            await loadMessages()
            await loadEnquiry()
            return true
        } catch {
            self.error = error
            return false
        }
    }

    func markAsRead() {
        Task {
            do {
                let endpoint = APIEndpoint.markEnquiryRead(id: enquiryId)
                try await APIClient.shared.requestVoid(endpoint)
            } catch {
                // Non-critical, silently fail
            }
        }
    }

    func sendReply(_ content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSending = true

        do {
            let endpoint = APIEndpoint.sendEnquiryReply(id: enquiryId, message: content)
            let newMessage: EnquiryMessage = try await APIClient.shared.request(
                endpoint,
                responseType: EnquiryMessage.self
            )
            messages.append(newMessage)

            // Reload enquiry to get updated status
            await loadEnquiry()
        } catch {
            self.error = error
            // Reload messages to sync state
            await loadMessages()
        }

        isSending = false
    }

    func markAsSpam() async {
        do {
            let endpoint = APIEndpoint.markEnquirySpam(id: enquiryId)
            try await APIClient.shared.requestVoid(endpoint)
            await loadEnquiry()
        } catch {
            self.error = error
        }
    }

    func archive() async {
        do {
            let endpoint = APIEndpoint.archiveEnquiry(id: enquiryId)
            try await APIClient.shared.requestVoid(endpoint)
            await loadEnquiry()
        } catch {
            self.error = error
        }
    }

    func convertToOrder(_ data: ConvertOrderData) async {
        do {
            let endpoint = APIEndpoint.convertEnquiryToOrder(id: enquiryId, body: data)
            try await APIClient.shared.requestVoid(endpoint)
            await loadEnquiry()
        } catch {
            self.error = error
        }
    }
}

// MARK: - Reply Template
struct ReplyTemplate: Identifiable {
    let id: String
    let name: String
    let content: String
}

// MARK: - Convert Order Data
struct ConvertOrderData: Codable {
    let enquiryId: String
    let services: [String]
    let estimatedPrice: Decimal?
    let priority: String
    let assignedTechnician: String?
    let notes: String

    init(
        enquiryId: String,
        services: [String],
        estimatedPrice: Decimal?,
        priority: OrderPriority,
        assignedTechnician: String?,
        notes: String
    ) {
        self.enquiryId = enquiryId
        self.services = services
        self.estimatedPrice = estimatedPrice
        self.priority = priority.rawValue
        self.assignedTechnician = assignedTechnician
        self.notes = notes
    }
}

// MARK: - Order Priority
enum OrderPriority: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
}
