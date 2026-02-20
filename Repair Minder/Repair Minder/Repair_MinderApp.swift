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
    #if os(iOS)
    @UIApplicationDelegateAdaptor(iOSAppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    #endif
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
                    #if os(macOS)
                    .frame(minWidth: 900, minHeight: 600)
                    #endif

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
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Replace default Cmd+N (new window) with our booking action
            CommandGroup(replacing: .newItem) { }

            CommandMenu("Booking") {
                Button("New Booking") {
                    NotificationCenter.default.post(name: .openNewBooking, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Device Lookup") {
                    NotificationCenter.default.post(name: .openDeviceLookup, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(
                        #selector(NSSplitViewController.toggleSidebar(_:)),
                        with: nil
                    )
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
        }
        #endif

        #if os(macOS)
        Settings {
            MacSettingsView()
        }
        #endif
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

#if os(iOS)
/// App delegate for handling push notifications and other system callbacks
class iOSAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Dynamically controlled orientation lock. Default allows all but upside-down.
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return iOSAppDelegate.orientationLock
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
        print("🔔 [iOSAppDelegate] Got APNs token: \(tokenString.prefix(20))...")
        #endif

        Task { @MainActor in
            PushNotificationService.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)

            // Auto-register token if user is authenticated
            if AuthManager.shared.authState == .authenticated {
                #if DEBUG
                print("🔔 [iOSAppDelegate] User authenticated, registering token with backend...")
                #endif
                await PushNotificationService.shared.registerToken(appType: "staff")

                // Show feedback to user
                #if DEBUG
                if PushNotificationService.shared.errorMessage == nil {
                    print("🔔 [iOSAppDelegate] Token registered successfully!")
                } else {
                    print("🔔 [iOSAppDelegate] Token registration failed: \(PushNotificationService.shared.errorMessage ?? "unknown")")
                }
                #endif
            } else if CustomerAuthManager.shared.authState == .authenticated {
                #if DEBUG
                print("🔔 [iOSAppDelegate] Customer authenticated, registering token with backend...")
                #endif
                await PushNotificationService.shared.registerToken(appType: "customer")
            } else {
                #if DEBUG
                print("🔔 [iOSAppDelegate] User not authenticated, skipping token registration")
                #endif
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("❌ [iOSAppDelegate] Failed to register for push notifications: \(error.localizedDescription)")
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
#endif

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
                #if os(iOS)
                StaffMainView()
                #elseif os(macOS)
                MacStaffMainView()
                #endif

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
        LottieLoadingView(size: 140, message: "Loading...")
    }
}

// MARK: - Staff Main View

/// Staff tab identifiers — wraps FeatureTab for dynamic tabs + the fixed More tab
private enum StaffTab: Hashable {
    case feature(FeatureTab)
    case more
}

/// Main staff interface with tab navigation
private struct StaffMainView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var deepLinkHandler = DeepLinkHandler.shared
    @ObservedObject private var tabConfig = TabBarConfig.shared
    @State private var selectedTab: StaffTab = .feature(.dashboard)
    @State private var showBookingSheet = false
    @State private var fabDragOffset: CGFloat = 0
    private var fabState = FABState.shared

    // Deep link navigation state
    @State private var deepLinkOrderId: String?
    @State private var deepLinkEnquiryId: String?
    @State private var deepLinkBuybackId: String?
    @State private var deepLinkDeviceId: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            // Dynamic feature tabs based on user preferences
            ForEach(tabConfig.selectedTabs) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.label, systemImage: tab.icon)
                    }
                    .tag(StaffTab.feature(tab))
            }

            // "More" tab — always present as the last tab
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
        #if os(iOS)
        .fullScreenCover(isPresented: $showBookingSheet) {
            BookingView()
        }
        #elseif os(macOS)
        .sheet(isPresented: $showBookingSheet) {
            BookingView()
                .frame(minWidth: 600, minHeight: 700)
        }
        #endif
        .onChange(of: deepLinkHandler.pendingDestination) { _, destination in
            handleDeepLink(destination)
        }
        .onChange(of: tabConfig.selectedTabs) { _, _ in
            // If current tab was removed from tab bar, switch to dashboard
            if case .feature(let current) = selectedTab, !tabConfig.isSelected(current) {
                selectedTab = .feature(.dashboard)
            }
        }
        .onAppear {
            // Handle any pending deep link when view appears
            if let destination = deepLinkHandler.pendingDestination {
                handleDeepLink(destination)
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(for tab: FeatureTab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView()

        case .queue:
            MyQueueView()

        case .orders:
            NavigationStack {
                OrderListView()
                    .navigationDestination(item: $deepLinkOrderId) { orderId in
                        OrderDetailView(orderId: orderId)
                    }
            }

        case .buyback:
            NavigationStack {
                BuybackListView()
                    .navigationDestination(item: $deepLinkBuybackId) { buybackId in
                        BuybackDetailView(buybackId: buybackId)
                    }
            }

        case .enquiries:
            NavigationStack {
                EnquiryListView()
                    .navigationDestination(item: $deepLinkEnquiryId) { ticketId in
                        EnquiryDetailView(ticketId: ticketId)
                    }
            }

        case .clients:
            ClientListView()
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ destination: DeepLinkDestination?) {
        guard let destination = destination else { return }

        #if DEBUG
        print("[StaffMainView] Handling deep link: \(destination)")
        #endif

        // Small delay to ensure tab switch completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch destination {
            case .order(let id):
                if tabConfig.isSelected(.orders) {
                    selectedTab = .feature(.orders)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        deepLinkOrderId = id
                    }
                } else {
                    selectedTab = .more
                }

            case .enquiry(let id), .ticket(let id):
                if tabConfig.isSelected(.enquiries) {
                    selectedTab = .feature(.enquiries)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        deepLinkEnquiryId = id
                    }
                } else {
                    selectedTab = .more
                }

            case .device(let id):
                if tabConfig.isSelected(.queue) {
                    selectedTab = .feature(.queue)
                } else {
                    selectedTab = .more
                }
                deepLinkDeviceId = id

            case .buyback(let id):
                if tabConfig.isSelected(.buyback) {
                    selectedTab = .feature(.buyback)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        deepLinkBuybackId = id
                    }
                } else {
                    selectedTab = .more
                }
            }

            // Clear the pending destination
            deepLinkHandler.clearPendingDestination()
        }
    }
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
                    .background(Color.platformGray6)
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
