import SwiftUI

/// Post-sale receipt — mirrors the web kiosk `KioskReceipt`: success check,
/// "Payment Complete", order # + client, a per-item summary card, and
/// Share / Print / New Sale actions.
struct KioskReceiptView: View {
    let order: KioskOrderResponse
    let onNewSale: () -> Void
    let onExit: () -> Void
    @State private var showDocument = false

    private var clientName: String {
        let n = [order.client.firstName, order.client.lastName].compactMap { $0 }.joined(separator: " ")
        return n.isEmpty ? "Guest" : n
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 24)

                ZStack {
                    Circle().fill(Color.green.opacity(0.15)).frame(width: 80, height: 80)
                    Image(systemName: "checkmark").font(.system(size: 34, weight: .bold)).foregroundStyle(.green)
                }

                VStack(spacing: 4) {
                    Text("Payment Complete").font(.title.weight(.bold))
                    Text("Order #\(order.orderNumber) · \(clientName)").foregroundStyle(.secondary)
                }

                summaryCard
                    .frame(maxWidth: 380)

                VStack(spacing: 12) {
                    Button { showDocument = true } label: {
                        Label("Share Receipt", systemImage: "square.and.arrow.up").frame(maxWidth: 380)
                    }.buttonStyle(.borderedProminent)

                    Button { showDocument = true } label: {
                        Label("Print Receipt", systemImage: "printer").frame(maxWidth: 380)
                    }.buttonStyle(.bordered)

                    Button { onNewSale() } label: {
                        Label("New Sale", systemImage: "arrow.counterclockwise").frame(maxWidth: 380)
                    }.buttonStyle(.borderedProminent).tint(.green)

                    Button("Exit Kiosk") { onExit() }.font(.callout).padding(.top, 4)
                }

                Spacer(minLength: 24)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showDocument) {
            DocumentPreviewSheet(orderId: order.id, orderNumber: order.orderNumber, documentType: .invoice)
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 8) {
            ForEach(order.items) { item in
                HStack(alignment: .top) {
                    Text("\(item.quantity)x \(item.description)")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(money(item.lineTotalIncVat)).font(.subheadline)
                }
            }
            Divider()
            HStack {
                Text("Total").font(.headline)
                Spacer()
                Text(money(order.totals.grandTotal)).font(.headline)
            }
            if let p = order.payment {
                HStack {
                    Text("Paid (\(p.paymentMethod.capitalized))").foregroundStyle(.green)
                    Spacer()
                    Text(money(p.amount)).foregroundStyle(.green)
                }
                .font(.subheadline)
            } else if order.totals.balanceDue > 0.001 {
                HStack {
                    Text("Balance Due").foregroundStyle(.orange)
                    Spacer()
                    Text(money(order.totals.balanceDue)).foregroundStyle(.orange)
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
    }

    private func money(_ v: Double) -> String { String(format: "£%.2f", v) }
}
