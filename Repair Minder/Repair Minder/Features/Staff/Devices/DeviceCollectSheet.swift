//
//  DeviceCollectSheet.swift
//  Repair Minder
//
//  Created on 04/07/2026.
//

import SwiftUI

/// Device-level "Collect" sheet — embeds the shared signature-capture inner
/// view (see `OrderSignatureSheet.swift`) and forwards the result to
/// `DeviceDetailViewModel.collectDevice`. Mirrors `CollectOrderSheet`'s
/// structure but posts to the device-scoped collect endpoint.
struct DeviceCollectSheet: View {
    let onCollect: (DeviceCollectRequest) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack {
                OrderSignatureSheetInner { signatureData, typedName, agreed in
                    let err = await onCollect(
                        DeviceCollectRequest(signatureData: signatureData, typedName: typedName, termsAgreed: agreed)
                    )
                    if err == nil {
                        dismiss()
                    } else {
                        errorText = err
                    }
                }
                if let errorText {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .padding()
                }
            }
            .navigationTitle("Collect device")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        errorText = nil
                        dismiss()
                    }
                }
            }
        }
    }
}
