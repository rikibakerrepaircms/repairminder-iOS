# Stage 1: Models, API Endpoints & PaymentService

## Objective

Add all POS-related Decodable/Encodable models, new `APIEndpoints` cases, a `PaymentService` class with all payment API methods, and extend `OrderDetailViewModel` with payment-related methods. This is the foundation stage — no UI changes.

## Dependencies

None — this is the foundation stage.

## Complexity

Medium

## Files to Modify

| File | Changes |
|------|---------|
| `Core/Models/Order.swift` | Add `ManualPaymentRequest` Encodable struct, `DevicePaymentBreakdown` Decodable struct |
| `Core/Networking/APIEndpoints.swift` | Add 9 new POS endpoint cases |

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Models/PosModels.swift` | All POS-related Decodable/Encodable types |
| `Core/Services/PaymentService.swift` | Payment API methods (manual + POS + links) |

## Implementation Details

### 1. `PosModels.swift` — New File

```swift
import Foundation

// MARK: - POS Integration

struct PosIntegration: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let provider: String           // "revolut", "square", "sumup", "dojo"
    let displayName: String?
    let environment: String?       // "production", "sandbox"
    let isActive: Bool?
    let config: PosIntegrationConfig?
}

struct PosIntegrationConfig: Decodable, Equatable, Sendable {
    let locationId: String?
}

// MARK: - POS Terminal

struct PosTerminal: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let integrationId: String?
    let providerTerminalId: String?
    let displayName: String
    let provider: String           // "revolut", "square", "sumup", "dojo"
    let isActive: Bool?

    var providerLabel: String {
        switch provider {
        case "revolut": return "Revolut"
        case "square": return "Square"
        case "sumup": return "SumUp"
        case "dojo": return "Dojo"
        default: return provider.capitalized
        }
    }

    var providerIcon: String {
        switch provider {
        case "revolut": return "creditcard.trianglebadge.exclamationmark"
        case "square": return "square"
        case "sumup": return "wave.3.right"
        case "dojo": return "creditcard"
        default: return "creditcard"
        }
    }
}

// MARK: - POS Transaction Status

enum PosTransactionStatus: String, Codable, Sendable {
    case pending
    case processing
    case completed
    case failed
    case cancelled
    case timeout

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled, .timeout: return true
        case .pending, .processing: return false
        }
    }

    var label: String {
        switch self {
        case .pending: return "Waiting for card..."
        case .processing: return "Processing..."
        case .completed: return "Payment Successful"
        case .failed: return "Payment Failed"
        case .cancelled: return "Payment Cancelled"
        case .timeout: return "Payment Timed Out"
        }
    }
}

// MARK: - POS Transaction (poll response)

struct PosTransactionPollResponse: Decodable, Sendable {
    let transactionId: String
    let orderId: String?
    let status: PosTransactionStatus
    let amount: Int              // pence
    let currency: String?
    let cardBrand: String?
    let cardLastFour: String?
    let failureReason: String?
    let createdAt: String?
    let completedAt: String?
}

// MARK: - Initiate Terminal Payment

struct InitiateTerminalPaymentRequest: Encodable {
    let orderId: String
    let terminalId: String
    let amount: Int              // pence
    let currency: String
    let deviceIds: [String]?
    let isDeposit: Bool?
}

struct InitiateTerminalPaymentResponse: Decodable, Sendable {
    let transactionId: String
    let providerOrderId: String?
    let paymentIntentId: String?
    let status: String?
    let provider: String?
    let terminalId: String?
}

// MARK: - Payment Link

struct PosPaymentLink: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let provider: String?
    let checkoutUrl: String
    let amount: Int              // pence
    let currency: String?
    let status: PaymentLinkStatus
    let createdAt: String?
    let completedAt: String?
    let cancelledAt: String?
    let lastEmailSentAt: String?

    var formattedAmount: String {
        CurrencyFormatter.format(Double(amount) / 100.0)
    }

    var formattedCreatedAt: String? {
        DateFormatters.formatRelativeDate(createdAt)
    }
}

