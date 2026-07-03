import SwiftUI

/// Parent-owned state for the optional pulled-part recovery captured during allocate-to-order.
struct PartRecoveryState {
    var enabled = false
    var conditionGrade = "A"
    var locationId: String?
    var subLocationId: String?
    var notes = ""
    var lcdWorking = true
    var glassCracked = false

    /// Valid unless enabled without a grade (A/B/C) + a location.
    var isValid: Bool { !enabled || (["A", "B", "C"].contains(conditionGrade) && locationId != nil) }

    func toInput() -> RecoveryInput? {
        guard enabled, let locationId else { return nil }
        return RecoveryInput(conditionGrade: conditionGrade, locationId: locationId,
                             subLocationId: subLocationId, notes: notes.isEmpty ? nil : notes,
                             lcdWorking: lcdWorking ? 1 : 0, glassCracked: glassCracked ? 1 : 0)
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
                Toggle("LCD working", isOn: $state.lcdWorking)
                Toggle("Glass cracked", isOn: $state.glassCracked)
                TextField("Notes", text: $state.notes, axis: .vertical).lineLimit(2...4)
            }
        }
        .task { locations = (try? await InventoryService().fetchLocations()) ?? [] }
    }
}
