// Features/Diagnostics/UI/TestSelectionView.swift
import SwiftUI

/// First screen of the diagnostics flow: pick which tests to run (individually or all),
/// then Start. Mirrors M360's selection step. Hosted by DiagnosticsFlowView.
struct TestSelectionView: View {
    @ObservedObject private var appState = AppState.shared
    @StateObject private var runner = DiagnosticRunner(tests: TestRegistry.allTests())
    @State private var showRunner = false

    /// Categories that actually have tests, in declaration order.
    private var categories: [TestCategory] {
        TestCategory.allCases.filter { cat in runner.tests.contains { $0.category == cat } }
    }

    var body: some View {
        List {
            ForEach(categories, id: \.self) { category in
                Section(category.rawValue) {
                    ForEach(runner.tests.filter { $0.category == category }, id: \.id) { test in
                        Button {
                            runner.toggle(test.id)
                        } label: {
                            HStack {
                                Text(test.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: runner.selectedIds.contains(test.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(runner.selectedIds.contains(test.id) ? Color.accentColor : Color.secondary)
                            }
                        }
                        .accessibilityIdentifier("test-row-\(test.id)")
                    }
                }
            }
        }
        .navigationTitle("Select Tests")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { appState.exitDiagnostics() }
                    .accessibilityIdentifier("diagnostics-close")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Select All") { runner.selectAll() }
                    .accessibilityIdentifier("select-all")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showRunner = true
            } label: {
                Text(runner.selectedIds.isEmpty ? "Start" : "Start (\(runner.selectedIds.count))")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(runner.selectedIds.isEmpty ? Color.gray : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(runner.selectedIds.isEmpty)
            .padding()
            .accessibilityIdentifier("start-tests")
        }
        .navigationDestination(isPresented: $showRunner) {
            TestRunnerView(runner: runner)
        }
    }
}

#Preview {
    NavigationStack { TestSelectionView() }
}
