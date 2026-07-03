import SwiftUI

/// Floating bottom bar shown when ≥1 asset is selected in edit-mode. Buttons enable
/// per `BulkActions` (Deploy needs in-stock; Return needs a supplier + active status).
struct BulkActionBar: View {
    let selectedAssets: [Asset]
    let onMove: () -> Void
    let onDeploy: () -> Void
    let onReturn: () -> Void
    let onExport: () -> Void
    let onScan: () -> Void

    private var deployable: Int { BulkActions.deployableCount(selectedAssets) }
    private var returnable: Int { BulkActions.returnableAssets(selectedAssets).count }

    var body: some View {
        VStack(spacing: 8) {
            Text("\(selectedAssets.count) selected").font(.footnote.weight(.medium)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    action("Move", "arrow.left.arrow.right", enabled: !selectedAssets.isEmpty, action: onMove)
                    action("Deploy\(deployable > 0 ? " (\(deployable))" : "")", "shippingbox", enabled: deployable > 0, action: onDeploy)
                    action("Return\(returnable > 0 ? " (\(returnable))" : "")", "arrow.uturn.left", enabled: returnable > 0, action: onReturn)
                    action("Export", "square.and.arrow.up", enabled: !selectedAssets.isEmpty, action: onExport)
                    #if os(iOS)
                    action("Scan", "barcode.viewfinder", enabled: true, action: onScan)
                    #endif
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 6, y: 2)
        .padding(.horizontal, 12).padding(.bottom, 8)
    }

    private func action(_ title: String, _ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.body)
                Text(title).font(.caption2)
            }
            .frame(minWidth: 60)
            .padding(.vertical, 6).padding(.horizontal, 8)
        }
        .disabled(!enabled)
        .accessibilityIdentifier("bulk-\(title.lowercased().prefix(6))")
    }
}
