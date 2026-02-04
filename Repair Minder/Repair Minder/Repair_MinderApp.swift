//
//  Repair_MinderApp.swift
//  Repair Minder
//
//  Created by riki on 03/02/2026.
//

import SwiftUI
import BackgroundTasks

@main
struct Repair_MinderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var appState = AppState()
    @State private var router = AppRouter()
    @AppStorage("appearance") private var appearance: Appearance = .system

    init() {
        registerBackgroundTasks()
    }

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
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    scheduleBackgroundSync()
                }
                .onOpenURL { url in
                    // Handle deep link URLs
                    DeepLinkHandler.shared.handle(url: url)
                }
                .preferredColorScheme(appearance.colorScheme)
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: SyncEngine.backgroundTaskIdentifier,
            using: nil
        ) { task in
            handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
    }

    private func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: SyncEngine.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background sync: \(error)")
        }
    }
}

private func handleBackgroundSync(task: BGAppRefreshTask) {
    // Schedule next sync
    let request = BGAppRefreshTaskRequest(identifier: SyncEngine.backgroundTaskIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)

    let syncTask = Task {
        await SyncEngine.shared.performFullSync()
    }

    task.expirationHandler = {
        syncTask.cancel()
    }

    Task {
        await syncTask.value
        task.setTaskCompleted(success: true)
    }
}
