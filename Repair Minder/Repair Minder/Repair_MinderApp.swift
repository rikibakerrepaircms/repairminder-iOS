//
//  Repair_MinderApp.swift
//  Repair Minder
//
//  Created by riki on 03/02/2026.
//

import SwiftUI
import UserNotifications

@main
struct Repair_MinderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .onOpenURL { url in
                    _ = DeepLinkHandler.shared.handleURL(url)
                }
        }
    }
}

// MARK: - App Delegate

/// App delegate for handling push notifications and other system callbacks
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self

        // Check if launched from notification
        if let notification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            Task { @MainActor in
                DeepLinkHandler.shared.handleNotification(userInfo: notification)
            }
        }

        return true
    }

    // MARK: - Remote Notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationService.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)

            // Auto-register token if user is authenticated
            if AuthManager.shared.authState == .authenticated {
                await PushNotificationService.shared.registerToken(appType: "staff")
            } else if CustomerAuthManager.shared.authState == .authenticated {
                await PushNotificationService.shared.registerToken(appType: "customer")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationService.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        Task { @MainActor in
            if DeepLinkHandler.shared.shouldDisplayNotificationInForeground(userInfo: userInfo) {
                completionHandler([.banner, .sound, .badge])
            } else {
                completionHandler([])
            }
        }
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        Task { @MainActor in
            DeepLinkHandler.shared.handleNotification(userInfo: userInfo)
        }

        completionHandler()
    }
}

// MARK: - Root View

/// The root view that switches between different app states
struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.currentState {
            case .loading:
                LoadingView()

            case .roleSelection:
                RoleSelectionView()

            case .staffLogin:
                StaffLoginView()

            case .customerLogin:
                CustomerLoginView()

            case .staffDashboard:
                StaffMainView()

            case .customerPortal:
                CustomerOrderListView()

            case .quarantine(let reason):
                QuarantineView(reason: reason)
            }
        }
        .task {
            await appState.initialize()
        }
    }
}

// MARK: - Loading View

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)

            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Staff Main View

/// Main staff interface with tab navigation
private struct StaffMainView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var appState = AppState.shared
    @State private var selectedTab: StaffTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(StaffTab.dashboard)

            MyQueueView()
                .tabItem {
                    Label("My Queue", systemImage: "tray.full.fill")
                }
                .tag(StaffTab.queue)

            OrderListView()
                .tabItem {
                    Label("Orders", systemImage: "doc.text.fill")
                }
                .tag(StaffTab.orders)

            EnquiryListView()
                .tabItem {
                    Label("Enquiries", systemImage: "envelope.fill")
                }
                .tag(StaffTab.enquiries)

            SettingsView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
                .tag(StaffTab.more)
        }
    }
}

/// Staff tab identifiers
private enum StaffTab: Hashable {
    case dashboard
    case queue
    case orders
    case enquiries
    case more
}

// MARK: - Quarantine View

private struct QuarantineView: View {
    let reason: String

    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.orange)

                Text("Limited Access")
                    .font(.title)
                    .fontWeight(.bold)

                Text(reason)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if authManager.currentCompany?.isPendingApproval == true {
                    Text("Please wait for your account to be verified by our team. You will receive an email once approved.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button("Logout") {
                    Task {
                        await authManager.logout()
                        appState.onStaffLogout()
                    }
                }
                .buttonStyle(.bordered)
                .padding(.top)
            }
            .padding()
            .navigationTitle("Account Status")
        }
    }
}
