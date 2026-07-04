import SwiftUI

/// Collapsible low-stock banner shown above the Assets list (mirrors web, which shows
/// it in every view mode except Groups). Auto-hides when there are no alerts.
///
/// By default the banner fetches its own alerts (used on the Assets list). Pass
/// `usesExternalSource: true` with `preloadedAlerts` to have it purely reflect data
/// already loaded elsewhere (e.g. `StockViewModel.lowStock` in the Stock segment) —
/// this avoids firing a second, redundant `fetchLowStock()` call.
struct LowStockBanner: View {
    let onView: (String) -> Void
    var preloadedAlerts: [LowStockAlert]? = nil
    var usesExternalSource: Bool = false

    @State private var fetchedAlerts: [LowStockAlert] = []
    @State private var expanded = false
    @State private var loaded = false

    private var alerts: [LowStockAlert] {
        usesExternalSource ? (preloadedAlerts ?? []) : fetchedAlerts
    }

    var body: some View {
        Group {
            if !alerts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Button { expanded.toggle() } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text("\(alerts.count) low-stock alert\(alerts.count == 1 ? "" : "s")").font(.subheadline.weight(.medium))
                            Spacer()
                            if !usesExternalSource {
                                Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain)
                            }
                            Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    if expanded {
                        ForEach(alerts.prefix(6)) { alert in
                            HStack {
                                Text(alert.name).font(.caption).lineLimit(1)
                                Spacer()
                                Text("\(alert.inStockCount)/\(alert.reorderLevel)").font(.caption2.monospaced())
                                    .foregroundStyle(alert.isCritical ? .red : .orange)
                                Button("View") { onView(alert.productTypeId) }.font(.caption2).buttonStyle(.bordered)
                            }
                        }
                        if alerts.count > 6 { Text("+\(alerts.count - 6) more in Stock ▸ Low Stock").font(.caption2).foregroundStyle(.secondary) }
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12).padding(.top, 4)
            }
        }
        .task {
            if !usesExternalSource, !loaded { await load() }
        }
    }

    private func load() async {
        loaded = true
        let resp = try? await InventoryService().fetchLowStock()
        fetchedAlerts = resp?.all ?? []
    }
}
