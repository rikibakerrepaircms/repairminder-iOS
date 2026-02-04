# Stage 12: Customer Orders & Quote Approval

## Objective

Fix customer order views and implement proper quote approval with signature capture.

## Dependencies

- **Requires**: Stage 11 complete (Customer auth working)
- **Requires**: Stage 03 complete (Order model)

## Complexity

**High** - Quote approval needs signature UI, model changes needed

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Customer/Orders/CustomerOrderListView.swift` | Update bindings |
| `Repair Minder/Customer/Orders/CustomerOrderListViewModel.swift` | Fix API calls |
| `Repair Minder/Customer/Orders/CustomerOrderDetailView.swift` | Major updates |
| `Repair Minder/Customer/Orders/CustomerOrderDetailViewModel.swift` | Remove non-existent endpoints |
| `Repair Minder/Customer/Orders/QuoteApprovalView.swift` | Add signature capture |

## Files to Create

| File | Purpose |
|------|---------|
| `Repair Minder/Customer/Components/SignatureView.swift` | Signature capture UI |
| `Repair Minder/Customer/Models/CustomerOrder.swift` | Customer-specific order model |

## Backend Reference

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `GET /api/customer/orders` | GET | List customer's orders |
| `GET /api/customer/orders/:id` | GET | Order detail with everything |
| `POST /api/customer/orders/:id/approve` | POST | Approve/reject quote |
| `POST /api/customer/orders/:id/reply` | POST | Send message |

### Order Detail Response

The order detail endpoint returns ALL data needed - no separate timeline or quote endpoints:

```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "ticket_number": 12345,
    "status": "awaiting_approval",
    "quote_sent_at": "2026-02-04T10:00:00.000Z",
    "quote_approved_at": null,
    "rejected_at": null,
    "devices": [
      {
        "id": "uuid",
        "display_name": "iPhone 14 Pro",
        "status": "diagnosing",
        "workflow_type": "repair",
        "customer_reported_issues": "Cracked screen",
        "authorization_status": "pending",
        "items": [
          {
            "description": "Screen Replacement",
            "quantity": 1,
            "unit_price": 149.99,
            "vat_rate": 0.2,
            "line_total": 149.99,
            "line_total_inc_vat": 179.99
          }
        ]
      }
    ],
    "items": [...],
    "totals": {
      "subtotal": 149.99,
      "vat_total": 30.00,
      "grand_total": 179.99,
      "amount_paid": 0,
      "balance_due": 179.99
    },
    "messages": [...],
    "company": {
      "name": "Repair Shop",
      "phone": "123-456-7890",
      "currency_code": "GBP"
    }
  }
}
```

### Approve Endpoint Request

```json
{
  "action": "approve",           // or "reject"
  "signature_type": "typed",     // or "drawn"
  "signature_data": "John Doe",  // typed name or base64 image
  "amount_acknowledged": 179.99, // total being approved
  "rejection_reason": null       // only for reject
}
```

## Implementation Details

### 1. CustomerOrder Model

```swift
// Repair Minder/Customer/Models/CustomerOrder.swift

import Foundation

struct CustomerOrder: Identifiable, Codable {
    let id: String
    let ticketNumber: Int
    let status: String
    let quoteSentAt: Date?
    let quoteApprovedAt: Date?
    let rejectedAt: Date?
    let createdAt: Date
    let updatedAt: Date?
    let devices: [CustomerOrderDevice]?
    let items: [CustomerOrderItem]?
    let totals: CustomerOrderTotals?
    let messages: [CustomerOrderMessage]?
    let company: CustomerCompanyInfo?

    var displayRef: String { "#\(ticketNumber)" }

    var canApproveQuote: Bool {
        quoteSentAt != nil && quoteApprovedAt == nil && rejectedAt == nil
    }
}

struct CustomerOrderDevice: Identifiable, Codable {
    let id: String
    let displayName: String
    let status: String
    let workflowType: String?
    let customerReportedIssues: String?
    let authorizationStatus: String?
    let items: [CustomerOrderItem]?
}

