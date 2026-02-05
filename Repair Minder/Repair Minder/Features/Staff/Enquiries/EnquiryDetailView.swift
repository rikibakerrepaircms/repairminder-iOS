//
//  EnquiryDetailView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// Detail view for a single ticket showing message thread and actions
struct EnquiryDetailView: View {
    let ticketId: String

    @StateObject private var viewModel: EnquiryDetailViewModel
    @FocusState private var isReplyFocused: Bool

    init(ticketId: String) {
        self.ticketId = ticketId
        self._viewModel = StateObject(wrappedValue: EnquiryDetailViewModel(ticketId: ticketId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            if viewModel.isLoading && viewModel.ticket == nil {
                loadingView
            } else if let error = viewModel.error, viewModel.ticket == nil {
                errorView(error)
            } else if let ticket = viewModel.ticket {
                ticketContent(ticket)
            }
        }
        .navigationTitle(viewModel.ticket?.displayNumber ?? "Ticket")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    statusMenu
                    Divider()
                    macroMenu
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await viewModel.loadTicket()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $viewModel.showingMacroPicker) {
            MacroPickerSheet(
                macros: viewModel.macros,
                onSelect: { macro in
                    Task { await viewModel.executeMacro(macro) }
                }
            )
        }
    }

    // MARK: - Loading & Error Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
            Text("Loading ticket...")
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Failed to load ticket")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    // MARK: - Ticket Content

    @ViewBuilder
    private func ticketContent(_ ticket: Ticket) -> some View {
        VStack(spacing: 0) {
            // Header card
            ticketHeader(ticket)

            // Active workflows
            if !viewModel.activeExecutions.isEmpty {
                workflowSection
            }

            // Messages
            messagesList

            // Reply composer
            if ticket.canReply {
                replyComposer
            } else {
                closedBanner(ticket)
            }
        }
    }

    // MARK: - Ticket Header

    private func ticketHeader(_ ticket: Ticket) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Subject
            Text(ticket.subject)
                .font(.headline)

