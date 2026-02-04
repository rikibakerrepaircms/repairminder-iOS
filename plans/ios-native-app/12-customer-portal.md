# Stage 12: Customer Portal

## Objective

Build a separate customer-facing interface for tracking repair orders, viewing status, communicating with the repair shop, **approving/rejecting quotes**, and **submitting new repair enquiries**.

---

## Dependencies

**Requires:** [See: Stage 03] complete - Authentication system exists
**Requires:** [See: Stage 11] complete - Push notifications work

---

## Complexity

**Medium** - Separate UI, customer-specific API endpoints

---

## Architecture Decision

Two options for customer portal:
1. **Separate Target** - Different app with shared code
2. **Tab/Mode Switch** - Same app, different interface based on user type

**Recommended: Separate Target** for App Store clarity and different branding.

---

## Files to Create

### New Target: Repair Minder Customer

| File | Purpose |
|------|---------|
| `Customer/CustomerApp.swift` | Customer app entry point |
| `Customer/CustomerContentView.swift` | Main customer interface |
| `Customer/Auth/CustomerLoginView.swift` | Customer login (email lookup) |
| `Customer/Auth/CustomerAuthManager.swift` | Customer auth (magic link/OTP) |
| `Customer/Orders/CustomerOrderListView.swift` | Customer's orders |
| `Customer/Orders/CustomerOrderDetailView.swift` | Order tracking view |
| `Customer/Orders/QuoteApprovalView.swift` | Approve/reject repair quotes |
| `Customer/Orders/QuoteApprovalCard.swift` | Quote card with action buttons |
| `Customer/Enquiries/NewEnquiryView.swift` | Submit new repair enquiry |
| `Customer/Enquiries/ShopPickerView.swift` | Select from previous shops |
| `Customer/Enquiries/EnquiryListView.swift` | Customer's enquiry history |
| `Customer/Enquiries/EnquiryDetailView.swift` | View enquiry status/replies |
| `Customer/Messages/ConversationView.swift` | Chat with repair shop |
| `Customer/Profile/CustomerProfileView.swift` | Customer profile/settings |

---

## Implementation Details

### 1. Customer App Entry Point

```swift
// Customer/CustomerApp.swift
import SwiftUI

@main
struct CustomerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = CustomerAuthManager()

    var body: some Scene {
        WindowGroup {
            CustomerContentView()
                .environmentObject(authManager)
        }
    }
}
```

### 2. Customer Content View

```swift
// Customer/CustomerContentView.swift
import SwiftUI

struct CustomerContentView: View {
    @EnvironmentObject var authManager: CustomerAuthManager

    var body: some View {
        Group {
            if authManager.isLoading {
                LoadingView(message: "Loading...")
            } else if authManager.isAuthenticated {
                CustomerMainView()
            } else {
                CustomerLoginView()
            }
        }
    }
}

struct CustomerMainView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CustomerOrderListView()
                .tabItem {
                    Label("Repairs", systemImage: "wrench.and.screwdriver.fill")
                }
                .tag(0)

            EnquiryListView()
                .tabItem {
                    Label("Enquiries", systemImage: "envelope.fill")
                }
                .tag(1)

            CustomerMessagesListView()
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(2)

            CustomerProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
    }
}
```

### 3. Customer Login (Magic Link)

```swift
// Customer/Auth/CustomerLoginView.swift
import SwiftUI

struct CustomerLoginView: View {
    @EnvironmentObject var authManager: CustomerAuthManager
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var showVerification = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Logo
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)

                    Text("Track Your Repair")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.top, 60)

                if showVerification {
                    // Verification Code Entry
                    VStack(spacing: 16) {
                        Text("Check your email")
                            .font(.headline)

                        Text("We sent a verification code to \(email)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        TextField("Enter code", text: $verificationCode)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.title2.monospaced())
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal, 60)

                        Button {
                            Task {
                                await authManager.verifyCode(email: email, code: verificationCode)
                            }
                        } label: {
                            if authManager.isLoading {
                                ProgressView()
                            } else {
                                Text("Verify")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(verificationCode.count < 6)
                        .padding(.horizontal)

                        Button("Use different email") {
                            showVerification = false
                            verificationCode = ""
                        }
                        .font(.subheadline)
                    }
                } else {
                    // Email Entry
                    VStack(spacing: 16) {
                        Text("Enter your email to view your repairs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("Email address", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)

                        if let error = authManager.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button {
                            Task {
                                let success = await authManager.requestCode(email: email)
                                if success {
                                    showVerification = true
                                }
                            }
                        } label: {
                            if authManager.isLoading {
                                ProgressView()
                            } else {
                                Text("Continue")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!email.isValidEmail)
                        .padding(.horizontal)
                    }
                }

                Spacer()
            }
        }
    }
}
```

