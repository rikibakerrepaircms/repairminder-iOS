import SwiftUI

struct KioskReceiptView: View {
    let order: KioskOrderResponse
    let onNewSale: () -> Void
    let onExit: () -> Void
    @State private var showDocument = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64)).foregroundStyle(.green)
            Text("Sale complete").font(.title.weight(.bold))
            Text("Order #\(order.orderNumber)").foregroundStyle(.secondary)

            VStack(spacing: 6) {
                summaryRow("Total", order.totals.grandTotal)
                summaryRow("Paid", order.totals.amountPaid)
                if order.totals.balanceDue > 0.001 {
                    summaryRow("Balance", order.totals.balanceDue, tint: .orange)
                }
                if let p = order.payment {
                    HStack { Text("Method").foregroundStyle(.secondary); Spacer(); Text(p.paymentMethod.capitalized) }
                        .font(.subheadline)
                }
            }
            .padding()
            .frame(maxWidth: 360)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 12) {
                Button { showDocument = true } label: {
                    Label("Receipt (Share / Print)", systemImage: "doc.text")
                        .frame(maxWidth: 360)
                }.buttonStyle(.bordered)

                Button { onNewSale() } label: {
                    Label("New Sale", systemImage: "plus")
                        .frame(maxWidth: 360)
                }.buttonStyle(.borderedProminent)

                Button("Exit Kiosk") { onExit() }.font(.callout)
            }
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showDocument) {
            DocumentPreviewSheet(orderId: order.id, orderNumber: order.orderNumber, documentType: .invoice)
        }
    }

    private func summaryRow(_ label: String, _ value: Double, tint: Color? = nil) -> some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer()
            Text(String(format: "£%.2f", value)).foregroundStyle(tint ?? .primary) }
            .font(.subheadline)
    }
}
