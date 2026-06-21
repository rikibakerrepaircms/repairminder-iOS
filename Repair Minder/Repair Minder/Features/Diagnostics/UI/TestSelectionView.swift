// Features/Diagnostics/UI/TestSelectionView.swift
import SwiftUI

/// First screen of the diagnostics flow: pick which tests to run (individually or all),
/// then Start. Branded category selection step. Hosted by DiagnosticsFlowView.
struct TestSelectionView: View {
    @ObservedObject private var appState = AppState.shared
    @StateObject private var runner = DiagnosticRunner(tests: TestRegistry.allTests())
    @State private var showRunner = false

    /// Categories that actually have tests, in declaration order.
    private var categories: [TestCategory] {
        TestCategory.allCases.filter { cat in runner.tests.contains { $0.category == cat } }
    }

    /// Tests belonging to a category.
    private func tests(for category: TestCategory) -> [DiagnosticTest] {
        runner.tests.filter { $0.category == category }
    }

    /// Number of selected tests in a category.
    private func selectedCount(for category: TestCategory) -> Int {
        tests(for: category).filter { runner.selectedIds.contains($0.id) }.count
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(categories, id: \.self) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        // Category header
                        categoryHeader(category)

                        // Test rows
                        VStack(spacing: 0) {
                            let categoryTests = tests(for: category)
                            ForEach(Array(categoryTests.enumerated()), id: \.element.id) { index, test in
                                Button {
                                    runner.toggle(test.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: runner.selectedIds.contains(test.id)
                                              ? "checkmark.circle.fill"
                                              : "circle")
                                            .font(.system(size: 20))
                                            .foregroundStyle(runner.selectedIds.contains(test.id)
                                                             ? Color.accentColor
                                                             : Color.secondary)

                                        Text(test.name)
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemBackground))
                                }
                                .accessibilityIdentifier("test-row-\(test.id)")

                                if index < categoryTests.count - 1 {
                                    Divider()
                                        .padding(.leading, 48)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Device Diagnostics")
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
            .background(.ultraThinMaterial)
            .accessibilityIdentifier("start-tests")
        }
        .navigationDestination(isPresented: $showRunner) {
            TestRunnerView(runner: runner)
        }
    }

    @ViewBuilder
    private func categoryHeader(_ category: TestCategory) -> some View {
        let total = tests(for: category).count
        let selected = selectedCount(for: category)

        HStack(alignment: .center) {
            Text(category.rawValue)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            if selected > 0 {
                Text("\(selected)/\(total)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                    )
            } else {
                Text("\(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    NavigationStack { TestSelectionView() }
}