struct CustomerOrderItem: Identifiable, Codable {
    var id: String { description + String(quantity) }
    let description: String
    let quantity: Int
    let unitPrice: Double
    let vatRate: Double
    let lineTotal: Double
    let lineTotalIncVat: Double
}

struct CustomerOrderTotals: Codable {
    let subtotal: Double
    let vatTotal: Double
    let grandTotal: Double
    let amountPaid: Double?
    let balanceDue: Double?
}

struct CustomerOrderMessage: Identifiable, Codable {
    let id: String
    let type: String
    let body: String?
    let fromName: String?
    let createdAt: Date
}

struct CustomerCompanyInfo: Codable {
    let name: String
    let phone: String?
    let email: String?
    let currencyCode: String?
}
```

### 2. SignatureView Component

```swift
// Repair Minder/Customer/Components/SignatureView.swift

import SwiftUI
import PencilKit

struct SignatureView: View {
    @Binding var signatureType: SignatureType
    @Binding var signatureData: String

    @State private var typedName = ""
    @State private var canvasView = PKCanvasView()

    enum SignatureType: String {
        case typed = "typed"
        case drawn = "drawn"
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Signature Type", selection: $signatureType) {
                Text("Type Name").tag(SignatureType.typed)
                Text("Draw Signature").tag(SignatureType.drawn)
            }
            .pickerStyle(.segmented)

            if signatureType == .typed {
                TextField("Type your full name", text: $typedName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title2)
                    .onChange(of: typedName) { _, newValue in
                        signatureData = newValue
                    }
            } else {
                SignatureCanvas(canvasView: $canvasView, onChanged: { image in
                    if let data = image.pngData() {
                        signatureData = data.base64EncodedString()
                    }
                })
                .frame(height: 150)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )

                Button("Clear") {
                    canvasView.drawing = PKDrawing()
                    signatureData = ""
                }
                .font(.caption)
            }
        }
    }
}

struct SignatureCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var onChanged: (UIImage) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.backgroundColor = .clear
        canvasView.delegate = context.coordinator
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var onChanged: (UIImage) -> Void

        init(onChanged: @escaping (UIImage) -> Void) {
            self.onChanged = onChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let image = canvasView.drawing.image(from: canvasView.bounds, scale: 2.0)
            onChanged(image)
        }
    }
}
```

### 3. CustomerOrderDetailViewModel (Fixed)

```swift
@MainActor
@Observable
final class CustomerOrderDetailViewModel {
    let orderId: String

    private(set) var order: CustomerOrder?
    private(set) var isLoading = false
    private(set) var isSubmitting = false
    var error: String?
    var successMessage: String?

    init(orderId: String) {
        self.orderId = orderId
    }

    // MARK: - Load Order (single endpoint provides everything)

    func loadOrder() async {
        isLoading = true
        error = nil

        do {
            order = try await APIClient.shared.request(
                .customerOrder(id: orderId),
                responseType: CustomerOrder.self
            )
        } catch {
            self.error = "Failed to load order"
        }

        isLoading = false
    }

    // NOTE: No separate loadTimeline() or loadQuote() - data is in order response

    // MARK: - Approve Quote

    func approveQuote(signatureType: String, signatureData: String) async {
        guard let total = order?.totals?.grandTotal else { return }

        isSubmitting = true
        error = nil

        do {
            try await APIClient.shared.requestVoid(
                .customerApproveOrder(
                    orderId: orderId,
                    action: "approve",
                    signatureType: signatureType,
                    signatureData: signatureData,
                    amountAcknowledged: total
                )
            )
            successMessage = "Quote approved! Your repair will begin shortly."
            await loadOrder()
        } catch {
            self.error = "Failed to approve quote"
        }

        isSubmitting = false
    }

    // MARK: - Reject Quote