### 4. Customer Auth Manager

```swift
// Customer/Auth/CustomerAuthManager.swift
import Foundation

@MainActor
final class CustomerAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var customerEmail: String?
    @Published var customerId: String?

    private let keychain = KeychainManager.shared

    init() {
        checkExistingSession()
    }

    private func checkExistingSession() {
        if let token = keychain.getString(for: .accessToken),
           let email = keychain.getString(for: .userId) {
            customerEmail = email
            isAuthenticated = true

            Task {
                await APIClient.shared.setAuthTokenProvider { [weak self] in
                    self?.keychain.getString(for: .accessToken)
                }
            }
        }
    }

    func requestCode(email: String) async -> Bool {
        isLoading = true
        error = nil

        struct RequestPayload: Encodable {
            let email: String
        }

        do {
            try await APIClient.shared.requestVoid(
                APIEndpoint(
                    path: "/api/customer/auth/request-magic-link",
                    method: .post,
                    body: RequestPayload(email: email)
                )
            )
            isLoading = false
            return true
        } catch {
            self.error = "Failed to send verification code"
            isLoading = false
            return false
        }
    }

    func verifyCode(email: String, code: String) async {
        isLoading = true
        error = nil

        struct VerifyPayload: Encodable {
            let email: String
            let code: String
        }

        struct VerifyResponse: Decodable {
            let token: String
            let customerId: String
        }

        do {
            let response: VerifyResponse = try await APIClient.shared.request(
                APIEndpoint(
                    path: "/api/customer/auth/verify-code",
                    method: .post,
                    body: VerifyPayload(email: email, code: code)
                ),
                responseType: VerifyResponse.self
            )

            try keychain.save(response.token, for: .accessToken)
            try keychain.save(email, for: .userId)

            customerEmail = email
            customerId = response.customerId
            isAuthenticated = true

            await APIClient.shared.setAuthTokenProvider { [weak self] in
                self?.keychain.getString(for: .accessToken)
            }
        } catch {
            self.error = "Invalid verification code"
        }

        isLoading = false
    }

    func logout() {
        keychain.deleteAll()
        customerEmail = nil
        customerId = nil
        isAuthenticated = false
    }
}
```

### 5. Customer Order List

```swift
// Customer/Orders/CustomerOrderListView.swift
import SwiftUI

struct CustomerOrderListView: View {
    @StateObject private var viewModel = CustomerOrderListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.orders.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No Repairs",
                        message: "You don't have any repair orders yet"
                    )
                } else {
                    List(viewModel.orders) { order in
                        NavigationLink(value: order.id) {
                            CustomerOrderRow(order: order)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Repairs")
            .navigationDestination(for: String.self) { orderId in
                CustomerOrderDetailView(orderId: orderId)
            }
            .refreshable {
                await viewModel.loadOrders()
            }
            .task {
                await viewModel.loadOrders()
            }
        }
    }
}

struct CustomerOrderRow: View {
    let order: CustomerOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(order.displayRef)
                    .font(.headline)

                Spacer()

                CustomerOrderStatusBadge(status: order.status)
            }

            Text(order.deviceSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("Dropped off \(order.createdAt.relativeFormatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
```

### 6. Customer Order Detail (Tracking)

