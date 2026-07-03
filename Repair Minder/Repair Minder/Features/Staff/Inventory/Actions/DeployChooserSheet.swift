import SwiftUI

struct DeployChooserSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: InventoryDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var route: Route?

    private enum Route: Int, Identifiable { case order, external; var id: Int { rawValue } }

    var body: some View {
        NavigationStack {
            List {
                Button { route = .order } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("To Order")
                            Text("Allocate to an existing RepairMinder order")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "shippingbox") }
                }
                Button { route = .external } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("External")
                            Text("Deploy to an external job or customer")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "arrow.up.forward.app") }
                }
            }
            .navigationTitle("Deploy Asset")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(item: $route) { r in
                switch r {
                case .order: DeployToOrderWizard(asset: asset, detailVM: viewModel) { dismiss() }
                case .external: DeployExternalSheet(asset: asset, viewModel: viewModel)
                }
            }
        }
    }
}