    func rejectQuote(signatureType: String, signatureData: String, reason: String) async {
        isSubmitting = true
        error = nil

        do {
            try await APIClient.shared.requestVoid(
                .customerApproveOrder(
                    orderId: orderId,
                    action: "reject",
                    signatureType: signatureType,
                    signatureData: signatureData,
                    rejectionReason: reason
                )
            )
            successMessage = "Quote declined. The shop has been notified."
            await loadOrder()
        } catch {
            self.error = "Failed to decline quote"
        }

        isSubmitting = false
    }

    // MARK: - Send Message

    func sendMessage(_ message: String, deviceId: String? = nil) async {
        do {
            try await APIClient.shared.requestVoid(
                .customerReply(orderId: orderId, message: message, deviceId: deviceId)
            )
            await loadOrder()  // Reload to show new message
        } catch {
            self.error = "Failed to send message"
        }
    }
}
```

### 4. QuoteApprovalView (With Signature)

```swift
struct QuoteApprovalView: View {
    let order: CustomerOrder
    @State private var viewModel: CustomerOrderDetailViewModel
    @State private var signatureType: SignatureView.SignatureType = .typed
    @State private var signatureData = ""
    @State private var showRejectSheet = false
    @State private var rejectReason = ""
    @Environment(\.dismiss) private var dismiss

    init(order: CustomerOrder) {
        self.order = order
        _viewModel = State(initialValue: CustomerOrderDetailViewModel(orderId: order.id))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Quote items from order.devices and order.items
                    QuoteItemsList(devices: order.devices ?? [])

                    // Total
                    if let totals = order.totals {
                        QuoteTotalsCard(totals: totals)
                    }

                    // Signature capture
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Signature")
                            .font(.headline)

                        SignatureView(
                            signatureType: $signatureType,
                            signatureData: $signatureData
                        )
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)

                    // Action buttons
                    VStack(spacing: 12) {
                        Button {
                            Task {
                                await viewModel.approveQuote(
                                    signatureType: signatureType.rawValue,
                                    signatureData: signatureData
                                )
                                if viewModel.error == nil {
                                    dismiss()
                                }
                            }
                        } label: {
                            Text("Approve Quote")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(signatureData.isEmpty || viewModel.isSubmitting)

                        Button {
                            showRejectSheet = true
                        } label: {
                            Text("Decline Quote")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isSubmitting)
                    }
                }
                .padding()
            }
            .navigationTitle("Review Quote")
            .sheet(isPresented: $showRejectSheet) {
                RejectQuoteSheet(/* ... */)
            }
        }
    }
}
```

## Database Changes

None

## Test Cases

| Test | Expected |
|------|----------|
| Order list loads | Customer's orders displayed |
| Order detail loads | Full order with devices, items, totals |
| Quote items display | Line items with prices shown |
| Type signature | Name captured as signatureData |
| Draw signature | Base64 image captured |
| Approve with signature | Quote approved, status updated |
| Reject with reason | Quote rejected, status updated |
| Send message | Message sent, reloads order |

## Acceptance Checklist

- [ ] Order list loads from correct endpoint
- [ ] Order detail loads all data from single endpoint
- [ ] No calls to non-existent timeline/quote endpoints
- [ ] SignatureView component works (typed and drawn)
- [ ] Approve sends correct payload with signature
- [ ] Reject sends correct payload with reason
- [ ] Success/error messages display
- [ ] Message sending works via `/reply` endpoint

## Deployment

1. Build customer app target
2. Login as customer
3. Navigate to orders
4. Open order awaiting approval
5. Review quote items
6. Add signature (typed or drawn)
7. Approve quote
8. Verify status updates

## Handoff Notes

- Order detail endpoint returns EVERYTHING - no separate calls needed
- Removed: `customerOrderTimeline`, `customerOrderQuote`, `customerApproveQuote`, `customerRejectQuote`
- Added: SignatureView component for capturing approval signatures
- Messages are included in order detail response