enum PaymentLinkStatus: String, Codable, Sendable {
    case pending
    case completed
    case failed
    case cancelled
    case expired
}

struct CreatePaymentLinkRequest: Encodable {
    let orderId: String
    let amount: Int              // pence
    let currency: String
    let customerEmail: String?
    let description: String?
    let deviceIds: [String]?
    let isDeposit: Bool?
}

struct CreatePaymentLinkResponse: Decodable, Sendable {
    let paymentLinkId: String
    let checkoutUrl: String
    let amount: Int
    let currency: String?
    let emailSent: Bool?
    let alreadyExists: Bool?
}
```

### 2. `ManualPaymentRequest` in `Order.swift`

Add after `OrderItemRequest`:

```swift
// MARK: - Manual Payment Request

/// Request body for recording a manual payment (cash, bank transfer, etc.).
struct ManualPaymentRequest: Encodable {
    var amount: Double           // Currency units (pounds)
    var paymentMethod: String    // "cash", "bank_transfer", "invoice", etc.
    var paymentDate: String      // ISO date "YYYY-MM-DD"
    var notes: String?
    var deviceId: String?
    var isDeposit: Bool?
    var isPayout: Bool?
}
```

Also add `DevicePaymentBreakdown` for the payment response:

```swift
// MARK: - Device Payment Breakdown

struct DevicePaymentBreakdown: Decodable, Equatable, Sendable {
    let deviceId: String
    let displayName: String?
    let lineTotal: Double?
    let depositsPaid: Double?
    let finalPaid: Double?
    let totalPaid: Double?
    let balanceDue: Double?
}
```

### 3. `APIEndpoints.swift` — New Cases

Add these cases to the `APIEndpoints` enum:

```swift
// POS Integrations & Terminals
case posIntegrations                                        // GET /api/pos/integrations
case posTerminals(locationId: String?)                      // GET /api/pos/terminals?location_id=X

// POS Terminal Payments
case initiateTerminalPayment                                // POST /api/pos/payments
case pollTerminalPayment(transactionId: String)             // GET /api/pos/payments/:id/status
case cancelTerminalPayment(transactionId: String)           // POST /api/pos/payments/:id/cancel

// POS Payment Links
case paymentLinks(orderId: String)                          // GET /api/pos/payment-links?order_id=X
case createPaymentLink                                      // POST /api/pos/payment-links
case cancelPaymentLink(linkId: String)                      // POST /api/pos/payment-links/:id/cancel
case resendPaymentLinkEmail(linkId: String)                 // POST /api/pos/payment-links/:id/resend
```

Update the `path` computed property:

```swift
case .posIntegrations: return "/api/pos/integrations"
case .posTerminals: return "/api/pos/terminals"
case .initiateTerminalPayment: return "/api/pos/payments"
case .pollTerminalPayment(let id): return "/api/pos/payments/\(id)/status"
case .cancelTerminalPayment(let id): return "/api/pos/payments/\(id)/cancel"
case .paymentLinks: return "/api/pos/payment-links"
case .createPaymentLink: return "/api/pos/payment-links"
case .cancelPaymentLink(let id): return "/api/pos/payment-links/\(id)/cancel"
case .resendPaymentLinkEmail(let id): return "/api/pos/payment-links/\(id)/resend"
```

Update the `method` computed property:

```swift
case .posIntegrations, .posTerminals, .pollTerminalPayment, .paymentLinks:
    return .get
case .initiateTerminalPayment, .createPaymentLink, .cancelTerminalPayment,
     .cancelPaymentLink, .resendPaymentLinkEmail:
    return .post
```

Update the `queryItems` computed property for `posTerminals` and `paymentLinks`:

```swift
case .posTerminals(let locationId):
    if let locationId {
        return [URLQueryItem(name: "location_id", value: locationId)]
    }
    return nil
case .paymentLinks(let orderId):
    return [URLQueryItem(name: "order_id", value: orderId)]
```

### 4. `PaymentService.swift` — New File

```swift
import Foundation

@MainActor
final class PaymentService: ObservableObject {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - Manual Payments

