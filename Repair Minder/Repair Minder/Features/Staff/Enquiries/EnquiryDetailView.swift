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
    @State private var isReplyExpanded = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(ticketId: String) {
        self.ticketId = ticketId
        self._viewModel = StateObject(wrappedValue: EnquiryDetailViewModel(ticketId: ticketId))
    }

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
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
        .frame(maxWidth: isRegularWidth ? 700 : .infinity)
        .frame(maxWidth: .infinity)
        .background(isRegularWidth ? Color(.systemGroupedBackground) : .clear)
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
        .onChange(of: viewModel.replyText) { oldValue, newValue in
            // Auto-expand fully when AI generates text (large jump in content)
            if newValue.count > 100 && oldValue.isEmpty && !isReplyExpanded {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isReplyExpanded = true
                }
            }
            // Auto-collapse when text is cleared
            if newValue.isEmpty && (isReplyExpanded || isReplyFocused) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isReplyExpanded = false
                    isReplyFocused = false
                }
            }
        }
        .sheet(isPresented: $viewModel.showingMacroPicker) {
            MacroPickerSheet(
                macros: viewModel.macros,
                onSelect: { macro in
                    viewModel.selectedWorkflowMacro = macro
                }
            )
        }
        .sheet(item: $viewModel.selectedWorkflowMacro) { macro in
            WorkflowExecutionSheet(macro: macro) { overrides in
                Task { await viewModel.executeMacro(macro, overrides: overrides) }
            }
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
                    Text(ticket.client?.displayName ?? "Unknown")
                        .font(.subheadline.weight(.medium))
                    Text(ticket.client?.email ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                // Status badge
                StatusBadge(status: ticket.status)
            }

            // No-email banner
            if ticket.client?.isGeneratedEmail == 1 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("No email address — replies will not be emailed")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Metadata row (iPad — show type, created, updated side by side)
            if isRegularWidth {
                Divider()
                HStack(spacing: 16) {
                    metadataItem(icon: ticket.ticketType.icon, label: "Type", value: ticket.ticketType.label, color: ticket.ticketType.color)
                    Spacer()
                    metadataItem(icon: "calendar", label: "Created", value: formattedDate(ticket.createdAt))
                    Spacer()
                    metadataItem(icon: "clock.arrow.circlepath", label: "Updated", value: ticket.formattedLastUpdate)
                    if let user = ticket.assignedUser {
                        Spacer()
                        metadataItem(icon: "person", label: "Assigned", value: user.fullName)
                    }
                }
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

    /// Text area height based on state: compact → focused → expanded
    private var textAreaHeight: CGFloat {
        if isReplyExpanded {
            return isRegularWidth ? 350 : UIScreen.main.bounds.height * 0.65
        } else if isReplyFocused {
            return isRegularWidth ? 200 : UIScreen.main.bounds.height * 0.35
        } else {
            return 48
        }
    }

    /// Whether the composer is in an active editing state
    private var isComposerActive: Bool {
        isReplyFocused || isReplyExpanded
    }

    private var replyComposer: some View {
        VStack(spacing: 0) {
            Divider()

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

            // Mode picker row with workflow, AI, and expand/collapse
            HStack {
                Picker("Mode", selection: $viewModel.replyMode) {
                    ForEach(EnquiryDetailViewModel.ReplyMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                // Collapse pill (shown when active)
                if isComposerActive {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isReplyExpanded = false
                            isReplyFocused = false
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.down.2")
                                .imageScale(.small)
                            Text("Collapse")
                        }
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                    }
                }

                // Expand pill (when focused but not fully expanded, and has text)
                if isReplyFocused && !isReplyExpanded && !viewModel.replyText.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isReplyExpanded = true
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.up.2")
                                .imageScale(.small)
                            Text("Expand")
                        }
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                    }
                }

                Spacer()

                // Workflow button
                if !viewModel.macros.isEmpty {
                    Menu {
                        ForEach(viewModel.macros.prefix(8)) { macro in
                            Button {
                                viewModel.selectedWorkflowMacro = macro
                            } label: {
                                Label(macro.name, systemImage: macro.isEmailMacro ? "envelope" : "note.text")
                            }
                        }

                        if viewModel.macros.count > 8 {
                            Divider()
                        }

                        Button {
                            viewModel.showingMacroPicker = true
                        } label: {
                            Label("Browse All...", systemImage: "ellipsis.circle")
                        }
                    } label: {
                        Image(systemName: "bolt.circle")
                            .font(.title3)
                    }
                }

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

            // SMS toggle (only in reply mode when SMS is available)
            if viewModel.replyMode == .reply && viewModel.canSendSms {
                HStack(spacing: 6) {
                    Toggle(isOn: $viewModel.sendSms) {
                        HStack(spacing: 4) {
                            Image(systemName: "message")
                                .font(.caption)
                            Text("Also send SMS")
                                .font(.caption)
                        }
                    }
                    .toggleStyle(.switch)
                    .scaleEffect(0.8)
                    .disabled(viewModel.ticket?.smsRemaining == 0)

                    if viewModel.sendSms, let phone = viewModel.ticket?.client?.phone {
                        Text("to \(phone)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let remaining = viewModel.ticket?.smsRemaining, remaining <= 10 {
                        Text(remaining == 0 ? "SMS limit reached" : "\(remaining) SMS left")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(remaining == 0 ? .red : .orange)
                    }

                    if viewModel.ticket?.smsAlreadySent == true {
                        Text("SMS already sent")
                            .font(.caption2)
                            .italic()
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }

            // Text input with status dropdown and send button
            HStack(alignment: .bottom, spacing: 8) {
                ZStack(alignment: .bottom) {
                    ScrollView {
                        TextField(viewModel.replyMode.placeholder, text: $viewModel.replyText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .focused($isReplyFocused)
                            .padding(8)
                            .frame(minHeight: textAreaHeight, alignment: .topLeading)
                    }
                    .scrollIndicators(isComposerActive ? .automatic : .never)
                    .scrollDisabled(!isComposerActive)
                    .frame(height: textAreaHeight)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isReplyFocused ? Color.blue.opacity(0.5) : Color(.systemGray4), lineWidth: isReplyFocused ? 1 : 0.5)
                    )

                    // Fade gradient when compact and has text
                    if !isComposerActive && !viewModel.replyText.isEmpty {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: Color(.systemGray6), location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .allowsHitTesting(false)
                    }
                }

                // Right side: status dropdown above send button
                VStack(spacing: 4) {
                    // Status dropdown (only for replies)
                    if viewModel.replyMode == .reply {
                        Menu {
                            ForEach(TicketStatus.allCases, id: \.self) { status in
                                Button {
                                    viewModel.selectedReplyStatus = status
                                } label: {
                                    HStack {
                                        Image(systemName: status.icon)
                                        Text(status.label)
                                        if viewModel.selectedReplyStatus == status {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Text(viewModel.selectedReplyStatus?.label ?? "Status")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background((viewModel.selectedReplyStatus?.color ?? .secondary).opacity(0.15))
                                .foregroundStyle(viewModel.selectedReplyStatus?.color ?? .secondary)
                                .clipShape(Capsule())
                        }
                    }

                    // Send button (iOS blue style)
                    Button {
                        Task { await viewModel.sendMessage() }
                    } label: {
                        if viewModel.isSending {
                            ProgressView()
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(viewModel.canSendReply ? .blue : Color(.systemGray4))
                        }
                    }
                    .disabled(!viewModel.canSendReply)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isReplyExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isReplyFocused)
    }

    // MARK: - iPad Helpers

    private func metadataItem(icon: String, label: String, value: String, color: Color = .secondary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(.caption.weight(.medium))
            }
        }
    }

    private func formattedDate(_ isoString: String) -> String {
        DateFormatters.formatRelativeDate(isoString) ?? isoString
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

// MARK: - Workflow Execution Sheet

private struct WorkflowExecutionSheet: View {
    let macro: Macro
    let onExecute: ([String: String]?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var variableValues: [String: String] = [:]
    @State private var validationErrors: Set<String> = []

    /// Variables that require user input when executing (matches web app PER_USE_VARIABLES)
    private static let perUseVariables = ["device_type", "repair_type", "price", "reply"]

    /// Labels for per-use variables
    private static let variableLabels: [String: String] = [
        "device_type": "Device Model",
        "repair_type": "Repair Type",
        "price": "Price",
        "reply": "Reply Content",
    ]

    /// Placeholders for per-use variables
    private static let variablePlaceholders: [String: String] = [
        "device_type": "e.g., iPhone 14 Pro, Samsung Galaxy S24",
        "repair_type": "e.g., Screen Replacement, Battery Replacement",
        "price": "e.g., 149.99",
        "reply": "Enter your reply message here...",
    ]

    /// Detect which per-use variables are used in the macro content (initial + all stages)
    private var usedPerUseVariables: [String] {
        var allContent = macro.initialContent + " " + (macro.initialSubject ?? "")
        if let stages = macro.stages {
            for stage in stages {
                allContent += " " + (stage.subject ?? "") + " " + (stage.content ?? "")
            }
        }
        return Self.perUseVariables.filter { allContent.contains("{{\($0)}}") }
    }

    private func label(for variable: String) -> String {
        Self.variableLabels[variable] ?? variable.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func placeholder(for variable: String) -> String {
        Self.variablePlaceholders[variable] ?? label(for: variable)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Macro info
                Section {
                    if let description = macro.description, !description.isEmpty {
                        Text(description)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Image(systemName: macro.isEmailMacro ? "envelope" : "note.text")
                            .foregroundStyle(.blue)
                        Text(macro.isEmailMacro ? "Sends Email" : "Adds Note")
                            .font(.subheadline)
                    }

                    if macro.hasFollowUps {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundStyle(.orange)
                            Text("\(macro.stageCount ?? 0) follow-up stage\(macro.stageCount == 1 ? "" : "s")")
                                .font(.subheadline)
                        }
                    }

                    if let behavior = macro.replyBehavior, behavior != "continue" {
                        HStack {
                            Image(systemName: behavior == "cancel" ? "xmark.circle" : "pause.circle")
                                .foregroundStyle(.secondary)
                            Text(macro.replyBehaviorDescription)
                                .font(.subheadline)
                        }
                    }
                }

                // Per-use variable inputs
                if !usedPerUseVariables.isEmpty {
                    Section("Required Information") {
                        ForEach(usedPerUseVariables, id: \.self) { variable in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(label(for: variable))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField(placeholder(for: variable), text: Binding(
                                    get: { variableValues[variable] ?? "" },
                                    set: {
                                        variableValues[variable] = $0
                                        validationErrors.remove(variable)
                                    }
                                ))
                                if validationErrors.contains(variable) {
                                    Text("This field is required")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }

                // Preview
                Section("Preview") {
                    if let subject = macro.initialSubject, macro.isEmailMacro {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Subject")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(subject)
                                .font(.subheadline)
                        }
                    }

                    Text(macro.initialContent)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(macro.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(macro.isEmailMacro ? "Send Email" : "Add Note") {
                        // Validate required per-use variables
                        let missing = usedPerUseVariables.filter { (variableValues[$0] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
                        if !missing.isEmpty {
                            validationErrors = Set(missing)
                            return
                        }
                        let nonEmpty = variableValues.filter { !$0.value.isEmpty }
                        onExecute(nonEmpty.isEmpty ? nil : nonEmpty)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EnquiryDetailView(ticketId: "test-id")
    }
}
