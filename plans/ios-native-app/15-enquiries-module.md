# Stage 15: Enquiries Module (Staff)

## Objective

Build a polished enquiry management interface for staff to view, respond to, and convert customer enquiries into repair orders. This is a high-visibility feature that creates first impressions with potential customers.

---

## Dependencies

**Requires:** [See: Stage 07] complete - Orders module for enquiry conversion
**Requires:** [See: Stage 11] complete - Push notifications for new enquiry alerts

---

## Complexity

**Medium** - Polished UI, real-time updates, conversation interface

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Enquiries/EnquiryListView.swift` | Main enquiry inbox |
| `Features/Enquiries/EnquiryListViewModel.swift` | List state management |
| `Features/Enquiries/EnquiryDetailView.swift` | Full enquiry view with conversation |
| `Features/Enquiries/EnquiryDetailViewModel.swift` | Detail logic |
| `Features/Enquiries/Components/EnquiryCard.swift` | Rich enquiry preview card |
| `Features/Enquiries/Components/EnquiryStatusPill.swift` | Animated status indicator |
| `Features/Enquiries/Components/EnquiryConversation.swift` | Message thread UI |
| `Features/Enquiries/Components/QuickReplyBar.swift` | Fast response input |
| `Features/Enquiries/Components/ConvertToOrderSheet.swift` | Enquiry → Order flow |
| `Features/Enquiries/EnquiryFilterSheet.swift` | Filter/sort options |
| `Core/Models/Enquiry.swift` | Enquiry data model |

---

## Implementation Details

### 1. Enquiry List View (Polished Inbox)

```swift
// Features/Enquiries/EnquiryListView.swift
import SwiftUI

struct EnquiryListView: View {
    @StateObject private var viewModel = EnquiryListViewModel()
    @EnvironmentObject var router: AppRouter
    @State private var showFilters = false
    @Namespace private var animation

    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Stats Header
                    EnquiryStatsHeader(stats: viewModel.stats)
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                    // Filter Chips
                    EnquiryFilterChips(
                        selectedFilter: $viewModel.selectedFilter,
                        counts: viewModel.filterCounts
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                    // Enquiry List
                    if viewModel.enquiries.isEmpty && !viewModel.isLoading {
                        EnquiryEmptyState(filter: viewModel.selectedFilter)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.enquiries) { enquiry in
                                    EnquiryCard(
                                        enquiry: enquiry,
                                        namespace: animation
                                    )
                                    .onTapGesture {
                                        router.navigate(to: .enquiryDetail(id: enquiry.id))
                                    }
                                    .contextMenu {
                                        EnquiryContextMenu(
                                            enquiry: enquiry,
                                            onMarkRead: { viewModel.markAsRead(enquiry.id) },
                                            onArchive: { viewModel.archive(enquiry.id) }
                                        )
                                    }
                                }

                                if viewModel.hasMorePages {
                                    ProgressView()
                                        .padding()
                                        .onAppear {
                                            Task { await viewModel.loadMore() }
                                        }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                        .refreshable {
                            await viewModel.refresh()
                        }
                    }
                }
            }
            .navigationTitle("Enquiries")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .enquiryDetail(let id):
                    EnquiryDetailView(enquiryId: id)
                default:
                    EmptyView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .symbolVariant(viewModel.hasActiveFilters ? .fill : .none)
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                EnquiryFilterSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.loadEnquiries()
            }
        }
    }
}

// Stats header showing key metrics
struct EnquiryStatsHeader: View {
    let stats: EnquiryStats

    var body: some View {
        HStack(spacing: 16) {
            StatPill(
                value: stats.newToday,
                label: "New Today",
                color: .blue,
                icon: "envelope.badge"
            )

            StatPill(
                value: stats.awaitingReply,
                label: "Awaiting Reply",
                color: .orange,
                icon: "clock"
            )

            StatPill(
                value: stats.convertedThisWeek,
                label: "Converted",
                color: .green,
                icon: "checkmark.circle"
            )
        }
    }
}