    /// Record a manual payment (cash, bank transfer, invoice, etc.)
    func recordManualPayment(orderId: String, request: ManualPaymentRequest) async throws -> OrderPayment {
        try await apiClient.request(
            .createOrderPayment(orderId: orderId),
            body: request
        )
    }

    /// Delete a recorded payment
    func deletePayment(orderId: String, paymentId: String) async throws {
        try await apiClient.requestVoid(
            .deleteOrderPayment(orderId: orderId, paymentId: paymentId)
        )
    }

    // MARK: - POS Integrations & Terminals

    /// Check if the company has any POS integrations configured
    func fetchIntegrations() async throws -> [PosIntegration] {
        try await apiClient.request(.posIntegrations)
    }

    /// List available terminals, optionally filtered by location
    func fetchTerminals(locationId: String? = nil) async throws -> [PosTerminal] {
        try await apiClient.request(.posTerminals(locationId: locationId))
    }

    // MARK: - Terminal Payments

    /// Initiate a card payment on a POS terminal
    func initiateTerminalPayment(_ request: InitiateTerminalPaymentRequest) async throws -> InitiateTerminalPaymentResponse {
        try await apiClient.request(.initiateTerminalPayment, body: request)
    }

    /// Poll for terminal payment status (call every 2s)
    func pollPaymentStatus(transactionId: String) async throws -> PosTransactionPollResponse {
        try await apiClient.request(.pollTerminalPayment(transactionId: transactionId))
    }

    /// Cancel a pending terminal payment
    func cancelTerminalPayment(transactionId: String) async throws {
        try await apiClient.requestVoid(.cancelTerminalPayment(transactionId: transactionId))
    }

    // MARK: - Payment Links

    /// Create a payment link (checkout URL) for remote payment
    func createPaymentLink(_ request: CreatePaymentLinkRequest) async throws -> CreatePaymentLinkResponse {
        try await apiClient.request(.createPaymentLink, body: request)
    }

    /// Fetch payment links for an order
    func fetchPaymentLinks(orderId: String) async throws -> [PosPaymentLink] {
        try await apiClient.request(.paymentLinks(orderId: orderId))
    }

    /// Cancel a pending payment link
    func cancelPaymentLink(linkId: String) async throws {
        try await apiClient.requestVoid(.cancelPaymentLink(linkId: linkId))
    }

    /// Resend the payment link email
    func resendPaymentLinkEmail(linkId: String) async throws {
        try await apiClient.requestVoid(.resendPaymentLinkEmail(linkId: linkId))
    }
}
```

### 5. `OrderDetailViewModel.swift` — Payment Extensions

Add to existing ViewModel:

```swift
// MARK: - Payment State

@Published private(set) var isSavingPayment = false
@Published private(set) var isDeletingPayment = false
@Published private(set) var paymentError: String?
@Published private(set) var posIntegrations: [PosIntegration] = []
@Published private(set) var posTerminals: [PosTerminal] = []
@Published private(set) var paymentLinks: [PosPaymentLink] = []

private let paymentService = PaymentService()

var hasPosIntegrations: Bool {
    !posIntegrations.isEmpty
}

var hasActiveTerminals: Bool {
    posTerminals.contains { $0.isActive == true }
}

var balanceDue: Double {
    order?.totals?.balanceDue ?? order?.balanceDue ?? 0
}

var depositsEnabled: Bool {
    order?.company?.depositsEnabled == 1
}

// MARK: - Payment Methods

/// Record a manual payment. Returns true on success.
func recordPayment(_ request: ManualPaymentRequest) async -> Bool {
    guard let orderId = order?.id else { return false }
    isSavingPayment = true
    paymentError = nil
    defer { isSavingPayment = false }
    do {
        _ = try await paymentService.recordManualPayment(orderId: orderId, request: request)
        await refresh()
        return true
    } catch let error as APIError {
        paymentError = error.localizedDescription
        return false
    } catch {
        paymentError = error.localizedDescription
        return false
    }
}

