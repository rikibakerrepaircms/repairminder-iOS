import SwiftUI

/// Parent-owned state for the optional pulled-part recovery captured during allocate-to-order.
struct PartRecoveryState {
    var enabled = false
    var conditionGrade = "A"
    var locationId: String?
    var subLocationId: String?
    var notes = ""
    /// Unanswered until the user explicitly picks Yes/No — only asked for screen categories.
    var lcdWorking: Bool?
    var glassCracked: Bool?
    /// The asset's category, used to decide whether the LCD/glass questions apply.
    var category: String?

    /// Matches web's `category.toLowerCase().includes('screen')` detection exactly
    /// (see src/components/assets/PartRecoveryForm.tsx).
    var isScreen: Bool { (category ?? "").lowercased().contains("screen") }

    /// Valid unless enabled without a grade (A/B/C) + a location, or — for screen
    /// categories — without both LCD-working and glass-cracked explicitly answered.
    var isValid: Bool {
        guard enabled else { return true }
        guard ["A", "B", "C"].contains(conditionGrade), locationId != nil else { return false }
        if isScreen, lcdWorking == nil || glassCracked == nil { return false }
        return true
    }

    func toInput() -> RecoveryInput? {
        guard enabled, let locationId, ["A", "B", "C"].contains(conditionGrade) else { return nil }
        if isScreen {
            guard let lcdWorking, let glassCracked else { return nil }
            return RecoveryInput(conditionGrade: conditionGrade, locationId: locationId,
                                 subLocationId: subLocationId, notes: notes.isEmpty ? nil : notes,
                                 lcdWorking: lcdWorking ? 1 : 0, glassCracked: glassCracked ? 1 : 0)
        }
        return RecoveryInput(conditionGrade: conditionGrade, locationId: locationId,
                             subLocationId: subLocationId, notes: notes.isEmpty ? nil : notes,
                             lcdWorking: nil, glassCracked: nil)
    }
}

struct PartRecoveryForm: View {
    @Binding var state: PartRecoveryState
    @State private var locations: [Location] = []

    var body: some View {
        Section("Recover a pulled part") {
            Toggle("Recover a part from this device", isOn: $state.enabled)
            if state.enabled {
                Picker("Condition", selection: $state.conditionGrade) {
                    Text("A - Excellent").tag("A")
                    Text("B - Good").tag("B")
                    Text("C - Fair").tag("C")
                }
                Picker("Location", selection: $state.locationId) {
                    Text("Select…").tag(String?.none)
                    ForEach(locations) { Text($0.name).tag(String?.some($0.id)) }
                }
                if state.isScreen {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LCD working?").font(.caption).foregroundStyle(.secondary)
                        Picker("LCD working?", selection: $state.lcdWorking) {
                            Text("Yes").tag(Bool?.some(true))
                            Text("No").tag(Bool?.some(false))
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Glass cracked?").font(.caption).foregroundStyle(.secondary)
                        Picker("Glass cracked?", selection: $state.glassCracked) {
                            Text("Yes").tag(Bool?.some(true))
                            Text("No").tag(Bool?.some(false))
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
                TextField("Notes", text: $state.notes, axis: .vertical).lineLimit(2...4)
            }
        }
        .task { locations = (try? await InventoryService().fetchLocations()) ?? [] }
    }
}
