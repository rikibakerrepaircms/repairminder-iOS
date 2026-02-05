//
//  EnquiryDetailViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import SwiftUI

/// ViewModel for ticket detail view
@MainActor
final class EnquiryDetailViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var ticket: Ticket?
    @Published private(set) var macros: [Macro] = []
    @Published private(set) var activeExecutions: [MacroExecution] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published private(set) var isGeneratingAI = false
    @Published private(set) var error: String?
    @Published var aiGeneratedText: String?
    @Published var showingMacroPicker = false
    @Published var showingStatusPicker = false

    // MARK: - Reply State

    @Published var replyText = ""
    @Published var selectedReplyStatus: TicketStatus? = .pending
    @Published var replyMode: ReplyMode = .reply
    @Published var selectedWorkflowMacro: Macro?

    enum ReplyMode: String, CaseIterable {
        case reply = "Reply"
        case note = "Note"

        var icon: String {
            switch self {
            case .reply: return "paperplane"
            case .note: return "note.text"
            }
        }

        var placeholder: String {
            switch self {
            case .reply: return "Type your reply..."
            case .note: return "Type an internal note..."
            }
        }
    }

    // MARK: - Private Properties

    private let ticketId: String

    // MARK: - Initialization

    init(ticketId: String) {
        self.ticketId = ticketId
    }

    // MARK: - Computed Properties

    /// Messages sorted chronologically (oldest first)
    var sortedMessages: [TicketMessage] {
        ticket?.messages?.sorted { msg1, msg2 in
            guard let date1 = ISO8601DateFormatter().date(from: msg1.createdAt),
                  let date2 = ISO8601DateFormatter().date(from: msg2.createdAt) else {
                return msg1.createdAt < msg2.createdAt
            }
            return date1 < date2
        } ?? []
    }

    /// Whether can send a reply
    var canSendReply: Bool {
        ticket?.canReply == true && !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    /// Whether ticket is closed or merged
    var isTicketClosed: Bool {
        ticket?.status == .closed || ticket?.isMerged == true
    }

    /// Devices from the linked order (for note association)
    var orderDevices: [TicketOrderDevice] {
        ticket?.order?.devices ?? []
    }

    // MARK: - Loading

    /// Load ticket details (initial load, skips if already loading)
    func loadTicket() async {
        guard !isLoading else { return }
        await performLoad()
    }

    /// Refresh ticket (pull-to-refresh, always reloads)
    func refresh() async {
        await performLoad()
    }

    private func performLoad() async {
        isLoading = true
        error = nil

        do {
            try Task.checkCancellation()
            ticket = try await APIClient.shared.request(.ticket(id: ticketId))
            try Task.checkCancellation()
            await loadMacros()
            await loadExecutions()
        } catch is CancellationError {
            // Task was cancelled (e.g. view lifecycle), ignore
        } catch let urlError as URLError where urlError.code == .cancelled {
            // URL request cancelled, ignore
        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Load available macros
    func loadMacros() async {
        do {
            let response: MacroListResponse = try await APIClient.shared.request(
                .macros(category: nil, includeStages: true)
            )
            macros = response.macros.filter { $0.isEnabled }
        } catch is CancellationError { }
        catch let urlError as URLError where urlError.code == .cancelled { }
        catch {
            print("Failed to load macros: \(error)")
        }
    }

    /// Load active macro executions for this ticket
    func loadExecutions() async {
        do {
            let response: MacroExecutionListResponse = try await APIClient.shared.request(
                .ticketMacroExecutions(id: ticketId)
            )
            activeExecutions = response.executions.filter { $0.status.isModifiable }
        } catch is CancellationError { }
        catch let urlError as URLError where urlError.code == .cancelled { }
        catch {
            print("Failed to load executions: \(error)")
        }
    }

    // MARK: - Actions

    /// Send reply or note
    func sendMessage() async {
        guard canSendReply else { return }

        isSending = true
        error = nil

        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            switch replyMode {
            case .reply:
                // Convert plain text to simple HTML
                let htmlBody = "<div>\(text.replacingOccurrences(of: "\n", with: "<br>"))</div>"
                let request = TicketReplyRequest(
                    htmlBody: htmlBody,
                    textBody: text,
                    status: selectedReplyStatus?.rawValue,
                    fromCustomEmailId: nil,
                    pendingAttachmentIds: nil
                )
                let _: TicketReplyResponse = try await APIClient.shared.request(
                    .ticketReply(id: ticketId),
                    body: request
                )

            case .note:
                let request = TicketNoteRequest(body: text, deviceId: nil)
                let _: TicketNoteResponse = try await APIClient.shared.request(
                    .ticketNote(id: ticketId),
                    body: request
                )
            }

            // Clear and reload
            replyText = ""
            selectedReplyStatus = .pending
            aiGeneratedText = nil
            await loadTicket()

        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }

        isSending = false
    }

    /// Generate AI response
    func generateAIResponse() async {
        guard !isGeneratingAI else { return }

        isGeneratingAI = true
        error = nil

        do {
            let request = AIResponseRequest(locationId: ticket?.locationId)
            let response: AIResponseResult = try await APIClient.shared.request(
                .ticketGenerateResponse(id: ticketId),
                body: request
            )

            aiGeneratedText = response.text
            replyText = response.text
            replyMode = .reply

        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }

        isGeneratingAI = false
    }

    /// Execute a macro
    func executeMacro(_ macro: Macro, overrides: [String: String]? = nil) async {
        error = nil

        do {
            let request = ExecuteMacroRequest(macroId: macro.id, variableOverrides: overrides)
            let _: ExecuteMacroResponse = try await APIClient.shared.request(
                .ticketExecuteMacro(id: ticketId),
                body: request
            )

            await loadTicket()

        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Update ticket status
    func updateStatus(_ status: TicketStatus) async {
        error = nil

        do {
            let body: [String: String] = ["status": status.rawValue]
            let _: Ticket = try await APIClient.shared.request(
                .updateTicket(id: ticketId),
                body: body
            )
            await loadTicket()

        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Workflow Actions

    /// Pause a workflow execution
    func pauseExecution(_ execution: MacroExecution, reason: String?) async {
        error = nil

        do {
            let request = PauseExecutionRequest(reason: reason)
            let _: PauseExecutionResponse = try await APIClient.shared.request(
                .pauseMacroExecution(id: execution.id),
                body: request
            )
            await loadExecutions()

        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Resume a workflow execution
    func resumeExecution(_ execution: MacroExecution, option: SchedulingOption) async {
        error = nil

        do {
            let request = ResumeExecutionRequest(schedulingOption: option.rawValue)
            let _: ResumeExecutionResponse = try await APIClient.shared.request(
                .resumeMacroExecution(id: execution.id),
                body: request
            )
            await loadExecutions()

        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Cancel a workflow execution
    func cancelExecution(_ execution: MacroExecution, reason: String?) async {
        error = nil

        do {
            if let reason {
                let request = CancelExecutionRequest(reason: reason)
                try await APIClient.shared.requestVoid(
                    .cancelMacroExecution(id: execution.id),
                    body: request
                )
            } else {
                try await APIClient.shared.requestVoid(.cancelMacroExecution(id: execution.id))
            }
            await loadExecutions()

        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Use AI-generated text
    func useAIResponse() {
        if let text = aiGeneratedText {
            replyText = text
            replyMode = .reply
        }
    }

    /// Clear AI response
    func clearAIResponse() {
        aiGeneratedText = nil
    }
}
