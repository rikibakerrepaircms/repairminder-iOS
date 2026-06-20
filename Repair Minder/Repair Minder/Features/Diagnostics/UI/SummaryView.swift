// Features/Diagnostics/UI/SummaryView.swift
import SwiftUI

/// Shows the per-test results + overall outcome, with a "Send results" action that
/// leads to the shop-code transmit screen (added in the next task).
struct SummaryView: View {
    @ObservedObject var runner: DiagnosticRunner
    @State private var showTransmit = false

    var body: some View {
        List {
            Section("Result") {
                HStack {
                    Text("Overall")
                    Spacer()
                    Text(runner.overallResult.capitalized)
                        .fontWeight(.semibold)
                        .foregroundStyle(color(forResult: runner.overallResult))
                        .accessibilityIdentifier("summary-overall")
                }
            }
            Section("Tests") {
                ForEach(runner.outcomes) { outcome in
                    HStack {
                        Text(outcome.name)
                        Spacer()
                        Text(outcome.status.rawValue.capitalized)
                            .foregroundStyle(color(forStatus: outcome.status))
                    }
                }
            }
        }
        .navigationTitle("Summary")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .safeAreaInset(edge: .bottom) {
            Button {
                showTransmit = true
            } label: {
                Text("Send results")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .accessibilityIdentifier("send-results")
        }
        .navigationDestination(isPresented: $showTransmit) {
            // Placeholder transmit root — replaced by TransmitView in the next task.
            Text("Send results")
                .accessibilityIdentifier("transmit-root")
        }
    }

    private func color(forResult result: String) -> Color {
        switch result {
        case "pass": return .green
        case "fail": return .red
        default: return .orange
        }
    }

    private func color(forStatus status: TestStatus) -> Color {
        switch status {
        case .pass: return .green
        case .fail: return .red
        case .skip: return .secondary
        case .partial, .error: return .orange
        }
    }
}