```swift
// Customer/Orders/CustomerOrderDetailView.swift
import SwiftUI

struct CustomerOrderDetailView: View {
    let orderId: String
    @StateObject private var viewModel: CustomerOrderDetailViewModel

    init(orderId: String) {
        self.orderId = orderId
        _viewModel = StateObject(wrappedValue: CustomerOrderDetailViewModel(orderId: orderId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status Header
                if let order = viewModel.order {
                    OrderTrackingHeader(order: order)

                    // Timeline
                    OrderTimeline(events: viewModel.timeline)

                    // Devices
                    DevicesStatusSection(devices: viewModel.devices)

                    // Payment Summary
                    if order.balance ?? 0 > 0 {
                        PaymentDueCard(balance: order.balance ?? 0)
                    }

                    // Contact Button
                    Button {
                        // Open conversation
                    } label: {
                        Label("Contact Shop", systemImage: "message.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(viewModel.order?.displayRef ?? "Order")
        .task {
            await viewModel.loadOrder()
        }
    }
}

struct OrderTrackingHeader: View {
    let order: CustomerOrder

    var body: some View {
        VStack(spacing: 16) {
            // Large status icon
            Image(systemName: order.status.icon)
                .font(.system(size: 60))
                .foregroundStyle(order.status.color)

            Text(order.status.customerDisplayName)
                .font(.title2)
                .fontWeight(.bold)

            Text(order.status.customerDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct OrderTimeline: View {
    let events: [TimelineEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(events) { event in
                TimelineRow(event: event, isLast: event.id == events.last?.id)
            }
        }
        .padding(.horizontal)
    }
}

struct TimelineRow: View {
    let event: TimelineEvent
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(event.isCompleted ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)

                if !isLast {
                    Rectangle()
                        .fill(event.isCompleted ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 2, height: 40)
                }
            }

            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let date = event.date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, isLast ? 0 : 20)

            Spacer()
        }
    }
}

struct TimelineEvent: Identifiable {
    let id: String
    let title: String
    let date: Date?
    let isCompleted: Bool
}
```

### 7. Quote Approval View (Authorize/Reject)

```swift
// Customer/Orders/QuoteApprovalView.swift
import SwiftUI

struct QuoteApprovalView: View {
    let order: CustomerOrder
    @StateObject private var viewModel: QuoteApprovalViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showRejectReason = false
    @State private var rejectReason = ""

    init(order: CustomerOrder) {
        self.order = order
        _viewModel = StateObject(wrappedValue: QuoteApprovalViewModel(orderId: order.id))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Quote Header
                    QuoteHeader(order: order)

                    // Device Breakdown
                    if let quote = viewModel.quote {
                        QuoteBreakdownCard(quote: quote)

                        // Total
                        QuoteTotalCard(quote: quote)

                        // Terms
                        QuoteTermsSection()

                        // Action Buttons
                        QuoteActionButtons(
                            onApprove: {
                                Task {
                                    await viewModel.approveQuote()
                                    dismiss()
                                }
                            },
                            onReject: {
                                showRejectReason = true
                            },
                            isLoading: viewModel.isLoading
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Review Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await viewModel.loadQuote()
            }
            .sheet(isPresented: $showRejectReason) {
                RejectReasonSheet(
                    reason: $rejectReason,
                    onSubmit: {
                        Task {
                            await viewModel.rejectQuote(reason: rejectReason)
                            dismiss()
                        }
                    }
                )
            }
        }
    }
}

struct QuoteHeader: View {
    let order: CustomerOrder

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("Quote Ready for Approval")
                .font(.title2)
                .fontWeight(.bold)

            Text("Order \(order.displayRef)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct QuoteBreakdownCard: View {
    let quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Repair Details")
                .font(.headline)

            ForEach(quote.items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.description)
                            .font(.subheadline)
                        if let device = item.deviceName {
                            Text(device)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Text("£\(item.price.formatted())")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                if item.id != quote.items.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QuoteTotalCard: View {
    let quote: Quote

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Subtotal")
                Spacer()
                Text("£\(quote.subtotal.formatted())")
            }
            .font(.subheadline)

            if quote.vat > 0 {
                HStack {
                    Text("VAT (20%)")
                    Spacer()
                    Text("£\(quote.vat.formatted())")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text("Total")
                    .fontWeight(.bold)
                Spacer()
                Text("£\(quote.total.formatted())")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            if quote.depositPaid > 0 {
                HStack {
                    Text("Deposit Paid")
                    Spacer()
                    Text("-£\(quote.depositPaid.formatted())")
                }
                .font(.subheadline)
                .foregroundStyle(.green)

                HStack {
                    Text("Balance Due")
                        .fontWeight(.medium)
                    Spacer()
                    Text("£\(quote.balanceDue.formatted())")
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QuoteActionButtons: View {
    let onApprove: () -> Void
    let onReject: () -> Void
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 12) {
            Button {
                onApprove()
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Approve Quote", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)

            Button(role: .destructive) {
                onReject()
            } label: {
                Label("Decline Quote", systemImage: "xmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

struct RejectReasonSheet: View {
    @Binding var reason: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Please tell us why you're declining this quote")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextEditor(text: $reason)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()
            }
            .padding()
            .navigationTitle("Decline Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        onSubmit()
                    }
                    .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
```

