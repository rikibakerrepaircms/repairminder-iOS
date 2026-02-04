# Stage 06: Enquiries/Tickets

## Objective

Implement enquiry (ticket) list, detail view with message thread, and reply/note functionality.

## Dependencies

- **Requires**: Stage 03 complete (Authentication)
- **Backend Reference**: `[Ref: /Volumes/Riki Repos/repairminder/worker/ticket_handlers.js]`

## Complexity

**Medium** - List, detail with messages, reply composer

## Files to Modify

| File | Changes |
|------|---------|
| `Features/Enquiries/EnquiryListView.swift` | Complete rewrite |
| `Features/Enquiries/EnquiryDetailView.swift` | Complete rewrite |

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Enquiries/EnquiryListViewModel.swift` | List logic with filters |
| `Features/Enquiries/EnquiryDetailViewModel.swift` | Detail and messaging logic |
| `Features/Enquiries/Components/EnquiryListRow.swift` | List row component |
| `Features/Enquiries/Components/MessageThread.swift` | Message display |
| `Features/Enquiries/Components/MessageBubble.swift` | Individual message |
| `Features/Enquiries/Components/ReplyComposer.swift` | Reply input |

---

## Implementation Details

### EnquiryListViewModel.swift

```swift
// Features/Enquiries/EnquiryListViewModel.swift

import Foundation

@MainActor
@Observable
final class EnquiryListViewModel {
    private(set) var tickets: [Ticket] = []
    private(set) var statusCounts: TicketStatusCounts?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMorePages = true
    var error: String?

    var selectedStatus: TicketStatus?

    private var currentPage = 1
    private let pageSize = 20

    // MARK: - Load

    func loadTickets(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            hasMorePages = true
        }

        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.request(
                .tickets(
                    page: currentPage,
                    limit: pageSize,
                    status: selectedStatus?.rawValue
                ),
                responseType: TicketListResponse.self
            )

            if refresh {
                tickets = response.tickets
            } else {
                tickets.append(contentsOf: response.tickets)
            }

            statusCounts = response.statusCounts
            hasMorePages = response.tickets.count == pageSize
            currentPage += 1
        } catch {
            self.error = "Failed to load enquiries"
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore && hasMorePages else { return }
        isLoadingMore = true
        await loadTickets()
        isLoadingMore = false
    }

    func refresh() async {
        await loadTickets(refresh: true)
        await AppState.shared.refreshHeaderCounts()
    }

    func applyStatusFilter(_ status: TicketStatus?) async {
        selectedStatus = status
        await loadTickets(refresh: true)
    }
}
```

---

### EnquiryListView.swift

```swift
// Features/Enquiries/EnquiryListView.swift

import SwiftUI

struct EnquiryListView: View {
    @State private var viewModel = EnquiryListViewModel()
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status Counts Header
                if let counts = viewModel.statusCounts {
                    StatusCountsHeader(
                        counts: counts,
                        selectedStatus: viewModel.selectedStatus,
                        onSelect: { status in
                            Task {
                                await viewModel.applyStatusFilter(status)
                            }
                        }
                    )
                }

                // Ticket List
                List {
                    ForEach(viewModel.tickets) { ticket in
                        NavigationLink {
                            EnquiryDetailView(ticketId: ticket.id)
                        } label: {
                            EnquiryListRow(ticket: ticket)
                        }
                        .onAppear {
                            if ticket == viewModel.tickets.last {
                                Task { await viewModel.loadMore() }
                            }
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Enquiries")
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.isLoading && viewModel.tickets.isEmpty {
                    ProgressView()
                } else if viewModel.tickets.isEmpty {
                    ContentUnavailableView(
                        "No Enquiries",
                        systemImage: "message",
                        description: Text("No enquiries found")
                    )
                }
            }
            .task {
                await viewModel.loadTickets(refresh: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("refreshEnquiries"))) { _ in
                Task { await viewModel.refresh() }
            }
        }
    }
}

// MARK: - Status Counts Header

struct StatusCountsHeader: View {
    let counts: TicketStatusCounts
    let selectedStatus: TicketStatus?
    let onSelect: (TicketStatus?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatusCountChip(
                    title: "All",
                    count: counts.open + counts.pending + counts.resolved + counts.closed,
                    isSelected: selectedStatus == nil,
                    color: .gray
                ) { onSelect(nil) }

                StatusCountChip(
                    title: "Open",
                    count: counts.open,
                    isSelected: selectedStatus == .open,
                    color: .blue
                ) { onSelect(.open) }

                StatusCountChip(
                    title: "Pending",
                    count: counts.pending,
                    isSelected: selectedStatus == .pending,
                    color: .orange
                ) { onSelect(.pending) }

                StatusCountChip(
                    title: "Resolved",
                    count: counts.resolved,
                    isSelected: selectedStatus == .resolved,
                    color: .green
                ) { onSelect(.resolved) }

                StatusCountChip(
                    title: "Closed",
                    count: counts.closed,
                    isSelected: selectedStatus == .closed,
                    color: .gray
                ) { onSelect(.closed) }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct StatusCountChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)

                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? .white.opacity(0.3) : color.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}
