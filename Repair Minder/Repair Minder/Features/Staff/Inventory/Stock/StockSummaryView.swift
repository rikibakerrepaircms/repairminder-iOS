import SwiftUI

/// Stock summary: sortable product-type rollups with expandable child variants.
/// Row tap filters the Assets list by that product type (mirrors web).
struct StockSummaryView: View {
    @ObservedObject var viewModel: StockViewModel
    let onFilterByProductType: (String) -> Void

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.summary.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.summary.isEmpty {
                retry(error)
            } else if viewModel.summary.isEmpty {
                ContentUnavailableView("No Stock", systemImage: "chart.bar", description: Text("Tracked product types will appear here."))
            } else {
                List {
                    Section {
                        ForEach(viewModel.sortedSummary) { item in
                            summaryRow(item, indent: 0)
                            if viewModel.expandedIds.contains(item.id), let children = item.children {
                                ForEach(children) { child in summaryRow(child, indent: 1) }
                            }
                        }
                    } header: { sortHeader }
                    Section { legend }
                }
                .listStyle(.plain)
                .refreshable { await viewModel.load(.summary) }
            }
        }
    }

    private var sortHeader: some View {
        HStack {
            ForEach(StockSortField.allCases) { field in
                Button {
                    viewModel.setSort(field)
                } label: {
                    HStack(spacing: 2) {
                        Text(field.rawValue).font(.caption2)
                        if viewModel.sortField == field {
                            Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down").font(.system(size: 8))
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.sortField == field ? Color.accentColor : .secondary)
                if field != StockSortField.allCases.last { Spacer() }
            }
        }
    }

    @ViewBuilder private func summaryRow(_ item: StockSummaryItem, indent: CGFloat) -> some View {
        HStack(spacing: 8) {
            if indent == 0, let children = item.children, !children.isEmpty {
                Button { viewModel.toggleExpand(item.id) } label: {
                    Image(systemName: viewModel.expandedIds.contains(item.id) ? "chevron.down" : "chevron.right").font(.caption)
                }.buttonStyle(.plain)
            } else {
                Spacer().frame(width: indent == 0 ? 0 : 20)
            }
            statusGlyph(item)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline).lineLimit(1)
                if let sku = item.sku { Text(sku).font(.caption2.monospaced()).foregroundStyle(.secondary) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(item.displayInStock) in stock").font(.caption.weight(.medium))
                Text("\(item.displayAllocated) alloc · \(item.totalCount) total · min \(item.reorderLevel)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.leading, indent * 12)
        .contentShape(Rectangle())
        .onTapGesture { onFilterByProductType(item.productTypeId) }
    }

    @ViewBuilder private func statusGlyph(_ item: StockSummaryItem) -> some View {
        if item.isOutOfStock {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.caption)
        } else if item.isLowStock {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange).font(.caption)
        } else {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            Label("OK", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            Label("Low", systemImage: "exclamationmark.circle.fill").foregroundStyle(.orange)
            Label("Out", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }.font(.caption2)
    }

    private func retry(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry") { Task { await viewModel.load(.summary) } }.buttonStyle(.borderedProminent)
        }.padding()
    }
}
