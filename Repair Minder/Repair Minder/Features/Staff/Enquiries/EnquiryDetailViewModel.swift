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
    @Published private(set) var isRewritingAI = false
    @Published private(set) var hasRewrittenAI = false
    /// Per-feature AI readiness. `nil` while loading/unknown — gating stays off
    /// until we have a definitive answer (the backend still fails safely).
    @Published private(set) var aiReadiness: AiReadiness?
    @Published private(set) var error: String?
    @Published var showingMacroPicker = false
    @Published var showingStatusPicker = false

    // MARK: - Reply State

    @Published var replyText = ""
    @Published var selectedReplyStatus: TicketStatus? = .pending
    @Published var replyMode: ReplyMode = .reply
    @Published var selectedWorkflowMacro: Macro?
    @Published var sendSms = false

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

    /// Whether SMS can be sent (company has SMS + client has phone)
    var canSendSms: Bool {
        guard let ticket = ticket else { return false }
        return ticket.smsAvailable == true && ticket.client?.phone != nil
    }

    /// Whether AI replies are known to be unavailable (ticket AI disabled or no
    /// provider key). Only true once readiness has loaded and `tickets.ready` is
    /// false — stays false while readiness is unknown so we don't block on it.
    var aiRepliesUnavailable: Bool {
        aiReadiness?.tickets.ready == false
    }

    /// Whether client needs SMS (no valid email)
    private var clientNeedsSms: Bool {
        guard let client = ticket?.client else { return false }
        return client.isGeneratedEmail == 1 || client.emailSuppressed == 1
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

            // Auto-check SMS toggle for no-email/suppressed clients
            if let ticket = self.ticket, ticket.smsAvailable == true, ticket.client?.phone != nil {
                let needsSms = (ticket.client?.isGeneratedEmail == 1 || ticket.client?.emailSuppressed == 1)
                sendSms = needsSms && !(ticket.smsAlreadySent ?? false)
            } else {
                sendSms = false
            }

            await loadMacros()
            await loadExecutions()
            await loadAiReadiness()
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
            #if DEBUG
            print("Failed to load macros: \(error)")
            #endif
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
            #if DEBUG
            print("Failed to load executions: \(error)")
            #endif
        }
    }

    /// Load per-feature AI readiness so we can proactively gate the AI buttons.
    /// Failures are swallowed — readiness stays `nil` (unknown) and the buttons
    /// remain enabled; the backend still fails safely on the actual call.
    func loadAiReadiness() async {
        do {
            aiReadiness = try await APIClient.shared.request(.aiReadiness)
        } catch is CancellationError { }
        catch let urlError as URLError where urlError.code == .cancelled { }
        catch {
            #if DEBUG
            print("Failed to load AI readiness: \(error)")
            #endif
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
                    pendingAttachmentIds: nil,
                    sendSms: sendSms ? true : nil
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
            sendSms = false
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
            let start: AIJobStart = try await APIClient.shared.request(
                .ticketGenerateResponse(id: ticketId), body: request
            )
            _ = start
            let result = try await pollAIJob(.ticketGenerateResponseStatus(id: ticketId))
            replyText = result.text
            replyMode = .reply
        } catch let apiError as APIError {
            error = friendlyAIError(apiError)
        } catch {
            self.error = error.localizedDescription
        }

        isGeneratingAI = false
    }

    /// Rewrite the current reply text using AI
    func rewriteResponse() async {
        guard !isRewritingAI else { return }
        guard !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isRewritingAI = true
        error = nil

        do {
            let request = AIRewriteRequest(text: replyText, locationId: ticket?.locationId)
            let start: AIJobStart = try await APIClient.shared.request(
                .ticketRewriteResponse(id: ticketId), body: request
            )
            _ = start
            let result = try await pollAIJob(.ticketRewriteResponseStatus(id: ticketId))
            replyText = result.text
            hasRewrittenAI = true
        } catch let apiError as APIError {
            error = friendlyAIError(apiError)
        } catch {
            self.error = error.localizedDescription
        }

        isRewritingAI = false
    }

    /// Poll an AI job status endpoint until it is done; throws on error/timeout.
    private func pollAIJob(_ endpoint: APIEndpoint) async throws -> AIResponseResult {
        let maxAttempts = 40            // ~80s
        for attempt in 0..<maxAttempts {
            try await Task.sleep(for: .milliseconds(attempt == 0 ? 1500 : 2000))
            let status: AIJobStatus = try await APIClient.shared.request(endpoint)
            switch status.status {
            case "done":
                if let result = status.result { return result }
                throw APIError.serverError(message: "AI job finished without a result", code: nil)
            case "error":
                throw APIError.serverError(message: "AI generation failed", code: nil)
            default:
                continue                // idle / running
            }
        }
        throw APIError.serverError(message: "AI generation timed out", code: nil)
    }

    /// Map an AI-endpoint error to a friendly, non-scary message when it's the
    /// "no provider key" case. The two ticket AI endpoints return HTTP 400 with
    /// an error mentioning Provider Keys when the company hasn't configured a
    /// key. The response contains no secrets, so nothing sensitive is shown.
    private func friendlyAIError(_ apiError: APIError) -> String {
        if case .httpError(let statusCode, let message) = apiError,
           statusCode == 400,
           let message,
           message.localizedCaseInsensitiveContains("provider key")
            || message.localizedCaseInsensitiveContains("api key") {
            return providerKeyHint
        }
        return apiError.localizedDescription
    }

    /// User-facing hint shown when ticket AI has no provider key configured.
    var providerKeyHint: String {
        "AI replies aren't set up for your company yet. An admin can add a provider key in the web dashboard → Settings → Provider Keys."
    }

    /// Preview a macro — returns fully substituted subject and content
    func previewMacro(_ macro: Macro, overrides: [String: String]? = nil) async -> PreviewMacroResponse? {
        do {
            let request = PreviewMacroRequest(
                macroId: macro.id,
                variableOverrides: overrides
            )
            let response: PreviewMacroResponse = try await APIClient.shared.request(
                .ticketPreviewMacro(id: ticketId),
                body: request
            )
            return response
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    /// Execute a macro
    func executeMacro(_ macro: Macro, overrides: [String: String]? = nil, subjectOverride: String? = nil, contentOverride: String? = nil) async {
        error = nil

        do {
            let request = ExecuteMacroRequest(
                macroId: macro.id,
                variableOverrides: overrides,
                sendSms: sendSms ? true : nil,
                subjectOverride: subjectOverride,
                contentOverride: contentOverride
            )
            let _: ExecuteMacroResponse = try await APIClient.shared.request(
                .ticketExecuteMacro(id: ticketId),
                body: request
            )
            sendSms = false
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
            try await APIClient.shared.requestVoid(
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

}
