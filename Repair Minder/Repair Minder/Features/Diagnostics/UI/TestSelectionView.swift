// Features/Diagnostics/UI/TestSelectionView.swift
import SwiftUI

/// First screen of the diagnostics flow: pick which tests to run (individually or all),
/// then Start. Branded icon-grid category selection step. Hosted by DiagnosticsFlowView.
struct TestSelectionView: View {
    @ObservedObject private var appState = AppState.shared
    @StateObject private var runner = DiagnosticRunner(tests: TestRegistry.allTests())
    @State private var showRunner = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

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

    private var startLabel: String {
        if runner.isInProgress { return "Resume" }
        return runner.selectedIds.isEmpty ? "Start" : "Start (\(runner.selectedIds.count))"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if let shopName = DiagnosticsShopPairing.companyName {
                    welcomeBanner(shopName)
                }

                ForEach(categories, id: \.self) { category in
                    VStack(alignment: .leading, spacing: 10) {
                        // Category header
                        categoryHeader(category)

                        // Icon grid of test tiles
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(tests(for: category), id: \.id) { test in
                                testTile(test)
                            }
                        }
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
                // Resume an in-progress session; otherwise (re)start fresh so a completed run's
                // results don't leak into a new selection.
                if !runner.isInProgress { runner.reset() }
                showRunner = true
            } label: {
                Text(startLabel)
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

    /// "Welcome back …" banner for a shop-paired device (name comes from the server, never hard-coded).
    @ViewBuilder
    private func welcomeBanner(_ shopName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome back")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(shopName)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("welcome-shop")
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

    @ViewBuilder
    private func testTile(_ test: DiagnosticTest) -> some View {
        let isSelected = runner.selectedIds.contains(test.id)

        Button {
            runner.toggle(test.id)
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Image(systemName: DiagnosticIcons.symbol(for: test.id))
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(isSelected ? .white : Color.accentColor)

                    Text(test.name)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 96)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? Color.accentColor : Color(.systemGray6))
                )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("test-row-\(test.id)")
    }
}

#Preview {
    NavigationStack { TestSelectionView() }
}
