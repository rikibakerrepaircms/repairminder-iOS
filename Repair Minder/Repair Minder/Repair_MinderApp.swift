//
//  Repair_MinderApp.swift
//  Repair Minder
//
//  Created by riki on 03/02/2026.
//

import SwiftUI

@main
struct Repair_MinderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var appState = AppState()
    @State private var router = AppRouter()
    @AppStorage("appearance") private var appearance: Appearance = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(router)
                .task {
                    // Set up deep link handler with router reference
                    await MainActor.run {
                        DeepLinkHandler.shared.router = router
                    }

                    // Check auth status
                    await appState.checkAuthStatus()

                    // Request notification permission if authenticated
                    if appState.isAuthenticated {
                        await NotificationManager.shared.requestPermission()
                    }
                }
                .onOpenURL { url in
                    // Handle deep link URLs
                    DeepLinkHandler.shared.handle(url: url)
                }
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
