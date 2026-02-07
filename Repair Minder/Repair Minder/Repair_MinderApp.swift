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
    @ObservedObject private var passcodeService = PasscodeService.shared
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @Environment(\.scenePhase) private var scenePhase

    @State private var backgroundTime: Date?

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(appState)
                    .onOpenURL { url in
                        _ = DeepLinkHandler.shared.handleURL(url)
                    }

                if passcodeService.isLocked {
                    PasscodeLockView()
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .opacity
                        ))
                }
            }
            .preferredColorScheme(appearanceManager.preferredColorScheme)
            .animation(passcodeService.isLocked ? nil : .easeInOut(duration: 0.25), value: passcodeService.isLocked)
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            backgroundTime = Date()
            // Always lock when going to background so content is never visible on return
            passcodeService.lockApp()
        case .active:
            if passcodeService.isLocked {
                if passcodeService.timeoutMinutes == 0 {
                    // "On App Close" — always stay locked
                } else if let bg = backgroundTime {
                    let duration = Date().timeIntervalSince(bg)
                    if !passcodeService.shouldLockOnForeground(backgroundDuration: duration) {
                        // Timeout not reached — unlock silently
                        passcodeService.unlockApp()
                    }
                } else {
                    // No background time recorded (cold launch) — stay locked
                }
            }
            backgroundTime = nil
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - App Delegate

/// App delegate for handling push notifications and other system callbacks
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Dynamically controlled orientation lock. Default allows all but upside-down.
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }

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
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        #if DEBUG
        print("🔔 [AppDelegate] Got APNs token: \(tokenString.prefix(20))...")
        #endif

        Task { @MainActor in
            PushNotificationService.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)

            // Auto-register token if user is authenticated
            if AuthManager.shared.authState == .authenticated {
                #if DEBUG
                print("🔔 [AppDelegate] User authenticated, registering token with backend...")
                #endif
                await PushNotificationService.shared.registerToken(appType: "staff")

                // Show feedback to user
                #if DEBUG
                if PushNotificationService.shared.errorMessage == nil {
                    print("🔔 [AppDelegate] Token registered successfully!")
                } else {
                    print("🔔 [AppDelegate] Token registration failed: \(PushNotificationService.shared.errorMessage ?? "unknown")")
                }
                #endif
            } else if CustomerAuthManager.shared.authState == .authenticated {
                #if DEBUG
                print("🔔 [AppDelegate] Customer authenticated, registering token with backend...")
                #endif
                await PushNotificationService.shared.registerToken(appType: "customer")
            } else {
                #if DEBUG
                print("🔔 [AppDelegate] User not authenticated, skipping token registration")
                #endif
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("❌ [AppDelegate] Failed to register for push notifications: \(error.localizedDescription)")
        #endif
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

            case .passcodeSetup:
                PasscodeSetupView()

            case .staffDashboard:
                StaffMainView()

            case .customerPortal:
                CustomerOrderListView()

            case .quarantine(let reason):
                QuarantineView(reason: reason)

            case .termsRequired:
                TermsRequiredView()
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
    @ObservedObject private var deepLinkHandler = DeepLinkHandler.shared
    @State private var selectedTab: StaffTab = .dashboard
    @State private var showBookingSheet = false
    @State private var fabDragOffset: CGFloat = 0
    private var fabState = FABState.shared

    // Deep link navigation state
    @State private var deepLinkOrderId: String?
    @State private var deepLinkEnquiryId: String?
    @State private var deepLinkDeviceId: String?

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

            NavigationStack {
                OrderListView()
                    .navigationDestination(item: $deepLinkOrderId) { orderId in
                        OrderDetailView(orderId: orderId)
                    }
            }
            .tabItem {
                Label("Orders", systemImage: "doc.text.fill")
            }
            .tag(StaffTab.orders)

            NavigationStack {
                EnquiryListView()
                    .navigationDestination(item: $deepLinkEnquiryId) { ticketId in
                        EnquiryDetailView(ticketId: ticketId)
                    }
            }
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
        // Dismiss FAB on any tap outside
        .overlay {
            if !fabState.isHidden {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { fabState.hide() }
            }
        }
        // FAB — slides off right edge when hidden, showing a small arc
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(color: fabState.isHidden ? .clear : .accentColor.opacity(0.3),
                        radius: 8, x: 0, y: 4)
                .offset(x: fabState.isHidden ? min(fabDragOffset, 0) : 0)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard fabState.isHidden else { return }
                            fabDragOffset = value.translation.width
                        }
                        .onEnded { value in
                            guard fabState.isHidden else { return }
                            if value.translation.width < -20 {
                                fabState.show()
                            }
                            fabDragOffset = 0
                        }
                )
                .onTapGesture {
                    if fabState.isHidden {
                        fabState.show()
                    } else {
                        showBookingSheet = true
                    }
                }
                .padding(.bottom, 90)
                .padding(.trailing, fabState.isHidden ? -40 : 34)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: fabState.isHidden)
        .fullScreenCover(isPresented: $showBookingSheet) {
            BookingView()
        }
        .onChange(of: deepLinkHandler.pendingDestination) { _, destination in
            handleDeepLink(destination)
        }
        .onAppear {
            // Handle any pending deep link when view appears
            if let destination = deepLinkHandler.pendingDestination {
                handleDeepLink(destination)
            }
        }
    }

    private func handleDeepLink(_ destination: DeepLinkDestination?) {
        guard let destination = destination else { return }

        #if DEBUG
        print("[StaffMainView] Handling deep link: \(destination)")
        #endif

        // Small delay to ensure tab switch completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch destination {
            case .order(let id):
                selectedTab = .orders
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    deepLinkOrderId = id
                }

            case .enquiry(let id), .ticket(let id):
                selectedTab = .enquiries
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    deepLinkEnquiryId = id
                }

            case .device(let id):
                // Devices are typically shown within orders, navigate to queue
                selectedTab = .queue
                deepLinkDeviceId = id
            }

            // Clear the pending destination
            deepLinkHandler.clearPendingDestination()
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