### 8. New Enquiry Submission

```swift
// Customer/Enquiries/NewEnquiryView.swift
import SwiftUI

struct NewEnquiryView: View {
    @StateObject private var viewModel = NewEnquiryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedShop: Shop?
    @State private var deviceType = ""
    @State private var deviceBrand = ""
    @State private var deviceModel = ""
    @State private var issueDescription = ""
    @State private var preferredContact: ContactMethod = .email
    @State private var showShopPicker = false

    enum ContactMethod: String, CaseIterable {
        case email, phone, whatsapp

        var displayName: String {
            switch self {
            case .email: return "Email"
            case .phone: return "Phone Call"
            case .whatsapp: return "WhatsApp"
            }
        }

        var icon: String {
            switch self {
            case .email: return "envelope.fill"
            case .phone: return "phone.fill"
            case .whatsapp: return "message.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Shop Selection
                Section {
                    Button {
                        showShopPicker = true
                    } label: {
                        HStack {
                            if let shop = selectedShop {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(shop.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text("Used \(shop.orderCount) times")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Select a repair shop")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("Repair Shop")
                } footer: {
                    Text("Choose from shops you've used before")
                }

                // Device Info
                Section("Device Information") {
                    Picker("Device Type", selection: $deviceType) {
                        Text("Select type").tag("")
                        Text("Smartphone").tag("smartphone")
                        Text("Tablet").tag("tablet")
                        Text("Laptop").tag("laptop")
                        Text("Desktop").tag("desktop")
                        Text("Game Console").tag("console")
                        Text("Other").tag("other")
                    }

                    TextField("Brand", text: $deviceBrand)
                        .textContentType(.organizationName)

                    TextField("Model", text: $deviceModel)
                }

                // Issue Description
                Section {
                    TextEditor(text: $issueDescription)
                        .frame(minHeight: 100)
                } header: {
                    Text("What's wrong?")
                } footer: {
                    Text("Describe the issue in detail. Include when it started, any error messages, and what you've already tried.")
                }

                // Contact Preference
                Section("Preferred Contact Method") {
                    ForEach(ContactMethod.allCases, id: \.self) { method in
                        Button {
                            preferredContact = method
                        } label: {
                            HStack {
                                Image(systemName: method.icon)
                                    .frame(width: 24)
                                Text(method.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if preferredContact == method {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Enquiry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            await submitEnquiry()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
            .sheet(isPresented: $showShopPicker) {
                ShopPickerView(selectedShop: $selectedShop)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Submitting...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    var isFormValid: Bool {
        selectedShop != nil &&
        !deviceType.isEmpty &&
        !deviceBrand.isEmpty &&
        !issueDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func submitEnquiry() async {
        guard let shop = selectedShop else { return }

        let success = await viewModel.submitEnquiry(
            shopId: shop.id,
            deviceType: deviceType,
            deviceBrand: deviceBrand,
            deviceModel: deviceModel,
            issue: issueDescription,
            contactMethod: preferredContact.rawValue
        )

        if success {
            dismiss()
        }
    }
}

// Customer/Enquiries/ShopPickerView.swift
struct ShopPickerView: View {
    @Binding var selectedShop: Shop?
    @StateObject private var viewModel = ShopPickerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.previousShops.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Previous Shops",
                        systemImage: "building.2",
                        description: Text("You haven't used any repair shops yet")
                    )
                } else {
                    ForEach(viewModel.previousShops) { shop in
                        Button {
                            selectedShop = shop
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(shop.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text(shop.address ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 8) {
                                        Label("\(shop.orderCount) orders", systemImage: "doc.text")
                                        if let lastUsed = shop.lastOrderDate {
                                            Text("•")
                                            Text("Last: \(lastUsed.relativeFormatted())")
                                        }
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                }

                                Spacer()

                                if selectedShop?.id == shop.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.accentColor)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Select Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await viewModel.loadPreviousShops()
            }
        }
    }
}
```

