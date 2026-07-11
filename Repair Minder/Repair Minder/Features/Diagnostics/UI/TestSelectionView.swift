// Features/Diagnostics/UI/TestSelectionView.swift
import SwiftUI

/// First screen of the diagnostics flow: pick which tests to run (individually or all),
/// then Start. Branded icon-grid category selection step. Hosted by DiagnosticsFlowView.
struct TestSelectionView: View {
    @ObservedObject private var appState = AppState.shared
    @StateObject private var runner = DiagnosticRunner(tests: TestRegistry.allTests())
    @State private var showRunner = false

    /// Ids of tests the current device actually supports. Computed once on appear because some
    /// `isSupported` checks do real work (front-camera discovery, haptics capability query) that we
    /// don't want to repeat on every body re-render. Unsupported tests (e.g. 3D Touch on a phone
    /// with only Haptic Touch) are hidden from the picker entirely rather than shown and then
    /// silently skipped at run time.
    @State private var supportedIds: Set<String> = []

    // Adaptive grid: tiles ~80pt wide and the row fits as many as the width allows
    // (≈4 on standard/large iPhones, 3 on a small SE, 6+ on iPad/landscape).
    private let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 8)
    ]

    /// Tests offered to the user: only those supported on this device.
    private var visibleTests: [DiagnosticTest] {
        runner.tests.filter { supportedIds.contains($0.id) }
    }

    /// Categories that actually have supported tests, in declaration order.
    private var categories: [TestCategory] {
        TestCategory.allCases.filter { cat in visibleTests.contains { $0.category == cat } }
    }

    /// Supported tests belonging to a category.
    private func tests(for category: TestCategory) -> [DiagnosticTest] {
        visibleTests.filter { $0.category == category }
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
            LazyVStack(alignment: .leading, spacing: 16) {
                if let shopName = DiagnosticsShopPairing.companyName {
                    welcomeBanner(shopName)
                }

                ForEach(categories, id: \.self) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        // Category header
                        categoryHeader(category)

                        // Icon grid of test tiles
                        LazyVGrid(columns: columns, spacing: 8) {
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
        .rmSoftTopScrollEdge()
        .onAppear {
            if supportedIds.isEmpty {
                supportedIds = Set(runner.tests.filter { $0.isSupported }.map(\.id))
            }
        }
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
            }
            .controlSize(.large)
            .buttonStyle(.rmGlassProminent(tint: runner.selectedIds.isEmpty ? .gray : .accentColor))
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
            VStack(alignment: .center, spacing: 2) {
                Text("Welcome back")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(shopName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .rmGlassTintedCard(cornerRadius: 14,
                           tint: Color.accentColor.opacity(0.25),
                           fallbackFill: Color.accentColor.opacity(0.1))
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
                VStack(spacing: 6) {
                    Image(systemName: DiagnosticIcons.symbol(for: test.id))
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(isSelected ? .white : Color.accentColor)

                    Text(test.name)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 76)
                .rmGlassTintedCard(
                    cornerRadius: 12,
                    tint: isSelected ? Color.accentColor.opacity(0.6) : Color.platformGray4.opacity(0.4),
                    fallbackFill: isSelected ? Color.accentColor : Color.platformGray6
                )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(4)
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