/// Delete a payment. Returns true on success.
func deletePayment(paymentId: String) async -> Bool {
    guard let orderId = order?.id else { return false }
    isDeletingPayment = true
    paymentError = nil
    defer { isDeletingPayment = false }
    do {
        try await paymentService.deletePayment(orderId: orderId, paymentId: paymentId)
        await refresh()
        return true
    } catch let error as APIError {
        paymentError = error.localizedDescription
        return false
    } catch {
        paymentError = error.localizedDescription
        return false
    }
}

/// Load POS integrations and terminals for the company
func loadPosConfig(locationId: String? = nil) async {
    do {
        async let integrations = paymentService.fetchIntegrations()
        async let terminals = paymentService.fetchTerminals(locationId: locationId)
        posIntegrations = try await integrations
        posTerminals = try await terminals
    } catch {
        // Silently fail — POS buttons just won't appear
        posIntegrations = []
        posTerminals = []
    }
}

/// Load payment links for the current order
func loadPaymentLinks() async {
    guard let orderId = order?.id else { return }
    do {
        paymentLinks = try await paymentService.fetchPaymentLinks(orderId: orderId)
    } catch {
        paymentLinks = []
    }
}

func clearPaymentError() {
    paymentError = nil
}
```

**Important:** The `loadPosConfig()` call should be added to the existing `loadOrder()` method — after the order loads successfully, fire `loadPosConfig(locationId:)` and `loadPaymentLinks()` concurrently. The `locationId` comes from the user's selected location (already available in the app's auth context).

## Database Changes

None — all API endpoints already exist.

## Test Cases

| Scenario | Input | Expected Output |
|----------|-------|-----------------|
| Fetch POS integrations | Company with Revolut | `posIntegrations` contains 1 integration with `provider: "revolut"` |
| Fetch POS integrations — no POS | Company without POS | `posIntegrations` empty, `hasPosIntegrations == false` |
| Fetch terminals with location | Valid `location_id` | Filtered terminal list |
| Record manual payment | Valid `ManualPaymentRequest` | Returns `true`, order refreshed, `balanceDue` decreased |
| Record payment — overpayment | Amount > balance | Returns `false`, `paymentError` set |
| Delete payment | Valid payment ID | Returns `true`, order refreshed |
| `depositsEnabled` — enabled | Company has `depositsEnabled: 1` | `true` |
| `depositsEnabled` — disabled | Company has `depositsEnabled: 0` | `false` |
| App builds | — | No warnings, all existing tests pass |

## Acceptance Checklist

- [ ] `PosModels.swift` created with: `PosIntegration`, `PosTerminal`, `PosTransactionStatus`, `PosTransactionPollResponse`, `InitiateTerminalPaymentRequest`, `InitiateTerminalPaymentResponse`, `PosPaymentLink`, `PaymentLinkStatus`, `CreatePaymentLinkRequest`, `CreatePaymentLinkResponse`
- [ ] `ManualPaymentRequest` added to `Order.swift`
- [ ] `DevicePaymentBreakdown` added to `Order.swift`
- [ ] 9 new cases added to `APIEndpoints.swift` with correct paths, methods, and query items
- [ ] `PaymentService.swift` created with 10 methods
- [ ] `OrderDetailViewModel` extended with payment state properties and 5 methods
- [ ] `loadPosConfig()` and `loadPaymentLinks()` called during order load
- [ ] All types conform to `Sendable`
- [ ] App builds without warnings
- [ ] Existing order detail loading still works

## Deployment

No deployment — iOS code only. Build and run on simulator, open an order detail to verify:
1. Order loads as before (no regression)
2. `posIntegrations` and `posTerminals` populated (check via debug print or breakpoint)

## Handoff Notes

After this stage, all three parallel stages can begin:
- **Stage 2** needs: `ManualPaymentRequest`, `viewModel.recordPayment()`, `viewModel.deletePayment()`, `viewModel.depositsEnabled`
- **Stage 3** needs: All POS models, `PaymentService` terminal methods, `viewModel.posTerminals`, `viewModel.hasPosIntegrations`
- **Stage 4** needs: `ManualPaymentRequest` (with `isPayout: true`), `viewModel.recordPayment()`