### 9. Customer Enquiry List

```swift
// Customer/Enquiries/EnquiryListView.swift
import SwiftUI

struct EnquiryListView: View {
    @StateObject private var viewModel = CustomerEnquiryListViewModel()
    @State private var showNewEnquiry = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.enquiries.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView {
                        Label("No Enquiries", systemImage: "envelope")
                    } description: {
                        Text("Submit an enquiry to get a repair quote")
                    } actions: {
                        Button("New Enquiry") {
                            showNewEnquiry = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(viewModel.enquiries) { enquiry in
                        NavigationLink(value: enquiry.id) {
                            EnquiryRow(enquiry: enquiry)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Enquiries")
            .navigationDestination(for: String.self) { enquiryId in
                EnquiryDetailView(enquiryId: enquiryId)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewEnquiry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await viewModel.loadEnquiries()
            }
            .task {
                await viewModel.loadEnquiries()
            }
            .sheet(isPresented: $showNewEnquiry) {
                NewEnquiryView()
            }
        }
    }
}

struct EnquiryRow: View {
    let enquiry: CustomerEnquiry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(enquiry.shopName)
                    .font(.headline)

                Spacer()

                EnquiryStatusBadge(status: enquiry.status)
            }

            Text("\(enquiry.deviceBrand) \(enquiry.deviceModel)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(enquiry.issueDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)

            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(enquiry.createdAt.relativeFormatted())
                    .font(.caption)
            }
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct EnquiryStatusBadge: View {
    let status: CustomerEnquiryStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }
}
```

### 10. Update Order Detail for Quote Approval

```swift
// Add to CustomerOrderDetailView when status is awaitingApproval
struct CustomerOrderDetailView: View {
    // ... existing code ...

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let order = viewModel.order {
                    OrderTrackingHeader(order: order)

                    // QUOTE APPROVAL CARD - Shows when awaiting approval
                    if order.status == .awaitingApproval {
                        QuoteApprovalCard(
                            order: order,
                            onApprove: {
                                Task { await viewModel.approveQuote() }
                            },
                            onReject: {
                                showRejectSheet = true
                            }
                        )
                    }

                    OrderTimeline(events: viewModel.timeline)
                    DevicesStatusSection(devices: viewModel.devices)

                    // ... rest of existing code ...
                }
            }
        }
    }
}

// Inline approval card for order detail
struct QuoteApprovalCard: View {
    let order: CustomerOrder
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Alert banner
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Action Required")
                        .font(.headline)
                    Text("Please review and approve the repair quote")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Quote summary
            if let total = order.total {
                HStack {
                    Text("Quoted Total")
                        .font(.subheadline)
                    Spacer()
                    Text("£\(total.formatted())")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .padding(.horizontal)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    onReject()
                } label: {
                    Label("Decline", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onApprove()
                } label: {
                    Label("Approve", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
```

---

## Customer-Specific Models

