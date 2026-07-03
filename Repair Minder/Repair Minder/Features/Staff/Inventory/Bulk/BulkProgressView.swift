import SwiftUI

/// Shared progress/result panel for the per-item bulk loops (move / deploy).
struct BulkProgressView: View {
    let total: Int
    let outcomes: [BulkOperationOutcome]
    let isRunning: Bool

    private var done: Int { outcomes.count }
    private var failures: [BulkOperationOutcome] { outcomes.filter { !$0.success } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isRunning {
                ProgressView(value: Double(done), total: Double(max(total, 1))) {
                    Text("Processing \(done)/\(total)…").font(.subheadline)
                }
            } else {
                Label("\(outcomes.filter(\.success).count) succeeded" + (failures.isEmpty ? "" : ", \(failures.count) failed"),
                      systemImage: failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(failures.isEmpty ? .green : .orange)
                    .font(.subheadline.weight(.medium))
            }
            if !failures.isEmpty {
                Divider()
                ForEach(failures) { f in
                    HStack(alignment: .top, spacing: 6) {
                        Text(f.assetTag).font(.caption.monospaced())
                        Text(f.message ?? "Failed").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