            // Client info
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ticket.client.displayName)
                        .font(.subheadline.weight(.medium))
                    Text(ticket.client.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                // Status badge
                StatusBadge(status: ticket.status)
            }

            // Order info
            if let order = ticket.order {
                Divider()
                HStack {
                    Image(systemName: "bag.fill")
                        .foregroundColor(.blue)
                    Text("Linked Order")
                        .font(.subheadline)
                    Spacer()
                    Text("\(order.deviceCount) device\(order.deviceCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Location
            if let location = ticket.location {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.green)
                    Text(location.name)
                        .font(.subheadline)
                }
            } else if ticket.requiresLocation == true {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Location required")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Workflow Section

    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Workflows")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal)

            ForEach(viewModel.activeExecutions) { execution in
                WorkflowCard(
                    execution: execution,
                    onPause: { await viewModel.pauseExecution(execution, reason: nil) },
                    onResume: { await viewModel.resumeExecution(execution, option: .rescheduleFromNow) },
                    onCancel: { await viewModel.cancelExecution(execution, reason: nil) }
                )
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Messages List

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.sortedMessages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.sortedMessages.count) { _, _ in
                // Scroll to bottom when new messages arrive
                if let lastMessage = viewModel.sortedMessages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Reply Composer

    private var replyComposer: some View {
        VStack(spacing: 0) {
            Divider()

            // AI response preview
            if viewModel.aiGeneratedText != nil {
                aiResponsePreview
            }

            // Error banner
            if let error = viewModel.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                        .font(.caption)
                }
                .foregroundColor(.red)
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // Mode picker
            HStack {
                Picker("Mode", selection: $viewModel.replyMode) {
                    ForEach(EnquiryDetailViewModel.ReplyMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Spacer()

                // AI generate button
                Button {
                    Task { await viewModel.generateAIResponse() }
                } label: {
                    if viewModel.isGeneratingAI {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                }
                .disabled(viewModel.isGeneratingAI)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Text input
            HStack(alignment: .bottom, spacing: 8) {
                TextField(viewModel.replyMode.placeholder, text: $viewModel.replyText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)
                    .focused($isReplyFocused)

                // Send button
                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    if viewModel.isSending {
                        ProgressView()
                    } else {
                        Image(systemName: viewModel.replyMode == .reply ? "paperplane.fill" : "plus.circle.fill")
                            .font(.title2)
                    }
                }
                .disabled(!viewModel.canSendReply)
            }
            .padding()

            // Status selector for replies
            if viewModel.replyMode == .reply {
                HStack {
                    Text("Set status to:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Status", selection: $viewModel.selectedReplyStatus) {
                        Text("No change").tag(nil as TicketStatus?)
                        ForEach(TicketStatus.allCases, id: \.self) { status in
                            Text(status.label).tag(status as TicketStatus?)
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .background(Color(.systemBackground))
    }

    private var aiResponsePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Generated Response")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button("Use") {
                    viewModel.useAIResponse()
                }
                .font(.caption)
                Button {
                    viewModel.clearAIResponse()
                } label: {
                    Image(systemName: "xmark.circle")
                }
            }

            Text(viewModel.aiGeneratedText ?? "")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(4)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
    }

    private func closedBanner(_ ticket: Ticket) -> some View {
        HStack {
            Image(systemName: ticket.isMerged ? "arrow.merge" : "lock.fill")
            Text(ticket.isMerged ? "This ticket has been merged" : "This ticket is closed")
                .font(.subheadline)
        }
        .foregroundColor(.secondary)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Menus

    @ViewBuilder
    private var statusMenu: some View {
        Menu("Change Status") {
            ForEach(TicketStatus.allCases, id: \.self) { status in
                Button {
                    Task { await viewModel.updateStatus(status) }
                } label: {
                    Label(status.label, systemImage: status.icon)
                }
            }
        }
    }

    @ViewBuilder
    private var macroMenu: some View {
        if !viewModel.macros.isEmpty {
            Menu("Run Macro") {
                ForEach(viewModel.macros) { macro in
                    Button {
                        Task { await viewModel.executeMacro(macro) }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(macro.name)
                            if let desc = macro.description {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Divider()

                Button {
                    viewModel.showingMacroPicker = true
                } label: {
                    Label("Browse All...", systemImage: "ellipsis.circle")
                }
            }
        }
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let status: TicketStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
            Text(status.label)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .foregroundColor(status.color)
        .clipShape(Capsule())
    }
}

// MARK: - Workflow Card

private struct WorkflowCard: View {
    let execution: MacroExecution
    let onPause: () async -> Void
    let onResume: () async -> Void
    let onCancel: () async -> Void

    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: execution.status.icon)
                    .foregroundColor(execution.status.color)
                Text(execution.macroName)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(execution.status.label)
                    .font(.caption)
                    .foregroundColor(execution.status.color)
            }

            // Progress
            HStack {
                Text(execution.progressDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let nextStage = execution.nextStage {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("Next: \(nextStage.timeRemaining)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Actions
            if execution.status.isModifiable && !isProcessing {
                HStack {
                    if execution.status == .active {
                        Button("Pause") {
                            isProcessing = true
                            Task {
                                await onPause()
                                isProcessing = false
                            }
                        }
                        .font(.caption)
                    } else if execution.status == .paused {
                        Button("Resume") {
                            isProcessing = true
                            Task {
                                await onResume()
                                isProcessing = false
                            }
                        }
                        .font(.caption)
                    }

                    Button("Cancel", role: .destructive) {
                        isProcessing = true
                        Task {
                            await onCancel()
                            isProcessing = false
                        }
                    }
                    .font(.caption)
                }
            }

            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        EnquiryDetailView(ticketId: "test-id")
    }
}