```swift
// Quote model for approval
struct Quote: Identifiable, Codable {
    let id: String
    let items: [QuoteItem]
    let subtotal: Decimal
    let vat: Decimal
    let total: Decimal
    let depositPaid: Decimal
    let balanceDue: Decimal
    let validUntil: Date?
}

struct QuoteItem: Identifiable, Codable {
    let id: String
    let description: String
    let deviceName: String?
    let price: Decimal
}

// Shop model for enquiry submission
struct Shop: Identifiable, Codable {
    let id: String
    let name: String
    let address: String?
    let orderCount: Int
    let lastOrderDate: Date?
}

// Customer enquiry model
struct CustomerEnquiry: Identifiable, Codable {
    let id: String
    let shopId: String
    let shopName: String
    let deviceType: String
    let deviceBrand: String
    let deviceModel: String
    let issueDescription: String
    let status: CustomerEnquiryStatus
    let createdAt: Date
    let replies: [EnquiryReply]?
}

struct EnquiryReply: Identifiable, Codable {
    let id: String
    let message: String
    let isFromShop: Bool
    let createdAt: Date
}

enum CustomerEnquiryStatus: String, Codable {
    case pending = "pending"
    case responded = "responded"
    case converted = "converted"      // Converted to order
    case closed = "closed"

    var displayName: String {
        switch self {
        case .pending: return "Awaiting Reply"
        case .responded: return "Shop Replied"
        case .converted: return "Order Created"
        case .closed: return "Closed"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .responded: return .blue
        case .converted: return .green
        case .closed: return .gray
        }
    }
}

// Customer order with customer-friendly status descriptions
struct CustomerOrder: Identifiable, Codable {
    let id: String
    let orderNumber: Int
    let status: CustomerOrderStatus
    let deviceSummary: String
    let total: Decimal?
    let deposit: Decimal?
    let balance: Decimal?
    let createdAt: Date

    var displayRef: String { "#\(orderNumber)" }
}

enum CustomerOrderStatus: String, Codable {
    case received = "booked_in"
    case diagnosing = "diagnosing"
    case awaitingApproval = "awaiting_approval"
    case inRepair = "in_progress"
    case awaitingParts = "awaiting_parts"
    case qualityCheck = "quality_check"
    case ready = "ready"
    case collected = "collected"

    var customerDisplayName: String {
        switch self {
        case .received: return "Received"
        case .diagnosing: return "Being Diagnosed"
        case .awaitingApproval: return "Approval Needed"
        case .inRepair: return "Being Repaired"
        case .awaitingParts: return "Waiting for Parts"
        case .qualityCheck: return "Final Checks"
        case .ready: return "Ready for Collection"
        case .collected: return "Collected"
        }
    }

    var customerDescription: String {
        switch self {
        case .received: return "We've received your device and it's in our queue"
        case .diagnosing: return "Our technician is examining your device"
        case .awaitingApproval: return "Please review and approve the repair quote"
        case .inRepair: return "Your device is being repaired"
        case .awaitingParts: return "We're waiting for parts to arrive"
        case .qualityCheck: return "We're running final quality checks"
        case .ready: return "Your device is ready! Come collect it anytime"
        case .collected: return "Thanks for choosing us!"
        }
    }

    var icon: String {
        switch self {
        case .received: return "tray.and.arrow.down.fill"
        case .diagnosing: return "magnifyingglass"
        case .awaitingApproval: return "hand.raised.fill"
        case .inRepair: return "wrench.and.screwdriver.fill"
        case .awaitingParts: return "shippingbox.fill"
        case .qualityCheck: return "checkmark.shield.fill"
        case .ready: return "checkmark.circle.fill"
        case .collected: return "hand.thumbsup.fill"
        }
    }

    var color: Color {
        switch self {
        case .received: return .blue
        case .diagnosing: return .orange
        case .awaitingApproval: return .yellow
        case .inRepair: return .purple
        case .awaitingParts: return .gray
        case .qualityCheck: return .teal
        case .ready: return .green
        case .collected: return .gray
        }
    }
}
```

---

## Test Cases

| Test | Expected |
|------|----------|
| Email entry | Sends verification code |
| Code verification | Logs in customer |
| Order list | Shows customer's orders |
| Order tracking | Shows status timeline |
| Device status | Shows each device |
| Contact button | Opens conversation |
| **Quote approval** | **Shows when awaiting approval** |
| **Approve quote** | **Status changes, confirmation shown** |
| **Reject quote** | **Requires reason, status changes** |
| **New enquiry** | **Form validates, submits to shop** |
| **Shop picker** | **Shows previous shops only** |
| **Enquiry list** | **Shows all customer enquiries** |
| **Enquiry status** | **Updates when shop replies** |
| Logout | Clears session |

---

## Acceptance Checklist

- [ ] Customer login via email verification works
- [ ] Session persists across app launches
- [ ] Order list shows only customer's orders
- [ ] Order tracking shows friendly status
- [ ] Timeline displays order history
- [ ] Device status visible
- [ ] Payment balance shown if due
- [ ] Contact/messaging works
- [ ] Push notifications for customer
- [ ] **Quote approval card shows for awaiting_approval orders**
- [ ] **Approve quote updates status and notifies shop**
- [ ] **Reject quote requires reason and updates status**
- [ ] **New enquiry form validates all required fields**
- [ ] **Shop picker shows only previously used shops**
- [ ] **Enquiry list displays with status badges**
- [ ] **Enquiry detail shows conversation history**
- [ ] **Push notification when shop replies to enquiry**
- [ ] Logout clears everything

---

## Handoff Notes

**For Stage 13:**
- Shared components can be reused
- Different notification preferences for customers
