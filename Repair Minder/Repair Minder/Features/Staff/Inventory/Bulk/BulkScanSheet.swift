#if os(iOS)
import SwiftUI

/// Camera-based bulk-scan accumulator (iOS substitute for the web hardware-wedge
/// `BulkScanActionsModal`): scan multiple in-stock asset tags, then Deploy/Move them.
struct BulkScanSheet: View {
    @StateObject private var viewModel = BulkScanViewModel()
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var showScanner = false
    @State private var showDeploy = false
    @State private var showMove = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.entries.isEmpty {
                    Section { Text("Scan asset tags to build a batch. Only in-stock assets can be deployed or moved.").font(.footnote).foregroundStyle(.secondary) }
                } else {
                    Section("\(viewModel.readyCount) ready · \(viewModel.entries.count) scanned") {
                        ForEach(viewModel.entries) { entry in
                            HStack {
                                Image(systemName: entry.asset != nil ? "checkmark.circle.fill" : "exclamationmark.circle")
                                    .foregroundStyle(entry.asset != nil ? .green : .orange)
                                VStack(alignment: .leading) {
                                    Text(entry.tag).font(.subheadline.monospaced())
                                    if let a = entry.asset { Text(a.name).font(.caption).foregroundStyle(.secondary) }
                                    else if let e = entry.error { Text(e).font(.caption).foregroundStyle(.orange) }
                                }
                                Spacer()
                                Button(role: .destructive) { viewModel.remove(entry.tag) } label: { Image(systemName: "xmark.circle") }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bulk Scan")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button { showScanner = true } label: { Label("Scan", systemImage: "barcode.viewfinder").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                    Menu {
                        Button("Deploy") { showDeploy = true }
                        Button("Move") { showMove = true }
                    } label: { Label("Actions", systemImage: "ellipsis.circle").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.readyCount == 0)
                }
                .padding()
                .background(.regularMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { if !viewModel.entries.isEmpty { Button("Clear") { viewModel.clear() } } }
            }
            .sheet(isPresented: $showScanner) {
                InventoryScannerSheet { tag in
                    showScanner = false
                    Task { await viewModel.onScan(tag: tag) }
                }
            }
            .sheet(isPresented: $showDeploy) {
                BulkDeploySheet(assets: viewModel.readyAssets) { onDone(); dismiss() }
            }
            .sheet(isPresented: $showMove) {
                BulkMoveSheet(assets: viewModel.readyAssets) { onDone(); dismiss() }
            }
        }
    }
}
#endif
