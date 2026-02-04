//
//  ContentView.swift
//  Repair Minder
//
//  Created by riki on 03/02/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) var appState
    @Environment(AppRouter.self) var router
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        VStack(spacing: 0) {
            OfflineBanner()

            Group {
                if appState.isLoading {
                    LoadingView(message: "Loading...")
                } else if appState.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        .animation(.easeInOut, value: appState.isAuthenticated)
    }
}

struct MainTabView: View {
    @Environment(AppRouter.self) var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            ForEach(AppRouter.Tab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppRouter.Tab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView()
        case .orders:
            OrderListView()
        case .scanner:
            ScannerView()
        case .clients:
            ClientListView()
        case .settings:
            SettingsView()
        }
    }
}

// Temporary placeholder for unimplemented views
struct PlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text(message)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(title)
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(AppRouter())
}
