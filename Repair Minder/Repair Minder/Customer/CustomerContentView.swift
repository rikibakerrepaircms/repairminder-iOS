//
//  CustomerContentView.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct CustomerContentView: View {
    @Environment(CustomerAuthManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isLoading {
                LoadingView(message: "Loading...")
            } else if authManager.isAuthenticated {
                CustomerMainView()
            } else {
                CustomerLoginView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
    }
}

struct CustomerMainView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CustomerOrderListView()
                .tabItem {
                    Label("Repairs", systemImage: "wrench.and.screwdriver.fill")
                }
                .tag(0)

            CustomerEnquiryListView()
                .tabItem {
                    Label("Enquiries", systemImage: "envelope.fill")
                }
                .tag(1)

            CustomerMessagesListView()
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(2)

            CustomerProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
    }
}

#Preview {
    CustomerContentView()
        .environment(CustomerAuthManager())
}
