import SwiftUI

/// Full low-stock list (the `all` bucket). "View" filters the Assets list.
struct LowStockView: View {
    @ObservedObject var viewModel: StockViewModel
    let onView: (String) -> Void

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.lowStock == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.lowStock == nil {
                VStack(spacing: 12) {
                    Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Retry") { Task { await viewModel.load(.lowStock) } }.buttonStyle(.borderedProminent)
                }.padding()
            } else if let low = viewModel.lowStock, !low.all.isEmpty {
                List {
                    Section("\(low.summary.total) alert\(low.summary.total == 1 ? "" : "s") · \(low.summary.byCategory.parts) parts · \(low.summary.byCategory.masters) masters · \(low.summary.byCategory.services) services") {
                        ForEach(low.all) { LowStockRow(alert: $0, onView: onView) }
                    }
                }
                .listStyle(.plain)
                .refreshable { await viewModel.load(.lowStock) }
            } else {
                ContentUnavailableView("No Low Stock", systemImage: "checkmark.circle", description: Text("Nothing below its reorder level."))
            }
        }
    }
}

struct LowStockRow: View {
    let alert: LowStockAlert
    let onView: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: alert.isCritical ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(alert.isCritical ? .red : .orange)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(alert.name).font(.subheadline)
                    if alert.isChildService, let parent = alert.parentName { Text("(\(parent))").font(.caption).foregroundStyle(.secondary) }
                }
                if let sku = alert.sku { Text(sku).font(.caption2.monospaced()).foregroundStyle(.secondary) }
                Text("\(alert.inStockCount) in stock (min: \(alert.reorderLevel))" + (alert.deficit > 0 ? " · need \(alert.deficit) more" : ""))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("View") { onView(alert.productTypeId) }.font(.caption).buttonStyle(.bordered)
        }
    }
}
