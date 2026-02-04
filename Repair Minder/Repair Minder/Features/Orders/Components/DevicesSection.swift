//
//  DevicesSection.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct DevicesSection: View {
    let devices: [Device]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Devices (\(devices.count))", systemImage: "iphone")
                .font(.headline)

            if devices.isEmpty {
                Text("No devices")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(devices) { device in
                    DeviceListItem(device: device)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DevicesSection(devices: [.sample, .sampleMacBook])
        .padding()
        .background(Color(.systemGroupedBackground))
}