// MARK: - Passcode Setup View

/// Shown after first login when user hasn't set a passcode.
/// Has a "Set up later" button — passcode setup is optional.
private struct PasscodeSetupView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var passcodeService = PasscodeService.shared
    @State private var showBiometricPrompt = false

    var body: some View {
        ZStack(alignment: .bottom) {
            SetPasscodeView(mode: .create) { success in
                if success {
                    if passcodeService.isBiometricAvailable {
                        showBiometricPrompt = true
                    } else {
                        appState.onPasscodeSet()
                    }
                }
                // Cancel (success=false) is ignored — only "Set up later" skips
            }

            Button("Set up later") {
                appState.onPasscodeSetupSkipped()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 32)
        }
        .alert("Use \(passcodeService.biometricType.displayName)?", isPresented: $showBiometricPrompt) {
            Button("Enable") {
                passcodeService.setBiometric(enabled: true)
                appState.onPasscodeSet()
            }
            Button("Not Now", role: .cancel) {
                appState.onPasscodeSet()
            }
        } message: {
            Text("Unlock Repair Minder with \(passcodeService.biometricType.displayName) instead of entering your passcode each time.")
        }
    }
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

// MARK: - Terms Required View

/// Blocking view shown when the company has pending platform terms to accept.
/// Users must visit the web app to review and agree before using the iOS app.
private struct TermsRequiredView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var appState = AppState.shared
    @State private var isChecking = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)

                Text("Updated Terms")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Our platform terms have been updated. Please review and accept the updated terms on the web app to continue using Repair Minder.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Link(destination: URL(string: "https://app.repairminder.com/")!) {
                    HStack {
                        Image(systemName: "safari")
                        Text("Open Repair Minder Web")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)

                Button {
                    isChecking = true
                    Task {
                        await appState.recheckConsent()
                        isChecking = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isChecking {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("I've Accepted \u{2014} Continue")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isChecking)
                .padding(.horizontal, 32)

                Spacer()

                Button("Log Out") {
                    Task {
                        await authManager.logout()
                        appState.onStaffLogout()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            }
            .navigationTitle("Terms Required")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
