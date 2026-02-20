//
//  MacStaffMainView.swift
//  Repair Minder
//
//  Created on 20/02/2026.
//

#if os(macOS)
import SwiftUI

// MARK: - Mac Staff Main View

/// macOS-native sidebar navigation replacing the iOS TabView.
/// Uses NavigationSplitView with 7 sections exposed in the sidebar.
struct MacStaffMainView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var deepLinkHandler = DeepLinkHandler.shared

    @State private var selectedSection: MacSection? = .dashboard
    @State private var showBookingSheet = false
    @State private var showDeviceLookup = false

    // Deep link navigation state
    @State private var deepLinkOrderId: String?
    @State private var deepLinkEnquiryId: String?
    @State private var deepLinkBuybackId: String?
    @State private var deepLinkDeviceId: String?

    enum MacSection: String, Hashable, CaseIterable {
        case dashboard = "Dashboard"
        case queue = "My Queue"
        case orders = "Orders"
        case enquiries = "Enquiries"
        case clients = "Clients"
        case devices = "Devices"
        case buyback = "Buyback"
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .sheet(isPresented: $showBookingSheet) {
            BookingView()
                .frame(minWidth: 600, minHeight: 700)
        }
        .sheet(isPresented: $showDeviceLookup) {
            ScannerView()
                .frame(minWidth: 500, minHeight: 400)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openNewBooking)) { _ in
            showBookingSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDeviceLookup)) { _ in
            showDeviceLookup = true
        }
        .onChange(of: deepLinkHandler.pendingDestination) { _, destination in
            handleDeepLink(destination)
        }
        .onAppear {
            if let destination = deepLinkHandler.pendingDestination {
                handleDeepLink(destination)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedSection) {
            Section("Overview") {
                Label("Dashboard", systemImage: "chart.bar.fill")
                    .tag(MacSection.dashboard)
                Label("My Queue", systemImage: "tray.full.fill")
                    .tag(MacSection.queue)
            }

            Section("Work") {
                Label("Orders", systemImage: "doc.text.fill")
                    .tag(MacSection.orders)
                Label("Enquiries", systemImage: "envelope.fill")
                    .tag(MacSection.enquiries)
                Label("Clients", systemImage: "person.2.fill")
                    .tag(MacSection.clients)
                Label("Devices", systemImage: "iphone.gen3")
                    .tag(MacSection.devices)
                Label("Buyback", systemImage: "arrow.triangle.2.circlepath")
                    .tag(MacSection.buyback)
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showBookingSheet = true
                } label: {
                    Label("New Booking", systemImage: "plus")
                }
                .help("New Booking (⌘N)")

                Button {
                    showDeviceLookup = true
                } label: {
                    Label("Device Lookup", systemImage: "barcode.viewfinder")
                }
                .help("Device Lookup (⌘⇧F)")
            }
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .dashboard:
            NavigationStack { DashboardView() }
        case .queue:
            NavigationStack { MyQueueView() }
        case .orders:
            NavigationStack {
                OrderListView()
                    .navigationDestination(item: $deepLinkOrderId) { orderId in
                        OrderDetailView(orderId: orderId)
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
            NavigationStack { ClientListView() }
        case .devices:
            NavigationStack { DevicesView() }
        case .buyback:
            NavigationStack {
                BuybackListView()
                    .navigationDestination(item: $deepLinkBuybackId) { buybackId in
                        BuybackDetailView(buybackId: buybackId)
                    }
            }
        case .none:
            Text("Select a section")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ destination: DeepLinkDestination?) {
        guard let destination else { return }

        #if DEBUG
        print("[MacStaffMainView] Handling deep link: \(destination)")
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch destination {
            case .order(let id):
                selectedSection = .orders
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    deepLinkOrderId = id
                }

            case .enquiry(let id), .ticket(let id):
                selectedSection = .enquiries
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    deepLinkEnquiryId = id
                }

            case .device:
                selectedSection = .devices

            case .buyback(let id):
                selectedSection = .buyback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    deepLinkBuybackId = id
                }
            }

            deepLinkHandler.clearPendingDestination()
        }
    }
}

// MARK: - Mac Settings View

/// Wraps the existing SettingsView for the macOS Settings scene (⌘,).
struct MacSettingsView: View {
    var body: some View {
        SettingsView()
            .frame(width: 500, height: 500)
    }
}

// MARK: - Notification Names for Menu Bar Commands

extension Notification.Name {
    /// Posted by the "New Booking" menu bar command (⌘N)
    static let openNewBooking = Notification.Name("openNewBooking")
    /// Posted by the "Device Lookup" menu bar command (⌘⇧F)
    static let openDeviceLookup = Notification.Name("openDeviceLookup")
}
#endif
