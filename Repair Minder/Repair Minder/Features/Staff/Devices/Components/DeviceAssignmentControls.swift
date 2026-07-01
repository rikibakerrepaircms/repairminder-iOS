//
//  DeviceAssignmentControls.swift
//  Repair Minder
//
//  Inline engineer + sub-location dropdowns for device rows (Devices list and
//  My Queue), mirroring the web /devices inline assignment column. Shared so the
//  two lists stay consistent.
//

import SwiftUI

struct DeviceAssignmentControls: View {
    let currentEngineer: AssignedEngineerInfo?
    let currentSubLocationId: String?
    let currentSubLocationCode: String?
    let engineers: [EngineerFilterInfo]
    let locations: [LocationOption]
    let subLocationsByLocation: [String: [SubLocationChoice]]
    var onAssignEngineer: (String?) -> Void
    var onAssignSubLocation: (String?) -> Void

    private var locationsWithSubs: [LocationOption] {
        locations.filter { !(subLocationsByLocation[$0.id] ?? []).isEmpty }
    }

    var body: some View {
        HStack(spacing: 8) {
            engineerMenu
            subLocationMenu
            Spacer(minLength: 0)
        }
    }

    private var engineerMenu: some View {
        Menu {
            Button { onAssignEngineer(nil) } label: {
                if currentEngineer == nil { Label("Unassigned", systemImage: "checkmark") }
                else { Text("Unassigned") }
            }
            ForEach(engineers) { eng in
                Button { onAssignEngineer(eng.id) } label: {
                    if currentEngineer?.id == eng.id { Label(eng.name, systemImage: "checkmark") }
                    else { Text(eng.name) }
                }
            }
        } label: {
            chip(icon: "person", text: currentEngineer?.name ?? "Unassigned", active: currentEngineer != nil)
        }
    }

    private var subLocationMenu: some View {
        Menu {
            Button { onAssignSubLocation(nil) } label: {
                if currentSubLocationId == nil { Label("None", systemImage: "checkmark") }
                else { Text("None") }
            }
            ForEach(locationsWithSubs) { loc in
                Section(loc.name) {
                    ForEach(subLocationsByLocation[loc.id] ?? []) { sl in
                        Button { onAssignSubLocation(sl.id) } label: {
                            if currentSubLocationId == sl.id { Label(sl.code, systemImage: "checkmark") }
                            else { Text(sl.code) }
                        }
                    }
                }
            }
        } label: {
            chip(icon: "mappin.circle", text: currentSubLocationCode ?? "Location", active: currentSubLocationId != nil)
        }
    }

    private func chip(icon: String, text: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(active ? Color.accentColor.opacity(0.12) : Color.platformGray5)
        .foregroundStyle(active ? Color.accentColor : Color.secondary)
        .clipShape(Capsule())
    }
}
