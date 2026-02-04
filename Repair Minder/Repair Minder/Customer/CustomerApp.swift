//
//  CustomerApp.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//
//  NOTE: When creating the Customer target in Xcode:
//  1. Add "CUSTOMER_APP" to Swift Active Compilation Conditions (Build Settings)
//  2. Exclude Staff-only files (Features/, App/) from Customer target
//  3. Include Customer/, Core/, Shared/, Resources/ in Customer target
//

import SwiftUI

#if CUSTOMER_APP
@main
struct CustomerApp: App {
    @State private var authManager = CustomerAuthManager()

    var body: some Scene {
        WindowGroup {
            CustomerContentView()
                .environment(authManager)
        }
    }
}
#endif