struct StatPill: View {
    let value: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.headline)
                    .fontWeight(.bold)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// Horizontal filter chips
struct EnquiryFilterChips: View {
    @Binding var selectedFilter: EnquiryFilter
    let counts: [EnquiryFilter: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EnquiryFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        count: counts[filter] ?? 0,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let filter: EnquiryFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(filter.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
```

### 2. Enquiry Card (Rich Preview)

```swift
// Features/Enquiries/Components/EnquiryCard.swift
import SwiftUI

struct EnquiryCard: View {
    let enquiry: Enquiry
    let namespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(alignment: .top) {
                // Customer avatar
                CustomerInitialsAvatar(
                    name: enquiry.customerName,
                    size: 44,
                    isNew: !enquiry.isRead
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(enquiry.customerName)
                            .font(.headline)
                            .fontWeight(.semibold)

                        if !enquiry.isRead {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(enquiry.customerEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Time & Status
                VStack(alignment: .trailing, spacing: 4) {
                    Text(enquiry.createdAt.relativeFormatted())
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    EnquiryStatusPill(status: enquiry.status)
                }
            }

            // Device info
            HStack(spacing: 8) {
                Image(systemName: enquiry.deviceType.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(enquiry.deviceBrand) \(enquiry.deviceModel)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if let phone = enquiry.customerPhone {
                    Label(phone, systemImage: "phone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Issue preview
            Text(enquiry.issueDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Footer with actions hint
            HStack {
                if let lastReply = enquiry.lastReply {
                    HStack(spacing: 4) {
                        Image(systemName: lastReply.isFromStaff ? "arrow.turn.up.right" : "arrow.turn.down.left")
                            .font(.caption2)
                        Text(lastReply.isFromStaff ? "You replied" : "Customer replied")
                            .font(.caption)
                        Text("•")
                        Text(lastReply.createdAt.relativeFormatted())
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                // Reply count
                if enquiry.replyCount > 0 {
                    Label("\(enquiry.replyCount)", systemImage: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(enquiry.isRead ? Color.clear : Color.blue.opacity(0.3), lineWidth: 2)
        )
    }
}

struct CustomerInitialsAvatar: View {
    let name: String
    let size: CGFloat
    let isNew: Bool

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].first ?? "?")\(parts[1].first ?? "?")"
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(avatarGradient)
                .clipShape(Circle())

            if isNew {
                Circle()
                    .fill(.blue)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .offset(x: size/3, y: -size/3)
            }
        }
    }

    var avatarGradient: LinearGradient {
        let colors: [(Color, Color)] = [
            (.blue, .purple),
            (.green, .teal),
            (.orange, .red),
            (.pink, .purple),
            (.teal, .blue)
        ]
        let index = abs(name.hashValue) % colors.count
        return LinearGradient(
            colors: [colors[index].0, colors[index].1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct EnquiryStatusPill: View {
    let status: EnquiryStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)

            Text(status.shortName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .clipShape(Capsule())
    }
}
```

### 3. Enquiry Detail View

```swift
// Features/Enquiries/EnquiryDetailView.swift
import SwiftUI

struct EnquiryDetailView: View {
    let enquiryId: String
    @StateObject private var viewModel: EnquiryDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showConvertSheet = false
    @State private var replyText = ""
    @FocusState private var isReplyFocused: Bool

    init(enquiryId: String) {
        self.enquiryId = enquiryId
        _viewModel = StateObject(wrappedValue: EnquiryDetailViewModel(enquiryId: enquiryId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        // Enquiry Header Card
                        EnquiryHeaderCard(enquiry: viewModel.enquiry)

                        // Device Info Card
                        if let enquiry = viewModel.enquiry {
                            DeviceInfoCard(enquiry: enquiry)
                        }

                        // Issue Description
                        IssueDescriptionCard(description: viewModel.enquiry?.issueDescription ?? "")

                        // Conversation Thread
                        ConversationThread(
                            messages: viewModel.messages,
                            scrollProxy: proxy
                        )
                    }
                    .padding()
                }
            }

            // Quick Reply Bar
            QuickReplyBar(
                text: $replyText,
                isFocused: $isReplyFocused,
                onSend: {
                    Task {
                        await viewModel.sendReply(replyText)
                        replyText = ""
                    }
                },
                templates: viewModel.replyTemplates
            )
        }
        .navigationTitle("Enquiry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showConvertSheet = true
                    } label: {
                        Label("Convert to Order", systemImage: "doc.badge.plus")
                    }

                    Button {
                        Task { await viewModel.markAsSpam() }
                    } label: {
                        Label("Mark as Spam", systemImage: "xmark.bin")
                    }

                    Button(role: .destructive) {
                        Task { await viewModel.archive() }
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            // Convert to Order button (prominent)
            ToolbarItem(placement: .primaryAction) {
                if viewModel.enquiry?.status != .converted {
                    Button {
                        showConvertSheet = true
                    } label: {
                        Label("Create Order", systemImage: "plus.circle.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .sheet(isPresented: $showConvertSheet) {
            ConvertToOrderSheet(
                enquiry: viewModel.enquiry!,
                onConvert: { orderData in
                    Task {
                        await viewModel.convertToOrder(orderData)
                        dismiss()
                    }
                }
            )
        }
        .task {
            await viewModel.load()
            viewModel.markAsRead()
        }
    }
}

struct EnquiryHeaderCard: View {
    let enquiry: Enquiry?

    var body: some View {
        if let enquiry = enquiry {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    CustomerInitialsAvatar(name: enquiry.customerName, size: 60, isNew: false)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(enquiry.customerName)
                            .font(.title3)
                            .fontWeight(.bold)

                        // Contact buttons
                        HStack(spacing: 12) {
                            if let phone = enquiry.customerPhone {
                                ContactPill(icon: "phone.fill", value: phone, action: .call)
                            }
                            ContactPill(icon: "envelope.fill", value: enquiry.customerEmail, action: .email)
                        }
                    }

                    Spacer()

                    EnquiryStatusPill(status: enquiry.status)
                }

                // Received time
                HStack {
                    Image(systemName: "clock")
                    Text("Received \(enquiry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    Spacer()
                    Text(enquiry.createdAt.relativeFormatted())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct ContactPill: View {
    let icon: String
    let value: String

    enum Action { case call, email }
    let action: Action

    var body: some View {
        Button {
            switch action {
            case .call:
                if let url = URL(string: "tel:\(value)") {
                    UIApplication.shared.open(url)
                }
            case .email:
                if let url = URL(string: "mailto:\(value)") {
                    UIApplication.shared.open(url)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(value)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct DeviceInfoCard: View {
    let enquiry: Enquiry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Device Information", systemImage: "iphone")
                .font(.headline)

            HStack(spacing: 16) {
                InfoItem(label: "Type", value: enquiry.deviceType.displayName, icon: enquiry.deviceType.icon)
                InfoItem(label: "Brand", value: enquiry.deviceBrand, icon: "building.2")
                InfoItem(label: "Model", value: enquiry.deviceModel, icon: "tag")
            }

            if let imei = enquiry.imei {
                HStack {
                    Text("IMEI")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(imei)
                        .font(.caption.monospaced())
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct InfoItem: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct IssueDescriptionCard: View {
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Issue Description", systemImage: "exclamationmark.bubble")
                .font(.headline)

            Text(description)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

### 4. Conversation Thread & Quick Reply

```swift
// Features/Enquiries/Components/EnquiryConversation.swift
import SwiftUI

struct ConversationThread: View {
    let messages: [EnquiryMessage]
    let scrollProxy: ScrollViewProxy

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Conversation", systemImage: "bubble.left.and.bubble.right")
                .font(.headline)

            ForEach(messages) { message in
                MessageBubble(message: message)
                    .id(message.id)
            }
        }
        .onChange(of: messages.count) { _, _ in
            if let lastId = messages.last?.id {
                withAnimation {
                    scrollProxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: EnquiryMessage

    var body: some View {
        HStack {
            if message.isFromStaff {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isFromStaff ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .padding(12)
                    .background(message.isFromStaff ? Color.accentColor : Color(.systemGray5))
                    .foregroundStyle(message.isFromStaff ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 4) {
                    if message.isFromStaff {
                        Text(message.staffName ?? "You")
                    }
                    Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            if !message.isFromStaff {
                Spacer(minLength: 60)
            }
        }
    }
}

// Features/Enquiries/Components/QuickReplyBar.swift
struct QuickReplyBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let templates: [ReplyTemplate]

    @State private var showTemplates = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Quick templates (expandable)
            if showTemplates {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(templates) { template in
                            Button {
                                text = template.content
                                showTemplates = false
                            } label: {
                                Text(template.name)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.secondarySystemBackground))
            }

            // Input row
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showTemplates.toggle()
                    }
                } label: {
                    Image(systemName: "text.bubble")
                        .font(.title3)
                        .foregroundStyle(showTemplates ? .accentColor : .secondary)
                }

                TextField("Type a reply...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused(isFocused)

                Button {
                    onSend()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(text.isEmpty ? .gray : .accentColor)
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
    }
}

struct ReplyTemplate: Identifiable {
    let id: String
    let name: String
    let content: String
}
```

### 5. Convert to Order Sheet

```swift
// Features/Enquiries/Components/ConvertToOrderSheet.swift
import SwiftUI

struct ConvertToOrderSheet: View {
    let enquiry: Enquiry
    let onConvert: (ConvertOrderData) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedServices: Set<String> = []
    @State private var estimatedPrice = ""
    @State private var notes = ""
    @State private var priority: OrderPriority = .normal
    @State private var assignedTechnician: String?

    var body: some View {
        NavigationStack {
            Form {
                // Customer Info (read-only)
                Section("Customer") {
                    LabeledContent("Name", value: enquiry.customerName)
                    LabeledContent("Email", value: enquiry.customerEmail)
                    if let phone = enquiry.customerPhone {
                        LabeledContent("Phone", value: phone)
                    }
                }

                // Device Info (read-only)
                Section("Device") {
                    LabeledContent("Type", value: enquiry.deviceType.displayName)
                    LabeledContent("Brand", value: enquiry.deviceBrand)
                    LabeledContent("Model", value: enquiry.deviceModel)
                }

                // Issue (read-only)
                Section("Reported Issue") {
                    Text(enquiry.issueDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Services
                Section("Services") {
                    ForEach(ServiceType.allCases, id: \.self) { service in
                        Toggle(isOn: Binding(
                            get: { selectedServices.contains(service.rawValue) },
                            set: { if $0 { selectedServices.insert(service.rawValue) } else { selectedServices.remove(service.rawValue) } }
                        )) {
                            Label(service.displayName, systemImage: service.icon)
                        }
                    }
                }

                // Quote
                Section("Initial Quote") {
                    TextField("Estimated Price (£)", text: $estimatedPrice)
                        .keyboardType(.decimalPad)
                }

                // Priority & Assignment
                Section("Order Details") {
                    Picker("Priority", selection: $priority) {
                        ForEach(OrderPriority.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }

                    // Technician picker would go here
                }

                // Notes
                Section("Internal Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Create Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let data = ConvertOrderData(
                            enquiryId: enquiry.id,
                            services: Array(selectedServices),
                            estimatedPrice: Decimal(string: estimatedPrice),
                            priority: priority,
                            assignedTechnician: assignedTechnician,
                            notes: notes
                        )
                        onConvert(data)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct ConvertOrderData {
    let enquiryId: String
    let services: [String]
    let estimatedPrice: Decimal?
    let priority: OrderPriority
    let assignedTechnician: String?
    let notes: String
}
```

---

## Models

```swift
// Core/Models/Enquiry.swift
import Foundation
import SwiftUI

struct Enquiry: Identifiable, Codable {
    let id: String
    let customerName: String
    let customerEmail: String
    let customerPhone: String?
    let deviceType: DeviceType
    let deviceBrand: String
    let deviceModel: String
    let imei: String?
    let issueDescription: String
    let preferredContact: String?
    let status: EnquiryStatus
    let isRead: Bool
    let replyCount: Int
    let lastReply: EnquiryReply?
    let createdAt: Date
    let updatedAt: Date
}

struct EnquiryReply: Identifiable, Codable {
    let id: String
    let isFromStaff: Bool
    let staffName: String?
    let createdAt: Date
}

struct EnquiryMessage: Identifiable, Codable {
    let id: String
    let content: String
    let isFromStaff: Bool
    let staffName: String?
    let createdAt: Date
}

enum EnquiryStatus: String, Codable, CaseIterable {
    case new = "new"
    case pending = "pending"           // Awaiting staff response
    case awaitingCustomer = "awaiting_customer"
    case converted = "converted"       // Converted to order
    case spam = "spam"
    case archived = "archived"

    var displayName: String {
        switch self {
        case .new: return "New"
        case .pending: return "Pending Reply"
        case .awaitingCustomer: return "Awaiting Customer"
        case .converted: return "Converted"
        case .spam: return "Spam"
        case .archived: return "Archived"
        }
    }

    var shortName: String {
        switch self {
        case .new: return "New"
        case .pending: return "Pending"
        case .awaitingCustomer: return "Waiting"
        case .converted: return "Order"
        case .spam: return "Spam"
        case .archived: return "Done"
        }
    }

    var color: Color {
        switch self {
        case .new: return .blue
        case .pending: return .orange
        case .awaitingCustomer: return .purple
        case .converted: return .green
        case .spam: return .red
        case .archived: return .gray
        }
    }
}

enum EnquiryFilter: String, CaseIterable {
    case all = "all"
    case new = "new"
    case pending = "pending"
    case awaitingCustomer = "awaiting_customer"

    var displayName: String {
        switch self {
        case .all: return "All"
        case .new: return "New"
        case .pending: return "Needs Reply"
        case .awaitingCustomer: return "Waiting"
        }
    }
}

struct EnquiryStats {
    let newToday: Int
    let awaitingReply: Int
    let convertedThisWeek: Int
}

enum DeviceType: String, Codable, CaseIterable {
    case smartphone, tablet, laptop, desktop, console, other

    var displayName: String {
        switch self {
        case .smartphone: return "Smartphone"
        case .tablet: return "Tablet"
        case .laptop: return "Laptop"
        case .desktop: return "Desktop"
        case .console: return "Game Console"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .smartphone: return "iphone"
        case .tablet: return "ipad"
        case .laptop: return "laptopcomputer"
        case .desktop: return "desktopcomputer"
        case .console: return "gamecontroller"
        case .other: return "wrench.and.screwdriver"
        }
    }
}
```

---

## Test Cases

| Test | Expected |
|------|----------|
| Enquiry list loads | Shows all enquiries with status |
| Filter chips work | Filters update list correctly |
| Stats update | Reflects current counts |
| Unread indicator | Blue dot on unread items |
| Card tap | Opens enquiry detail |
| Reply sends | Message appears in thread |
| Templates work | Inserts template text |
| Convert to order | Creates order, marks converted |
| Mark as spam | Moves to spam |
| Archive | Removes from active list |

---

## Acceptance Checklist

- [ ] Enquiry list shows all enquiries
- [ ] Unread enquiries have visual indicator
- [ ] Filter chips filter correctly
- [ ] Stats header shows accurate counts
- [ ] Enquiry detail shows full info
- [ ] Conversation thread displays correctly
- [ ] Quick reply input works
- [ ] Reply templates load and apply
- [ ] Convert to order creates order
- [ ] Converted enquiries show status
- [ ] Context menu actions work
- [ ] Pull-to-refresh updates list
- [ ] Pagination loads more items
- [ ] Push notifications for new enquiries
- [ ] Real-time updates when app is open

---

## Handoff Notes

**Integrations:**
- Push notifications (Stage 11) - new enquiry, customer reply
- Orders module (Stage 07) - convert enquiry to order
- Customers may submit via Customer Portal (Stage 12)