```

---

### EnquiryListRow.swift

```swift
// Features/Enquiries/Components/EnquiryListRow.swift

import SwiftUI

struct EnquiryListRow: View {
    let ticket: Ticket

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ticket.displayRef)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                TicketStatusBadge(status: ticket.status)
            }

            Text(ticket.subject)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)

            HStack {
                Text(ticket.client.name ?? ticket.client.email ?? "Unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let lastUpdate = ticket.lastClientUpdate {
                    Text(lastUpdate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(ticket.updatedAt ?? ticket.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Show linked order if exists
            if let order = ticket.order {
                HStack {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text("Order #\(order.orderNumber ?? 0)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TicketStatusBadge: View {
    let status: TicketStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch status {
        case .open: return .blue.opacity(0.2)
        case .pending: return .orange.opacity(0.2)
        case .resolved: return .green.opacity(0.2)
        case .closed: return .gray.opacity(0.2)
        case .unknown: return .gray.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .open: return .blue
        case .pending: return .orange
        case .resolved: return .green
        case .closed: return .gray
        case .unknown: return .gray
        }
    }
}
```

---

### EnquiryDetailViewModel.swift

```swift
// Features/Enquiries/EnquiryDetailViewModel.swift

import Foundation

@MainActor
@Observable
final class EnquiryDetailViewModel {
    let ticketId: String

    private(set) var ticket: Ticket?
    private(set) var isLoading = false
    private(set) var isSending = false
    var error: String?
    var successMessage: String?

    init(ticketId: String) {
        self.ticketId = ticketId
    }

    // MARK: - Load

    func loadTicket() async {
        isLoading = true
        error = nil

        do {
            ticket = try await APIClient.shared.request(
                .ticket(id: ticketId),
                responseType: Ticket.self
            )
        } catch {
            self.error = "Failed to load enquiry"
        }

        isLoading = false
    }

    // MARK: - Reply

    func sendReply(_ body: String) async {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSending = true
        error = nil

        do {
            try await APIClient.shared.requestVoid(
                .ticketReply(ticketId: ticketId, body: body)
            )
            successMessage = "Reply sent"
            await loadTicket() // Reload to show new message
        } catch {
            self.error = "Failed to send reply"
        }

        isSending = false
    }

    // MARK: - Add Note

    func addNote(_ body: String) async {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSending = true
        error = nil

        do {
            try await APIClient.shared.requestVoid(
                .ticketNote(ticketId: ticketId, body: body)
            )
            successMessage = "Note added"
            await loadTicket()
        } catch {
            self.error = "Failed to add note"
        }

        isSending = false
    }

    // MARK: - Resolve

    func resolveTicket(notes: String? = nil) async {
        isSending = true
        error = nil

        do {
            try await APIClient.shared.requestVoid(
                .resolveTicket(ticketId: ticketId, notes: notes)
            )
            successMessage = "Enquiry resolved"
            await loadTicket()
        } catch {
            self.error = "Failed to resolve enquiry"
        }

        isSending = false
    }
}
```

---

### EnquiryDetailView.swift

```swift
// Features/Enquiries/EnquiryDetailView.swift

import SwiftUI

struct EnquiryDetailView: View {
    let ticketId: String
    @State private var viewModel: EnquiryDetailViewModel
    @State private var replyText = ""
    @State private var isNote = false
    @State private var showResolveAlert = false

    init(ticketId: String) {
        self.ticketId = ticketId
        _viewModel = State(initialValue: EnquiryDetailViewModel(ticketId: ticketId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let ticket = viewModel.ticket {
                // Header
                EnquiryHeader(ticket: ticket)

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(ticket.messages ?? []) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.ticket?.messages?.count) { _, _ in
                        if let lastId = ticket.messages?.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }

                // Reply Composer
                ReplyComposer(
                    text: $replyText,
                    isNote: $isNote,
                    isSending: viewModel.isSending,
                    onSend: {
                        Task {
                            if isNote {
                                await viewModel.addNote(replyText)
                            } else {
                                await viewModel.sendReply(replyText)
                            }
                            replyText = ""
                        }
                    }
                )
            }
        }
        .navigationTitle(viewModel.ticket?.displayRef ?? "Enquiry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if let order = viewModel.ticket?.order {
                        NavigationLink {
                            OrderDetailView(orderId: order.id)
                        } label: {
                            Label("View Order", systemImage: "doc.text")
                        }
                    }

                    if viewModel.ticket?.status == .open || viewModel.ticket?.status == .pending {
                        Button {
                            showResolveAlert = true
                        } label: {
                            Label("Resolve", systemImage: "checkmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.ticket == nil {
                ProgressView()
            }
        }
        .alert("Resolve Enquiry", isPresented: $showResolveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Resolve") {
                Task { await viewModel.resolveTicket() }
            }
        } message: {
            Text("Mark this enquiry as resolved?")
        }
        .task {
            await viewModel.loadTicket()
        }
    }
}

// MARK: - Enquiry Header

struct EnquiryHeader: View {
    let ticket: Ticket

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ticket.client.name ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let email = ticket.client.email {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                TicketStatusBadge(status: ticket.status)
            }

            Text(ticket.subject)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
    }
}
```

---

### MessageBubble.swift

```swift
// Features/Enquiries/Components/MessageBubble.swift

import SwiftUI

struct MessageBubble: View {
    let message: TicketMessage

    private var isOutbound: Bool {
        message.type == .outbound || message.type == .outboundSms
    }

    private var isNote: Bool {
        message.type == .note || message.type == .internalNote
    }

    var body: some View {
        HStack {
            if isOutbound { Spacer(minLength: 40) }

            VStack(alignment: isOutbound ? .trailing : .leading, spacing: 4) {
                // Sender info
                HStack(spacing: 4) {
                    if isNote {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                    }

                    Text(senderName)
                        .font(.caption)
                        .fontWeight(.medium)

                    Text(message.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Message body
                Text(message.bodyText ?? "")
                    .font(.subheadline)
                    .padding(12)
                    .background(backgroundColor)
                    .foregroundStyle(foregroundColor)
                    .cornerRadius(16, corners: corners)

                // Attachments
                if let attachments = message.attachments, !attachments.isEmpty {
                    HStack {
                        ForEach(attachments) { attachment in
                            Label(attachment.filename ?? "File", systemImage: "paperclip")
                                .font(.caption)
                                .padding(6)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                    }
                }
            }

            if !isOutbound { Spacer(minLength: 40) }
        }
    }

    private var senderName: String {
        if isNote {
            return "Note: \(message.createdBy?.fullName ?? "Staff")"
        } else if isOutbound {
            return message.createdBy?.fullName ?? "You"
        } else {
            return message.fromName ?? message.fromEmail ?? "Customer"
        }
    }

    private var backgroundColor: Color {
        if isNote {
            return .yellow.opacity(0.2)
        } else if isOutbound {
            return .accentColor
        } else {
            return Color(.systemGray5)
        }
    }

    private var foregroundColor: Color {
        if isNote {
            return .primary
        } else if isOutbound {
            return .white
        } else {
            return .primary
        }
    }

    private var corners: UIRectCorner {
        if isOutbound {
            return [.topLeft, .topRight, .bottomLeft]
        } else {
            return [.topLeft, .topRight, .bottomRight]
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
```

---

### ReplyComposer.swift

```swift
// Features/Enquiries/Components/ReplyComposer.swift

import SwiftUI

struct ReplyComposer: View {
    @Binding var text: String
    @Binding var isNote: Bool
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Note toggle
            HStack {
                Button {
                    isNote.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isNote ? "lock.fill" : "lock.open")
                        Text(isNote ? "Internal Note" : "Reply to Customer")
                            .font(.caption)
                    }
                    .foregroundStyle(isNote ? .orange : .accentColor)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Input
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Type a message...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)

                Button {
                    onSend()
                } label: {
                    if isSending {
                        ProgressView()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(
                                text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? .gray
                                    : .accentColor
                            )
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}
```

---

## Database Changes

None (iOS only)

## Test Cases

| Test | Steps | Expected |
|------|-------|----------|
| Enquiry list loads | Navigate to Enquiries tab | List displays |
| Status filter works | Tap status chip | List filters |
| Status counts show | View header | Counts display |
| Enquiry detail loads | Tap enquiry | Detail with messages |
| Send reply | Type and tap send | Message appears |
| Add note | Toggle to note, type, send | Note appears (yellow) |
| Resolve enquiry | Tap resolve | Status changes |
| Navigate to order | Tap View Order | Order detail opens |
| Message timestamps | View messages | Times display |
| Attachments show | View message with file | Attachment label |

## Acceptance Checklist

- [ ] Enquiry list loads with pagination
- [ ] Status counts display in header
- [ ] Status filter works correctly
- [ ] Enquiry detail loads with messages
- [ ] Messages display with correct alignment (in/out)
- [ ] Notes display with yellow background
- [ ] Reply sends successfully
- [ ] Internal note sends successfully
- [ ] Resolve action works
- [ ] Navigation to linked order works
- [ ] Badge count updates on tab
- [ ] No decode errors in console

## Deployment

1. Build and run
2. Navigate to Enquiries tab
3. Verify list loads with status counts
4. Test status filter
5. Open enquiry detail
6. Send a reply, verify it appears
7. Add an internal note
8. Test resolve action
9. Verify linked order navigation

## Handoff Notes

- Messages sorted chronologically (oldest first)
- Note toggle affects whether reply goes to customer
- Internal notes only visible to staff
- Linked order available via menu
- Deep links use ticket ID
- [See: Stage 07] for push notification handling of enquiry replies
